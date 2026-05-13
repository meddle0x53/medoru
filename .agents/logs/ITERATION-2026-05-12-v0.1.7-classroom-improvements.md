# Iteration Log: v0.1.7 Classroom Improvements

**Date**: 2026-05-12
**Status**: Complete
**Tests**: 707 passing

---

## Changes Summary

### Kana Memory Card Game (continued)
- Fixed board sizes to 4x4 and 6x6 (was 8x8/10x10)
- Split hiragana/katakana row toggles in creation form
- Fixed `phx-change` field detection using `_target` fallback
- Fixed `validate_kana_answer` to compare romaji against `kana.readings`

### Classroom Settings Editing
- Added `update_classroom/3` with teacher authorization
- Inline edit form in Settings tab for name and description
- Blur-debounced inputs to prevent value loss on checkbox clicks

### Membership Auto-Approval
- Added `should_approve_memberships` boolean to classrooms (default true)
- `apply_to_join` auto-approves when false, skips teacher notification
- Toggle on creation form and settings edit
- Student join UIs show appropriate messages/badges per setting

### Public Classrooms
- Added `public` boolean to classrooms (default false)
- `list_visible_classrooms/2`: public + joined + owned with search/pagination
- Student `/classrooms` tab shows visible classrooms with search field
- Classroom cards show Owner/Member/Public badges with appropriate actions
- Teachers can set public/private on creation and in settings

### Lesson Reordering Bug Fix
- `ensure_lesson_order_indices` now detects duplicates, not just uniform indices
- Production migration fixes all existing duplicate `order_index` values

### Self-Join Prevention
- Teachers can no longer join their own classrooms via invite code or public listing

---

## Files Modified

### Migrations
- `priv/repo/migrations/20260512112304_add_should_approve_memberships_to_classrooms.exs`
- `priv/repo/migrations/20260512114227_add_public_to_classrooms.exs`
- `priv/repo/migrations/20260512122733_fix_duplicate_lesson_order_indices.exs`

### Schema
- `lib/medoru/classrooms/classroom.ex`

### Context
- `lib/medoru/classrooms.ex`
- `lib/medoru/games.ex`

### LiveViews
- `lib/medoru_web/live/teacher/classroom_live/show.ex`
- `lib/medoru_web/live/teacher/classroom_live/new.ex`
- `lib/medoru_web/live/teacher/kana_game_live/form.ex`
- `lib/medoru_web/live/teacher/kana_game_live/form.html.heex`
- `lib/medoru_web/live/classroom_game_live/play.ex`
- `lib/medoru_web/live/classroom_live/index.ex`
- `lib/medoru_web/live/classroom_live/join.ex`

---

## Deployment Notes

Run `mix ecto.migrate` on production to apply all three migrations.
