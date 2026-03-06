# Iteration 5: Learning Core

**Status**: APPROVED  
**Date**: 2026-03-06  
**Reviewed By**: meddle  
**Approved**: YES

---

## Summary

Iteration 5 is complete. The Learning Core provides user progress tracking for lessons, kanji, and words with an interactive study interface.

## What Was Implemented

### 1. Schemas Created

- **`Medoru.Learning.UserProgress`** - Tracks individual kanji/word mastery:
  - `user_id`, `kanji_id`, `word_id` (polymorphic - either kanji OR word)
  - `mastery_level` (0-4: New → Learning → Mastered)
  - `times_reviewed`, `last_reviewed_at`, `next_review_at` (for SRS)
  - Validation ensures exactly one of kanji_id or word_id is present

- **`Medoru.Learning.LessonProgress`** - Tracks lesson completion:
  - `user_id`, `lesson_id`
  - `status` (:started, :completed)
  - `started_at`, `completed_at`, `progress_percentage`

### 2. Migrations

- `20260306102526_create_user_progress.exs` - User progress table with indexes
- `20260306102530_create_lesson_progress.exs` - Lesson progress table with indexes

### 3. Learning Context (`lib/medoru/learning.ex`)

Key functions:
- `start_lesson/2` - Begin lesson tracking
- `get_lesson_progress/2`, `list_lesson_progress/1` - Query lesson progress
- `update_lesson_progress/3`, `complete_lesson/2` - Update progress
- `track_kanji_learned/2`, `track_word_learned/2` - Mark content as learned
- `update_kanji_mastery/3`, `update_word_mastery/3` - Update mastery levels
- `get_user_stats/1` - Aggregate statistics

### 4. Content Context Updates

- `get_lesson_for_learning!/1` - New function that preloads words with full kanji/reading data

### 5. LiveViews

- **`MedoruWeb.LearnLive`** - Interactive lesson study interface:
  - `/lessons/:lesson_id/learn` - Study mode URL
  - Word-by-word navigation (Next/Previous)
  - Kanji breakdown with readings and meanings
  - Progress bar showing completion percentage
  - "Mark as Learned" button for authenticated users
  - Auto-advance after marking learned
  - "Finish Early" option
  - Completion screen with celebration

### 6. Routes & Navigation

- `/lessons/:lesson_id/learn` - Learn mode route
- Updated LessonLive.Show button to link to learn mode
- Works for both authenticated (tracks progress) and anonymous (preview) users

### 7. Validation

- UserProgress: Exactly one of kanji_id or word_id must be present
- Mastery level: 0-4 range
- Unique constraints on (user_id, kanji_id) and (user_id, word_id)
- LessonProgress: Unique constraint on (user_id, lesson_id)

### 8. Tests

- **`test/medoru/learning_test.exs`** - 55 new tests:
  - Lesson progress CRUD
  - User progress (kanji/word) CRUD
  - Mastery level updates
  - Statistics aggregation
  - Validation tests

- **`test/medoru_web/live/learn_live_test.exs`** - 15 LiveView tests:
  - Render tests (authenticated/anonymous)
  - Navigation (next/previous)
  - Progress tracking
  - Completion flow
  - Kanji breakdown display

- **New fixture file**: `test/support/fixtures/learning_fixtures.ex`

## Test Results

```
Running ExUnit with seed: 966069, max_cases: 64
212 tests, 0 failures
```

## Code Quality

- `mix precommit` passes
- All 212 tests passing (157 from previous + 55 new)

## Key Design Decisions

1. **Polymorphic UserProgress** - Single table tracks both kanji and word progress with mutual exclusivity validation
2. **Progress Percentage** - Calculated based on word position in lesson
3. **Anonymous Preview** - Learn mode accessible without login, but progress only tracked for authenticated users
4. **Auto-advance** - Marking a word as learned automatically advances to next word
5. **Mastery Levels** - 0 (New), 1-3 (Learning), 4 (Mastered) - foundation for future SRS

## Files Created/Modified

### New Files (10):
- `lib/medoru/learning/user_progress.ex`
- `lib/medoru/learning/lesson_progress.ex`
- `lib/medoru/learning.ex`
- `lib/medoru_web/live/learn_live.ex`
- `priv/repo/migrations/20260306102526_create_user_progress.exs`
- `priv/repo/migrations/20260306102530_create_lesson_progress.exs`
- `test/support/fixtures/learning_fixtures.ex`
- `test/medoru/learning_test.exs`
- `test/medoru_web/live/learn_live_test.exs`
- `.agents/logs/ITERATION-05-learning-core.md`

### Modified Files (4):
- `lib/medoru/content.ex` - Added `get_lesson_for_learning!/1`
- `lib/medoru_web/router.ex` - Added learn route
- `lib/medoru_web/live/lesson_live/show.html.heex` - Updated button to link to learn mode
- `test/medoru_web/live/lesson_live_test.exs` - Updated test for new button text

## Database Status

- ✅ `user_progress` table created with indexes
- ✅ `lesson_progress` table created with indexes

## Bug Fixes (Post-Completion)

### Fix: Lesson Progress Visibility

**Problem**: Completed lessons were not showing completion status in the UI.

**Changes Made**:
1. **`LessonLive.Show`** - Now fetches and displays actual lesson progress:
   - Shows "Completed!" badge when lesson is done
   - Shows actual word progress count (X/Y words learned)
   - Shows completion date
   - Progress bar shows actual percentage
   - Button changes to "Review Lesson" (green) for completed lessons
   - Button shows "Continue Learning" for in-progress lessons

2. **`LessonLive.Index`** - Now shows completion badges:
   - Green checkmark icon for completed lessons
   - "Completed" badge on lesson card
   - Shows progress percentage for in-progress lessons
   - Visual distinction with green styling for completed lessons

3. **`Learning Context`** - Added `count_learned_words_in_lesson/2` function

### Modified Files (Additional):
- `lib/medoru_web/live/lesson_live/show.ex` - Added progress fetching
- `lib/medoru_web/live/lesson_live/show.html.heex` - Updated progress display
- `lib/medoru_web/live/lesson_live/index.ex` - Added progress map
- `lib/medoru_web/live/lesson_live/index.html.heex` - Added completion badges
- `lib/medoru/learning.ex` - Added `count_learned_words_in_lesson/2`

## Feature: Lesson Types

Added `lesson_type` field to lessons to support different learning modes:

**Types:** `:reading`, `:writing`, `:listening`, `:speaking`, `:grammar`

**Current state:** All existing lessons are set to `:reading` (default)

**Changes:**
- Migration: `20260306111102_add_lesson_type.exs` - PostgreSQL enum type
- Schema: `Lesson.lesson_type` with Ecto.Enum
- Context: `list_lessons_by_type/1` function
- Seeds: Support for optional `lesson_type` in JSON

### Modified Files (Lesson Types):
- `lib/medoru/content/lesson.ex` - Added lesson_type field and validation
- `lib/medoru/content.ex` - Added `list_lessons_by_type/1`
- `priv/repo/migrations/20260306111102_add_lesson_type.exs` - New migration
- `priv/repo/seeds.exs` - Handle lesson_type in seeding

### UI Changes (Lesson Type Indicators):
- `lib/medoru_web/live/lesson_live/index.html.heex` - Type badge on lesson cards
- `lib/medoru_web/live/lesson_live/show.html.heex` - Type badge in lesson header

**Type Badge Colors & Icons:**
| Type | Color | Icon |
|------|-------|------|
| reading | Blue | book-open |
| writing | Purple | pencil |
| listening | Orange | speaker-wave |
| speaking | Pink | chat-bubble-left-right |
| grammar | Teal | wrench |

## Feature: Japanese-Inspired Theme

Complete visual redesign with a Japanese-inspired color palette:

**Color Palette:**
- **Primary**: Dark Green (Japanese forest/moss) - `oklch(45% 0.12 145)`
- **Secondary**: Tree Brown - `oklch(50% 0.08 75)`
- **Accent**: Sakura Pink - `oklch(75% 0.15 15)`
- **Base**: Warm off-white with subtle green undertones

**Changes:**
- Updated both light and dark themes in `app.css`
- Replaced all indigo/slate colors with theme-aware DaisyUI classes
- Navigation, buttons, badges now use the Japanese color palette
- Future themes can be unlocked by learning (planned for later milestones)

### Modified Files (Theme):
- `assets/css/app.css` - Complete theme overhaul with Japanese colors
- `lib/medoru_web/components/layouts.ex` - Updated to use theme classes
- All LiveView templates updated to use `bg-primary`, `text-primary`, etc.
- Tests updated to match new CSS classes

---

**Ready for review. Please review the changes and approve to proceed to Iteration 6.**
