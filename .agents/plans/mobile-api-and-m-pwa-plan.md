# Plan: Medoru Mobile API (`/api/v1`) and `/m` Chat PWA

**Goal:** Build a standalone mobile-first chat PWA at `/m` backed by a new Phoenix REST API (`/api/v1`), without breaking the existing site or PWA. The first release covers 1-1 and group chats only; classroom chats come later with the classroom selector.

**Non-goal for this plan:** Classroom mode, offline sync, Apple/email auth, store submission.

---

## Architecture Decisions

1. **API is REST + OpenAPI 3**, served by `open_api_spex`. Swagger UI at `/api/swagger`.
2. **Auth uses the existing session cookie**, not API tokens. The `/m` PWA is a first-party client, so cookie-based auth is simpler and secure. API tokens remain for third-party integrations.
3. **Real-time chat uses existing Phoenix PubSub / LiveView channels**, not a separate WebSocket API. The `/m` PWA connects to the same `chat:<conversation_id>` topics the desktop site uses.
4. **End-to-end encryption stays in the client.** The API transports ciphertext; the `/m` PWA reuses or ports the existing `chat_crypto.js` logic.
5. **File uploads reuse `ChatUploadController`** under `/api/v1/chat/upload`.
6. **The existing site is untouched.** New code is isolated to `/api/v1/*` routes and `/m/*` LiveView routes. The existing manifest and service worker stay at `/`; `/m` gets its own manifest and scoped service worker.

---

## Phase 1: API Foundation

### 1.1 Add dependencies
- Add `open_api_spex` to `mix.exs` and run `mix deps.get`.

### 1.2 Create the API pipeline and router
- Add a new pipeline `:mobile_api` in `lib/medoru_web/router.ex`:
  - `plug :accepts, ["json"]`
  - `plug :fetch_session`
  - `plug :put_secure_browser_headers`
  - `plug MedoruWeb.UserAuth, :fetch_current_user`
- Add a new scope `/api/v1` under `MedoruWeb.API` namespace.
- Add `/api/swagger` route for Swagger UI.

### 1.3 Auth endpoint
- `GET /api/v1/me` — returns current user (id, email, name, avatar, profile).
- `POST /api/v1/auth/logout` — clears session.
- Reuse Google OAuth at `/auth/google/callback`; after login redirect to `/m` when a `?mobile=true` param is present.

### 1.4 Conversation endpoints
- `GET /api/v1/conversations` — list 1-1 and group conversations for current user, with last message metadata, unread count, and participant info.
- `POST /api/v1/conversations` — create a 1-1 or group conversation.
- `GET /api/v1/conversations/:id` — conversation details + participants + current user’s keys.
- `GET /api/v1/conversations/:id/messages?limit=&offset=` — paginated messages (ciphertext, plaintext, attachments, reactions).
- `POST /api/v1/conversations/:id/messages` — send encrypted or plaintext message, with optional attachment metadata and `reply_to_message_id`.
- `DELETE /api/v1/conversations/:id/messages/:message_id` — delete own message.
- `PATCH /api/v1/conversations/:id/messages/:message_id` — edit own plaintext message.
- `POST /api/v1/conversations/:id/read` — mark conversation as read.

### 1.5 Reaction endpoints
- `POST /api/v1/conversations/:id/messages/:message_id/reactions` — add reaction.
- `DELETE /api/v1/conversations/:id/messages/:message_id/reactions/:emoji` — remove reaction.

### 1.6 Attachment endpoint
- `POST /api/v1/chat/upload` — wraps existing `ChatUploadController.create/2` logic for API clients.

### 1.7 Special-command lookup endpoints
- `GET /api/v1/words/lookup?text=` — for `/word` and `/w` commands.
- `GET /api/v1/kanji/lookup?character=` — for `/kanji` and `/k` commands.
- `GET /api/v1/grammars/lookup?pattern=` — for `/grammar` and `/g` commands.

### 1.8 OpenAPI schemas and specs
- Define request/response schemas in `lib/medoru_web/api/schemas.ex`.
- Define operation specs on each API controller action.
- Mount Swagger UI at `/api/swagger`.

---

## Phase 2: `/m` PWA Chat Shell

### 2.1 New mobile layout and assets
- Create `lib/medoru_web/components/layouts/mobile.html.heex` — minimal shell with no desktop chrome, safe-area insets, and bottom tab bar.
- Create `assets/js/m_app.js` and `assets/css/m_app.css` for the mobile bundle.
- Update `config/config.exs` (or `assets/esbuild.config.js`) to build the new bundle.
- Create `/m/manifest.json` and `/m/service-worker.js` scoped to `/m/*`.

### 2.2 Mobile router scope
- Add `/m` scope in `lib/medoru_web/router.ex` with a `:mobile` pipeline:
  - Reuses `:browser` but renders the mobile layout.
  - Requires authenticated user.
- Routes:
  - `live "/m", Mobile.ChatLive.Index` — conversation list.
  - `live "/m/conversations/:id", Mobile.ChatLive.Show` — chat view.
  - `live "/m/login", Mobile.AuthLive.Login` — mobile login (redirects to Google OAuth).
  - `live "/m/settings", Mobile.SettingsLive.Index` — minimal settings (logout, profile).

### 2.3 Login flow
- Mobile login page shows Google button.
- Button goes to `/auth/google?mobile=true`.
- `AuthController.callback/2` checks for mobile param and redirects to `/m` after successful login.
- Session cookie is shared across `/` and `/m`.

### 2.4 Conversation list (`Mobile.ChatLive.Index`)
- Fetch conversations from `/api/v1/conversations` via `Req` or `fetch`.
- Display messenger-style list: avatar, name, last message preview, timestamp, unread badge.
- Pull-to-refresh support.
- Floating “New chat” button.

### 2.5 Chat view (`Mobile.ChatLive.Show`)
- Load messages via `/api/v1/conversations/:id/messages`.
- Join the existing `chat:<conversation_id>` channel for real-time new messages, edits, deletes, reactions, typing, and read receipts.
- Reuse or port `chat_crypto.js` functions for E2E encrypt/decrypt and key management.
- Support:
  - Sending plaintext and encrypted messages.
  - Attachments (image, voice, audio, video, document) via `/api/v1/chat/upload`.
  - Voice recording using the media recorder API.
  - Reactions.
  - Reply-to.
  - Edit/delete own messages.
  - Link previews.
  - Special commands (`/word`, `/kanji`, `/grammar`) using lookup endpoints.
  - Typing indicators and read receipts via the channel.
- Media folder with the same pagination component used on desktop.

### 2.6 Push notifications
- Reuse existing push subscription API (`/api/push-subscribe`).
- Service worker handles notification click to open `/m/conversations/:id`.

---

## Phase 3: Polish and Wrap

### 3.1 PWA polish
- Install prompt for Android.
- iOS “Add to Home Screen” guidance.
- Splash screen, themed status bar, standalone display mode.
- Handle deep links (`/m/conversations/:id`) from notifications.

### 3.2 Capacitor wrapper (optional, later)
- Initialize Capacitor project in a `mobile/` directory.
- Point web dir to `priv/static` or a production build.
- Configure deep links and native push.
- Build for Android/iOS internal testing.

---

## Testing Strategy

1. **API tests** in `test/medoru_web/api/`:
   - Authentication and authorization.
   - Conversation CRUD.
   - Message pagination, send, edit, delete.
   - Reactions and read receipts.
   - File uploads.
   - OpenAPI spec validity via `open_api_spex` test helpers.

2. **LiveView tests** in `test/medoru_web/live/mobile/`:
   - Login redirect.
   - Conversation list rendering.
   - Chat view message loading.

3. **Manual QA**:
   - Test on actual Android/iOS devices in browser.
   - Verify E2E encryption between desktop and mobile users.
   - Verify push notifications.

---

## Files to Create / Modify

### New files
- `lib/medoru_web/api/schemas.ex`
- `lib/medoru_web/api/controllers/me_controller.ex`
- `lib/medoru_web/api/controllers/conversation_controller.ex`
- `lib/medoru_web/api/controllers/message_controller.ex`
- `lib/medoru_web/api/controllers/reaction_controller.ex`
- `lib/medoru_web/api/controllers/upload_controller.ex`
- `lib/medoru_web/api/controllers/lookup_controller.ex`
- `lib/medoru_web/live/mobile/chat_live/index.ex`
- `lib/medoru_web/live/mobile/chat_live/index.html.heex`
- `lib/medoru_web/live/mobile/chat_live/show.ex`
- `lib/medoru_web/live/mobile/chat_live/show.html.heex`
- `lib/medoru_web/live/mobile/auth_live/login.ex`
- `lib/medoru_web/live/mobile/settings_live/index.ex`
- `lib/medoru_web/components/layouts/mobile.html.heex`
- `priv/static/m/manifest.json`
- `priv/static/m/service-worker.js`
- `assets/js/m_app.js`
- `assets/css/m_app.css`
- Tests under `test/medoru_web/api/` and `test/medoru_web/live/mobile/`

### Modified files
- `mix.exs` — add `open_api_spex`.
- `lib/medoru_web/router.ex` — API pipeline, `/api/v1` scope, `/m` scope, Swagger UI.
- `lib/medoru_web/controllers/auth_controller.ex` — mobile redirect after OAuth.
- `lib/medoru_web/components/layouts.ex` — add mobile layout.
- `config/config.exs` or esbuild config — add `m_app.js` bundle.

---

## Suggested First Iteration (MVP)

To get something usable quickly, implement only:

1. `GET /api/v1/me`
2. `GET /api/v1/conversations`
3. `GET /api/v1/conversations/:id/messages`
4. `POST /api/v1/conversations/:id/messages` (plaintext only, no encryption)
5. `/m/login`, `/m`, `/m/conversations/:id` with conversation list and chat view.
6. Reuse existing channel for real-time delivery.

This gives a working mobile chat in the first iteration. E2E encryption, attachments, reactions, and special commands follow in subsequent iterations.
