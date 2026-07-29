# Implementation Plan: Medoru 0.10.0 — `/m` TypeScript SPA/PWA + Capacitor Native Packages

**Goal:** Build a standalone TypeScript SPA/PWA at `/m` backed by `/api/v1` REST and Phoenix Channels, then package the same frontend with Capacitor as a **fully native app for the iOS App Store and Google Play**. The `/m` app is a **new, separate application** — it is not a mobile skin of the website.

**Critical constraint — the existing web app is not touched:**
- The existing site and PWA at `/` remain **completely untouched**: no LiveView, template, hook, or desktop-flow changes.
- The only allowed modifications to existing backend code are **purely additive**: new context functions (e.g. native device management), new modules, and new routes/scopes. Existing functions keep their signatures and behavior.
- The one exception is `MedoruWeb.AuthController`, which gains an **additive** `mobile=true` redirect branch for the `/m` login flow; existing redirects stay as they are.
- The mobile app interoperates with the browser chat at `/messages` by calling the same `Medoru.Chat` context functions and by subscribing to the existing `chat:<conversation_id>` Phoenix.PubSub topics through a new, thin channel adapter. Desktop users and mobile users chat with each other transparently.

**Target architecture:**
- Browser `/m` PWA: Phoenix session-cookie auth, Web Push, service worker.
- Native iOS/Android packages (Capacitor): OAuth PKCE → JWT access + DB refresh tokens, APNs/FCM push.
- REST (`/api/v1`) for commands and history.
- Phoenix Channels for real-time events.

**Scope for 0.10.0:** 1-1 and group chats. Classroom chats, full offline sync, and store submission are out of scope for the initial release.

**Platform order (decided 2026-07-29):** Android first — target a working **APK for the user's tablet** before anything iOS. The iOS path (Xcode on the user's Mac, signing, TestFlight) comes after the Android build works end-to-end.

---

## Phase 0: Foundation

### 0.1 Version bump
- Update `mix.exs` `version` to `0.10.0`.
- Update `releases` version to match.

### 0.2 Dependencies

Add to `mix.exs`:
- `{:open_api_spex, "~> 3.21"}` — OpenAPI specs.
- `{:jose, "~> 1.11"}` — JWT signing/verification.
- `{:hammer, "~> 6.1"}` — rate limiting.
- `{:hammer_backend_mnesia, "~> 0.6"}` — default Hammer backend for development. Use `hammer_backend_redis` in production for multi-node deployments.

Defer until the native push phase (Phase 4/5-native) — the existing browser Web Push is hand-rolled in `MedoruWeb.Push` and keeps working without them:
- `{:pigeon, "~> 2.0"}` — APNs/FCM push for native packages.
- `{:kadabra, "~> 0.6"}` — HTTP/2 adapter for Pigeon (APNs).

Add to `assets/m/package.json` (new Vite/Svelte mobile project):
- `vite`, `@sveltejs/vite-plugin-svelte`, `svelte`, `typescript`, `@types/node`, `phoenix`.
- `@capacitor/core`, `@capacitor/cli`, `@capacitor/preferences`, `@capacitor/push-notifications`, `@capacitor/browser`, `@capacitor/splash-screen`, `@capacitor/status-bar`.
- `@aparajita/capacitor-secure-storage` — encrypted storage for refresh tokens.

Run `mix deps.get` and `npm install` in `assets/m`.

### 0.3 Green baseline
- Run `mix compile`, `mix test`, `mix assets.build`.

---

## Phase 1: `/api/v1` REST API

### 1.1 Internal namespace

Use `MedoruWeb.API.V1` for all controllers, schemas, specs, and plugs. Later V2 becomes `MedoruWeb.API.V2` without renaming existing modules.

### 1.2 Unified authentication plug

Create `lib/medoru_web/api/v1/plugs/authenticate.ex`:

```elixir
defmodule MedoruWeb.API.V1.Plugs.Authenticate do
  @moduledoc """
  Authenticates mobile API requests.
  First tries the Phoenix session cookie, then falls back to Bearer token.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with nil <- current_user_from_session(conn),
         nil <- current_user_from_bearer(conn) do
      conn
      |> put_status(401)
      |> Phoenix.Controller.json(%{
        error: %{code: "unauthenticated", message: "Authentication required.", details: %{}}
      })
      |> halt()
    else
      user ->
        assign(conn, :current_scope, %{
          current_user: user,
          locale: conn.assigns[:locale] || "en"
        })
    end
  end

  defp current_user_from_session(conn) do
    # reuse MedoruWeb.UserAuth.fetch_current_user logic
  end

  defp current_user_from_bearer(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> verify_access_token(token)
      _ -> nil
    end
  end
end
```

Create `lib/medoru_web/api/v1/router.ex` or add directly in `lib/medoru_web/router.ex`:

```elixir
pipeline :mobile_api do
  plug :accepts, ["json"]
  plug :put_secure_browser_headers
  plug MedoruWeb.API.V1.Plugs.Authenticate
end

scope "/api/v1", MedoruWeb.API.V1 do
  pipe_through :mobile_api

  get "/me", MeController, :show
  post "/auth/logout", MeController, :logout
  post "/auth/refresh", AuthController, :refresh
  get "/socket_token", AuthController, :socket_token

  resources "/conversations", ConversationController, only: [:index, :create, :show]
  resources "/conversations/:conversation_id/messages", MessageController, only: [:index, :create, :update, :delete]
  post "/conversations/:conversation_id/read", MessageController, :read

  post "/conversations/:conversation_id/messages/:message_id/reactions", ReactionController, :create
  delete "/conversations/:conversation_id/messages/:message_id/reactions/:emoji", ReactionController, :delete

  post "/uploads", UploadController, :create

  get "/words/lookup", LookupController, :word
  get "/kanji/lookup", LookupController, :kanji
  get "/grammars/lookup", LookupController, :grammar

  post "/push/token", PushController, :register_token
  delete "/push/token", PushController, :delete_token
end
```

### 1.3 Rate limiting

Configure `Hammer` in `config/config.exs`:

```elixir
config :hammer,
  backend: {Hammer.Backend.Mnesia, [expiry_ms: 60_000, cleanup_interval_ms: 120_000]}
```

Create `lib/medoru_web/api/v1/plugs/rate_limit.ex`:

- Keyed by `current_user.id` when authenticated, or `conn.remote_ip` when not.
- Limits:
  - login/refresh: 10/minute
  - uploads: 10/minute
  - messages: 120/minute
  - lookups: 60/minute
  - default: 300/minute
- Returns 429 with `Retry-After` header.

Apply rate limiting in `:mobile_api` pipeline after auth.

### 1.4 OpenAPI spec & schemas

Create:
- `lib/medoru_web/api/v1/spec.ex` — `OpenApi` implementation with `cookieAuth` and `bearerAuth` security schemes.
- `lib/medoru_web/api/v1/schemas.ex` — User, Conversation, Participant, Message, Reaction, Error, lookup results, paginated list wrapper.

### 1.5 JWT access tokens

Create `lib/medoru/tokens.ex`:

- `generate_access_token(user_id, jti)` — signs a JWT with `sub`, `jti`, `iat`, `exp` (5 minutes).
- `verify_access_token(token)` — verifies signature, expiry, and revocation list.
- `revoke_access_token(jti)` — adds JTI to a short-lived ETS/Redis revocation set (or rely on short expiry).

Use `JOSE.JWT`/`JOSE.JWS` with a secret from `config/runtime.exs`.

### 1.5.1 Socket tokens

Socket tokens are **not** JWTs. Create a short-lived, random token stored in ETS:

- `Tokens.create_socket_token(user_id)` — generate 256-bit random string, store `{token, user_id, expires_at}` in ETS, return token.
- `Tokens.verify_socket_token(token)` — lookup in ETS, delete on use or expiry, return `{:ok, user_id}` or `:error`.
- TTL: 2 minutes.
- Endpoint: `GET /api/v1/socket_token` returns `%{token: "..."}`.

One practical note before coding: make the socket-token ETS table supervised and explicitly document whether tokens are single-use. Your plan implies single-use because verification deletes them; that is a good default.

### 1.6 Native device & refresh tokens

Create migration:

```elixir
create table(:native_devices, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
  add :device_id, :string, null: false
  add :platform, :string, null: false # ios | android
  add :refresh_token_hash, :string, null: false
  add :push_token, :string
  add :last_seen_at, :utc_datetime_usec
  add :revoked_at, :utc_datetime_usec
  timestamps(type: :utc_datetime_usec)
end

create unique_index(:native_devices, [:device_id])
create index(:native_devices, [:user_id])
create index(:native_devices, [:refresh_token_hash])
```

Create `lib/medoru/accounts/native_device.ex` schema.

Add context functions in `Medoru.Accounts`:
- `create_native_device(user_id, device_id, platform, refresh_plaintext)`
- `verify_native_refresh_token(refresh_plaintext)`
- `rotate_native_device(device, new_refresh_plaintext)`
- `revoke_native_device(user_id, device_id)`
- `update_push_token(user_id, device_id, push_token)`
- `touch_native_device(device_id)`

### 1.7 Auth controllers

Create `lib/medoru_web/api/v1/controllers/me_controller.ex`:
- `show/2` → current user JSON.
- `logout/2` → clear session for browser; for native, revoke device if `device_id` provided.

Create `lib/medoru_web/api/v1/controllers/auth_controller.ex`:
- `refresh/2` — accept `refresh_token` + `device_id`, verify, rotate refresh token, issue new JWT access token.
- `socket_token/2` — issue a short-lived random socket token (2 min) stored in ETS. Browser PWA calls this with session cookie; native calls with bearer access token.

### 1.8 Conversation controller

Create `lib/medoru_web/api/v1/controllers/conversation_controller.ex`:
- `index/2` — `Chat.list_conversations/2`, filter blocked, include unread counts and online status.
- `show/2` — `Chat.get_conversation/2`, include participant public keys and user's encrypted conversation keys.
- `create/2` — 1-1 or group.

All conversation endpoints use the same `Medoru.Chat` context functions the desktop LiveViews use, ensuring identical behavior and data.

### 1.9 Message controller with web-style pagination

Create `lib/medoru_web/api/v1/controllers/message_controller.ex`:

- `index/2` — `GET /api/v1/conversations/:id/messages?page=1&per_page=50`.
  - **Reuse the exact listing the web chat uses**: `Chat.list_messages/2` (chat.ex:390, offset-based `limit`/`offset`, newest-first) and `Chat.list_messages_with_attachments/2` where attachment metadata is needed. No new pagination mechanism is introduced; the mobile app paginates the same way the desktop LiveView does ("load older" button / infinite scroll fetching the next page).
  - Returns `%{data: [...], page: n, per_page: n, has_more: bool}`.
- `create/2` — plaintext or encrypted, with optional `reply_to_message_id` and attachment fields. Uses `Chat.store_message/5` and `Chat.store_plaintext_message/4`.
- `update/2` — edit own message via `Chat.edit_message/3`.
- `delete/2` — soft-delete own message via `Chat.delete_message/2`.
- `read/2` — `Chat.mark_read/2`.

These are the same context functions the desktop chat uses, so messages sent from mobile trigger the same PubSub broadcasts desktop listens to, and vice versa.

### 1.10 Message IDs

Keep existing UUIDv4 primary keys. Ordering follows `inserted_at` exactly as in `Chat.list_messages/2`. No ID-strategy change is needed for 0.10.0.

### 1.11 Reaction controller

Create `lib/medoru_web/api/v1/controllers/reaction_controller.ex`.

### 1.12 Upload controller — reuse the existing chat upload flow

**Do not build a new uploads table or `upload_id` flow.** The web chat already has a working upload mechanism; the mobile API mirrors it:

- Web today: multipart `POST /api/chat/uploads` → `MedoruWeb.ChatUploadController` stores the file at `<uploads_dir>/chat_files/<uuid>.<ext>` and returns the path; the message then stores `attachment_path`, `attachment_type`, `duration_seconds` directly on the `chat_messages` row.
- Mobile: create `lib/medoru_web/api/v1/controllers/upload_controller.ex` with a single `create/2` action (`POST /api/v1/uploads`, multipart) that uses the **same storage helper/validation rules** as `ChatUploadController` (50MB default, 200MB video for teachers/admins, same directory, same served URL `/uploads/chat_files/...`). Extract the shared store/validate logic into a small module both controllers call — this is additive refactoring of `ChatUploadController` internals only; its route, request, and response shapes stay identical so the web app is unaffected.
- Message `create/2` accepts `attachment_path`, `attachment_type`, and `duration_seconds` exactly like the web flow and passes them through to `Chat.store_message/5` / `Chat.store_plaintext_message/4`.
- No cleanup worker is needed (files are referenced by messages immediately, same as the web). No Oban dependency.

### 1.13 Lookup controller

Create `lib/medoru_web/api/v1/controllers/lookup_controller.ex`.

### 1.14 Fallback controller

Create `lib/medoru_web/api/v1/fallback_controller.ex`.

---

## Phase 2: Phoenix Channels

> **Note:** Channels are fully greenfield — the app currently has no `UserSocket`, no `channels/` directory, and only the `/live` LiveView socket in the endpoint. Everything in this phase is new code; no desktop code is modified.

### 2.1 Socket token auth

Add to endpoint:

```elixir
socket "/socket", MedoruWeb.UserSocket,
  websocket: [timeout: 45_000],
  longpoll: false
```

Create `lib/medoru_web/channels/user_socket.ex`:

```elixir
defmodule MedoruWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", MedoruWeb.ChatChannel
  channel "encryption:*", MedoruWeb.EncryptionChannel
  channel "presence:*", MedoruWeb.PresenceChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Tokens.verify_socket_token(token) do
      {:ok, user_id} -> {:ok, assign(socket, :current_user_id, user_id)}
      :error -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user_id}"
end
```

### 2.2 ChatChannel

Create `lib/medoru_web/channels/chat_channel.ex`:

- `join("chat:" <> conversation_id, _payload, socket)` — verify participant, subscribe to the **same** `chat:<conversation_id>` Phoenix.PubSub topic the desktop LiveViews already use.
- Inbound events:
  - `typing` → calls `Chat.set_typing/3` (same as desktop)
  - `read` → calls `Chat.mark_read/2` (same as desktop)
- Forward existing PubSub broadcasts to mobile clients with versioned event names:
  - `{:new_message, msg}` → `"message.created"`
  - `{:message_edited, msg}` → `"message.updated"`
  - `{:message_deleted, id}` → `"message.deleted"`
  - `{:reaction, ...}` → `"reaction.updated"`

**No changes to desktop code.** The channel is a passive listener and emitter on the existing topic.

### 2.3 EncryptionChannel

Create `lib/medoru_web/channels/encryption_channel.ex`:

- `join("encryption:" <> conversation_id, _payload, socket)` — verify participant, subscribe to the existing `chat:<conversation_id>` PubSub topic.
- Inbound events:
  - `register_public_key`
  - `ensure_conversation_key`
  - `store_conversation_keys`
  - `report_key_mismatch`
  - `acknowledge_conversation_key`
- Forward existing PubSub broadcasts with versioned event names:
  - `{:request_key_reencryption, target, key}` → `"encryption.rekey_requested"`
  - `{:reencrypted_key, target, key}` → `"encryption.key_updated"`
  - `{:encryption_reset, conv_id}` → `"encryption.reset"`

**No changes to desktop code.** The desktop already broadcasts these messages to `chat:<conversation_id>`.

### 2.4 PresenceChannel

Create `lib/medoru_web/channels/presence_channel.ex`:

- `join("presence:conversation:<id>", ...)` — track presence for online status.
- `join("presence:user:<id>", ...)` — global online status.
- Forward `{:typing, ...}` PubSub broadcasts to typing subscribers.

Uses the existing `MedoruWeb.Presence` module already used by the desktop chat. No desktop changes required.

---

## Phase 3: `/m` TypeScript SPA/PWA

### 3.1 Build setup

Create `assets/m/` as a Vite + Svelte + TypeScript project:

```
assets/m/
├── index.html
├── vite.config.ts
├── tsconfig.json
├── svelte.config.js
├── package.json
├── src/
│   ├── main.ts
│   ├── App.svelte
│   ├── api/
│   │   ├── client.ts
│   │   ├── auth.ts
│   │   ├── conversations.ts
│   │   ├── messages.ts
│   │   ├── uploads.ts
│   │   └── lookups.ts
│   ├── channels/
│   │   ├── socket.ts
│   │   ├── chat.ts
│   │   ├── encryption.ts
│   │   └── presence.ts
│   ├── services/
│   │   ├── auth.ts
│   │   ├── notifier.ts
│   │   ├── crypto/
│   │   │   ├── service.ts
│   │   │   ├── keyManager.ts
│   │   │   ├── encryptor.ts
│   │   │   ├── decryptor.ts
│   │   │   └── rotation.ts
│   │   └── push/
│   │       ├── web.ts
│   │       └── native.ts
│   ├── models/
│   │   ├── user.ts
│   │   ├── conversation.ts
│   │   └── message.ts
│   ├── stores/
│   │   ├── auth.ts
│   │   ├── conversations.ts
│   │   ├── messages.ts
│   │   └── presence.ts
│   ├── views/
│   │   ├── LoginView.svelte
│   │   ├── ConversationListView.svelte
│   │   ├── ChatView.svelte
│   │   ├── SettingsView.svelte
│   │   └── UserPickerView.svelte
│   ├── components/
│   │   ├── MessageBubble.svelte
│   │   ├── ChatInput.svelte
│   │   ├── BottomNav.svelte
│   │   └── ReactionPicker.svelte
│   └── utils/
│       ├── pagination.ts
│       └── platform.ts
└── public/
    ├── manifest.json
    └── service-worker.js
```

### 3.2 API client

Create `assets/m/src/api/client.ts`:

```typescript
export const api = {
  get, post, patch, del, upload,
  refresh, websocketToken, setAuthHandler
}
```

- Browser: `credentials: "include"`.
- Native: attach `Authorization: Bearer <access_token>`.
- Auto-refresh on 401 using refresh token (native only; browser PWA relies on session cookie).
- Retry middleware: on network failure or 5xx, retry with exponential backoff (up to 3 attempts) for idempotent GET/HEAD requests. Timeouts tuned for mobile networks.

### 3.3 Auth flow

**Browser PWA:**
1. Load app.
2. Call `GET /api/v1/me` with credentials.
3. If 401, show LoginView with "Sign in with Google" → `/auth/google?mobile=true`.
4. `AuthController.callback/2` redirects to `/m` on success.
5. Call `/api/v1/socket_token` to get channel token.

**Native Capacitor:**
1. Detect `Capacitor.isNativePlatform()`.
2. Use `@capacitor/browser` for Google OAuth PKCE.
3. Handle deep link `com.medoru.app:/oauth2callback?code=...`.
4. POST `code` + `code_verifier` + `device_id` to `/api/v1/auth/native/exchange`.
5. Store access token in `@capacitor/preferences` (short-lived, 5 minutes) and refresh token in `@aparajita/capacitor-secure-storage` (Keychain/Keystore-backed).
6. Call `/api/v1/socket_token` with bearer token.

Add `POST /api/v1/auth/native/exchange` endpoint.

### 3.4 Svelte views

Implement Svelte components as outlined in directory structure.

### 3.5 Crypto services

Create:
- `assets/m/src/services/crypto/service.ts` — initializes user RSA keys.
- `assets/m/src/services/crypto/keyManager.ts` — conversation key cache, decryption.
- `assets/m/src/services/crypto/encryptor.ts` — message encryption.
- `assets/m/src/services/crypto/decryptor.ts` — message decryption.
- `assets/m/src/services/crypto/rotation.ts` — re-encryption for other users.

Share low-level primitives with the desktop crypto code, which lives in **`assets/js/hooks/chat_crypto.js`** (exports `CryptoState` with RSA-OAEP keypair generation and AES-GCM encrypt/decrypt helpers; related hooks: `chat_input.js`, `chat_key_manager.js`, `group_chat_creator.js`).

**Desktop compatibility:** Extract the crypto functions into a shared module without changing the desktop `ChatCrypto` hook's public API or behavior. The desktop chat continues to work exactly as before; the mobile app imports the same primitives.

### 3.6 Web Push

Create `assets/m/src/services/push/web.ts`:

- Register `/m/service-worker.js`.
- Subscribe with VAPID.
- POST subscription to `/api/push-subscribe`.

### 3.7 PWA manifest & service worker

Create `assets/m/public/manifest.json` and `assets/m/public/service-worker.js`.

Cache name: `medoru-mobile-${APP_VERSION}` where `APP_VERSION` is injected at build time.

### 3.8 Build integration

In `mix.exs`:

```elixir
"m.build": ["cmd cd assets/m && npm run build"],
"m.dev": ["cmd cd assets/m && npm run dev"],
"m.ios": ["m.build", "cmd cd clients/mobile && npx cap copy && npx cap open ios"],
"m.android": ["m.build", "cmd cd clients/mobile && npx cap copy && npx cap open android"]
```

Vite build outputs to `priv/static/mobile/` (filesystem) while the public URL remains `/m`.

---

## Phase 4: Capacitor Native Packaging

### 4.1 Project location

Create `clients/mobile/`:

```bash
npx cap init MedoruMobile com.medoru.app --web-dir ../../priv/static/mobile
npx cap add ios
npx cap add android
```

### 4.2 Native auth

Use `@capacitor/browser` for OAuth PKCE.

Implement PKCE helpers in `assets/m/src/services/auth/native.ts`.

### 4.3 Native push

Create `assets/m/src/services/push/native.ts`:

- Use `@capacitor/push-notifications`.
- On token received, POST to `/api/v1/push/token`.
- On notification tap, navigate to conversation.

### 4.4 Plugins

Configure:
- `@capacitor/status-bar`
- `@capacitor/splash-screen`
- `@capacitor/preferences`
- `@capacitor/browser`
- `@capacitor/push-notifications`

---

## Phase 5: Push Notification Abstraction

### 5.1 Notifier service

Create `lib/medoru/notifier.ex`:

```elixir
def notify(user_id, notification) do
  # notification is a struct such as %MessageNotification{conversation_id: ..., sender_name: ..., body: ...}
  # dispatch to browser subscriptions via WebPush
  # dispatch to native devices via APNs/FCM
end
```

Define notification structs in `lib/medoru/notifications/`:
- `MessageNotification`
- Future: `MentionNotification`, `FriendRequestNotification`, etc.

Create adapters:
- `lib/medoru/notifier/web_push.ex`
- `lib/medoru/notifier/apns.ex`
- `lib/medoru/notifier/fcm.ex`

### 5.2 Replace direct push calls

In `Medoru.Chat.maybe_notify_participants/3` (currently a **private** function, chat.ex:1111 — the change is an internal call-site swap only, the public context API is unchanged), replace `Notifications.send_push_notification/4` with `Notifier.notify/2`.

Keep existing Web Push subscriptions in `push_subscriptions` table for browser PWA.
Use `native_devices` table for native push tokens.

### 5.3 APNs/FCM config

In `config/runtime.exs`:

```elixir
config :medoru, :push,
  apns: [
    cert: System.get_env("APNS_CERT_PEM"),
    key: System.get_env("APNS_KEY_PEM"),
    mode: String.to_atom(System.get_env("APNS_MODE", "dev"))
  ],
  fcm: [
    service_account_json: System.get_env("FCM_SERVICE_ACCOUNT_JSON")
  ]
```

---

## Phase 6: Offline Foundation

For 0.10.0:

- Service worker caches shell + static assets.
- IndexedDB schema:
  - `profiles`
  - `conversations`
  - `messages` (last 200 per conversation)
- On load, render cached data immediately, then refresh.
- Queue outgoing messages in IndexedDB when offline; retry on reconnect.

Full offline sync deferred.

---

## Phase 7: Testing

### 7.1 API tests

Create `test/medoru_web/api/v1/`:
- `me_controller_test.exs`
- `auth_controller_test.exs`
- `conversation_controller_test.exs`
- `message_controller_test.exs`
- `reaction_controller_test.exs`
- `upload_controller_test.exs`
- `lookup_controller_test.exs`

Cover session auth, token auth, rate limiting, offset pagination, and the attachment upload flow.

### 7.2 Channel tests

Create `test/medoru_web/channels/`:
- `chat_channel_test.exs`
- `encryption_channel_test.exs`
- `presence_channel_test.exs`

### 7.3 Token tests

Create `test/medoru/tokens_test.exs` and `test/medoru/accounts/native_device_test.exs`.

### 7.4 Frontend tests

Add `vitest` in `assets/m` for services and stores.

### 7.5 Manual QA

- Browser PWA on Android/iOS.
- Capacitor simulators.
- Desktop ↔ mobile E2E encryption.
- Web Push and native push.

---

## Phase 8: Final Validation

1. `mix format --check-formatted`
2. `mix credo --strict`
3. `mix test`
4. `mix m.build`
5. Update `AGENTS.md` to `0.10.0`.

---

## Files to Create / Modify

### New files
- `lib/medoru/tokens.ex`
- `lib/medoru/accounts/native_device.ex`
- `lib/medoru/notifier.ex`
- `lib/medoru/notifier/web_push.ex`
- `lib/medoru/notifier/apns.ex`
- `lib/medoru/notifier/fcm.ex`
- `lib/medoru_web/api/v1/plugs/authenticate.ex`
- `lib/medoru_web/api/v1/plugs/rate_limit.ex`
- `lib/medoru_web/api/v1/spec.ex`
- `lib/medoru_web/api/v1/schemas.ex`
- `lib/medoru_web/api/v1/fallback_controller.ex`
- `lib/medoru_web/api/v1/controllers/me_controller.ex`
- `lib/medoru_web/api/v1/controllers/auth_controller.ex`
- `lib/medoru_web/api/v1/controllers/conversation_controller.ex`
- `lib/medoru_web/api/v1/controllers/message_controller.ex`
- `lib/medoru_web/api/v1/controllers/reaction_controller.ex`
- `lib/medoru_web/api/v1/controllers/upload_controller.ex`
- `lib/medoru_web/api/v1/controllers/lookup_controller.ex`
- `lib/medoru_web/api/v1/controllers/push_controller.ex`
- `lib/medoru_web/channels/user_socket.ex`
- `lib/medoru_web/channels/chat_channel.ex`
- `lib/medoru_web/channels/encryption_channel.ex`
- `lib/medoru_web/channels/presence_channel.ex`
- `lib/medoru_web/controllers/mobile_controller.ex`
- `lib/medoru_web/components/layouts/mobile.html.heex`
- `lib/medoru/chat/file_storage.ex` (or similarly named) — shared store/validate logic extracted from `ChatUploadController`, used by both the existing web controller and the new API upload controller.
- Migration for the `native_devices` table only (no uploads table — the existing `attachment_path` message fields are reused).
- `assets/m/` Vite + Svelte project.
- `clients/mobile/` Capacitor project.
- `priv/static/mobile/` built output.
- Tests under `test/medoru_web/api/v1/`, `test/medoru_web/channels/`.

### Modified files

All modifications are **additive** — existing routes, functions, and behavior are preserved:

- `mix.exs` — deps, aliases, version.
- `lib/medoru_web/router.ex` — new `/api/v1` scope and `/m` route (existing scopes untouched).
- `lib/medoru_web/endpoint.ex` — new `/socket` mount alongside `/live`.
- `lib/medoru_web/controllers/auth_controller.ex` — additive `mobile=true` redirect branch for the `/m` login flow (current redirects unchanged).
- `lib/medoru_web/controllers/chat_upload_controller.ex` — internals refactored to call the shared storage module; route/request/response unchanged.
- `lib/medoru_web/components/layouts.ex` — mobile layout.
- `lib/medoru/accounts.ex` — native device functions.
- `lib/medoru/accounts/api_token.ex` — unchanged (no refresh/device fields).
- `lib/medoru/chat.ex` — Notifier integration inside the private notify call site only; pagination reused as-is.
- `lib/medoru/chat/message.ex` — unchanged (UUIDv4 retained for 0.10.0).
- `lib/medoru/notifications.ex` — delegate to Notifier.
- `config/config.exs` — Hammer, JWT.
- `config/runtime.exs` — APNs/FCM, JWT secret.
- `config/dev.exs` — mobile dev server integration.
- `assets/js/hooks/chat_crypto.js` — extract crypto core into a shared module, hook API/behavior unchanged.
- `AGENTS.md` — version and state.

---

## Iteration Order (Recommended)

1. Phase 0: deps, version, green tests.
2. Phase 1.1–1.6: unified auth, JWT, native device schema, rate limiting.
3. Phase 1.7–1.14: all API controllers with web-style offset pagination and the reused attachment upload flow.
4. Phase 2: socket token + split channels.
5. Phase 5: Notifier abstraction + Web Push wiring.
6. Phase 3.1–3.5: Vite/Svelte shell, API client, auth, conversation list, chat view.
7. Phase 3.6–3.8: Web Push, manifest, service worker, build integration.
8. Phase 6: offline foundation.
9. Phase 4 + Phase 5 native: Capacitor project, PKCE, native push — **Android (APK) first**, iOS second.
10. Phase 7–8: tests, validation, docs.

This order ships a working browser PWA first, then layers native packaging and push.
