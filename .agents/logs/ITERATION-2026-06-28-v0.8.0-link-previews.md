# Iteration Log: Link Previews in Posts, Comments, and Chats

**Date:** 2026-06-28
**Version:** v0.8.0
**Branch:** master

## Goal
Add rich link previews (like Facebook/Discord) when users share external URLs in:
- White board posts
- White board comments
- Dashboard stream posts/comments
- Classroom chat messages
- Encrypted 1:1 and group chat messages

## Implementation

### Database & Context
- Migration `priv/repo/migrations/20260628000000_create_link_previews.exs` creates the `link_previews` cache table with `url`, `title`, `description`, `image_url`, `site_name`, `favicon_url`, `status`, `error_message`, and `fetched_at`.
- Schema `lib/medoru/link_previews/link_preview.ex`.
- Context `lib/medoru/link_previews.ex` exposes:
  - `get_or_fetch_preview/1` — returns cached preview or creates a pending record and fetches asynchronously.
  - `get_preview/1` — cached lookup only.
  - `preview_for_text/1` — triggers fetch and returns fetched preview or `nil`.
  - `cached_preview_for_text/1` — render-safe lookup that does not trigger fetches.
  - PubSub subscribe/broadcast helpers.

### Fetcher
- `lib/medoru/link_previews/fetcher.ex` uses `Req` + `Floki`.
- URL normalization (lowercase scheme/host, strip fragments, trailing punctuation).
- Security: rejects non-http(s), localhost, private IP ranges, `.local`/`.internal` hosts.
- Request limits: 5s connect/receive timeout, max 3 redirects, 2 MB body cap, bot user-agent.
- Parses `og:title`, `og:description`, `og:image`, `og:site_name`, falls back to `<title>` and `<meta name="description">`, and absolutizes image/favicon URLs.
- Failed previews are cached for 24h to avoid retry storms; successful previews refresh after 7 days.

### API
- `lib/medoru_web/controllers/link_preview_controller.ex` and `GET /api/link-preview` return preview JSON for the encrypted chat client.

### UI Component
- `lib/medoru_web/components/link_preview_card.ex` renders a compact card (image, favicon + hostname, title, description).

### Server-Side Rendering
- `lib/medoru_web/white_board_post_renderer.ex` appends a preview card after the rendered body when a cached preview exists.
- `lib/medoru_web/live/messages_live/show.ex` and `lib/medoru_web/live/classroom_live/show.ex` append preview cards to plaintext chat messages.
- YouTube links keep their existing inline iframe behavior and do not get an OG preview card.

### Encrypted Chat Client
- `assets/js/hooks/chat_crypto.js` fetches `/api/link-preview` for the first non-YouTube URL in a decrypted message and appends a preview card client-side with a per-session cache.

### Live Updates
- `lib/medoru_web/link_preview_subscribers.ex` helper lets LiveViews subscribe to preview topics for a collection of texts.
- `UserWhiteBoardLive`, `UserWhiteBoardPostLive`, `DashboardLive`, `MessagesLive.Show`, and `ClassroomLive.Show` subscribe on mount and when new content loads.
- `:link_preview_ready` PubSub messages bump a `link_preview_tick` assign, causing the LiveView to re-render with the new cached preview.

### Dependencies
- Added `{:floki, "~> 0.36"}` to `mix.exs`.

## Files Changed

- `mix.exs`
- `lib/medoru/link_previews/link_preview.ex` (new)
- `lib/medoru/link_previews.ex` (new)
- `lib/medoru/link_previews/fetcher.ex` (new)
- `lib/medoru_web/controllers/link_preview_controller.ex` (new)
- `lib/medoru_web/components/link_preview_card.ex` (new)
- `lib/medoru_web/link_preview_subscribers.ex` (new)
- `lib/medoru_web/router.ex`
- `lib/medoru_web/white_board_post_renderer.ex`
- `lib/medoru_web/live/messages_live/show.ex`
- `lib/medoru_web/live/classroom_live/show.ex`
- `lib/medoru_web/live/user_white_board_live.ex`
- `lib/medoru_web/live/user_white_board_post_live.ex`
- `lib/medoru_web/live/dashboard_live.ex`
- `assets/js/app.js`
- `assets/js/hooks/chat_crypto.js`
- `assets/js/hooks/word_color_apply_to.js`
- `priv/repo/migrations/20260628000000_create_link_previews.exs` (new)
- `test/medoru/link_previews_test.exs` (new)
- `test/medoru_web/controllers/link_preview_controller_test.exs` (new)
- `test/medoru_web/white_board_post_renderer_test.exs`
- `test/medoru_web/live/user_white_board_live_test.exs`
- `AGENTS.md`

## Tests Added

- `Medoru.LinkPreviewsTest` — URL normalization, validation, extraction, caching.
- `MedoruWeb.LinkPreviewControllerTest` — API endpoint returns cached/pending previews.
- `MedoruWeb.WhiteBoardPostRendererTest` — posts and comments render preview cards for cached URLs.
- `MedoruWeb.UserWhiteBoardLiveTest` — white board post renders preview card.

## Verification

- `mix deps.get` — fetched `floki`.
- `mix ecto.migrate` — `create_link_previews` applied.
- `mix compile --warnings-as-errors` — clean.
- `mix format --check-formatted` — clean.
- Targeted tests — 58 tests, 0 failures.
- Full suite — pending.
