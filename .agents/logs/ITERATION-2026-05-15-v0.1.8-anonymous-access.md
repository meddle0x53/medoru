# Iteration Log: v0.1.8 Anonymous Public Access

**Date**: 2026-05-15
**Status**: In Progress (v0.1.8)
**Tests**: 761 passing, 0 failures

---

## Changes Summary

### Featured Public Classroom
- New `site_settings` table with `featured_classroom_id`
- `SiteSettings` context with singleton pattern (one row)
- Admin dashboard "Site Settings" card with dropdown to select from public classrooms
- `PublicAccess` helper module for verifying featured classroom access

### Anonymous Navigation
- `/games` and `/lessons` routes moved to `:public` live_session
- Layout nav shows Games/Lessons links for anonymous users
- Anonymous users see featured classroom content on `/games` and `/lessons`
- Authenticated users see their own classroom content as before

### Anonymous Game Play
- **Memory Card Games** (`ClassroomGameLive.Play`):
  - In-memory anonymous session struct mimicking `MemoryCardSession`
  - Full game logic replicated: flip, match, collect, input validation, reset
  - Supports both word memory cards and kana memory cards
  - Game over shows score + "Sign in to Save Progress" CTA
- **Kana Cascade** (`KanaFallingGameLive.Play`): Already supported anonymous; skips DB save
- **Kanji Cascade** (`KanjiFallingGameLive.Play`): Already supported anonymous; skips DB save
- **Game Rankings** (`ClassroomGameLive.Rankings`): Anonymous users can view featured classroom rankings

### Anonymous Lesson Study
- `ClassroomLive.CustomLesson`: Anonymous users can view featured classroom lessons
- Progress tracking skipped (no DB writes)
- Required tests are skipped for anonymous users (redirected to completion)
- `ClassroomLive.CustomLessonComplete`: Simplified completion screen for anonymous users
  - No "mark as learned" section
  - Shows sign-in CTA to save progress

### Bug Fixes
- **Admin dashboard crash**: `classroom.teacher.display_name` → `classroom.teacher.name` (profile not loaded)
- **Games index crash**: Added `:classroom` preload to `Games.list_classroom_games/2`
- **Lesson links for anonymous**: Fixed to point to public classroom routes (`/classrooms/:id/custom-lessons/:lesson_id`)

---

## Files Modified

### New Files
- `lib/medoru/site_settings/site_setting.ex` — Schema
- `lib/medoru/site_settings.ex` — Context
- `lib/medoru_web/live/public_access.ex` — Helper module

### Migrations
- `priv/repo/migrations/*_create_site_settings.exs`

### LiveViews
- `lib/medoru_web/live/admin/dashboard_live.ex` — Featured classroom setting
- `lib/medoru_web/live/admin/dashboard_live/dashboard.html.heex` — Site Settings card
- `lib/medoru_web/live/games_live/index.ex` — Anonymous support + published filter
- `lib/medoru_web/live/lesson_live/index.html.heex` — Anonymous lesson links fix
- `lib/medoru_web/live/classroom_game_live/play.ex` — Anonymous session support
- `lib/medoru_web/live/classroom_game_live/rankings.ex` — Anonymous access
- `lib/medoru_web/live/classroom_live/custom_lesson.ex` — Anonymous lesson study
- `lib/medoru_web/live/classroom_live/custom_lesson_complete.ex` — Anonymous completion
- `lib/medoru_web/live/kana_falling_game_live/play.ex` — Anonymous game over (pre-existing)
- `lib/medoru_web/live/kanji_falling_game_live/play.ex` — Anonymous game over (pre-existing)

### Contexts
- `lib/medoru/classrooms.ex` — `list_public_classrooms/0`
- `lib/medoru/games.ex` — `:classroom` preload in `list_classroom_games/2`

### Router
- `lib/medoru_web/router.ex` — `/games` and `/lessons` in `:public` session

---

## Deployment Notes

Migration required: `site_settings` table creation.

---

## Architecture Notes

Anonymous game sessions use plain maps with the same shape as `MemoryCardSession`:
- `id: :anonymous`, `status: :in_progress | :completed`
- `score`, `attempts_used`, `max_attempts`, `cards_state`, `game_id`

All template helper functions (`card_states/1`, `game_over?/1`, `attempts_remaining/1`) work unchanged because they access fields via map/struct field access, which is polymorphic between Ecto structs and plain maps.
