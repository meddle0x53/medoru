# Iteration 4: Lessons System

**Status**: COMPLETED  
**Date**: 2026-03-06  
**Reviewed By**: meddle  
**Approved**: PENDING REVIEW

---

## Summary

Iteration 4 is complete. The Lessons System provides structured learning paths where users can browse lessons organized by JLPT level, each containing 1-10 kanji to learn.

## What Was Implemented

### 1. Schemas Created

- **`Medoru.Content.Lesson`** - Title, description, difficulty (1-5), order_index (for sequencing)
- **`Medoru.Content.LessonKanji`** - Join table linking lessons to kanji with position tracking

### 2. Migrations

- `20260306075336_create_lessons.exs` - Lessons table with composite unique index on (difficulty, order_index)
- `20260306075344_create_lesson_kanjis.exs` - Lesson-kanji join table with unique constraints

### 3. Content Context Updates (`lib/medoru/content.ex`)

Key functions:
- `list_lessons/0` - List all lessons ordered by difficulty and order
- `list_lessons_by_difficulty/1` - Filter by JLPT difficulty level (1-5)
- `get_lesson!/1` - Get lesson by ID
- `get_lesson_with_kanji!/1` - Get lesson with kanji preloaded
- `create_lesson/1` - Create lesson
- `create_lesson_with_kanji/2` - Transaction to create lesson with kanji links
- Full CRUD for lesson_kanjis

### 4. Seed Data

- `priv/repo/seeds/lessons_n5.json` - 10 N5 lessons with 5-10 kanji each:
  1. Basics: Numbers
  2. People & Self
  3. Nature Elements
  4. Time & Dates
  5. Places & Directions
  6. Education & Work
  7. Size & Quantity
  8. Actions & Movement
  9. Country & World
  10. Daily Life

### 5. LiveViews

- **`MedoruWeb.LessonLive.Index`** - Browse lessons by JLPT difficulty
  - List view with lesson number badges
  - Kanji count per lesson
  - Difficulty selector (N1-N5)
  - Links to detail page

- **`MedoruWeb.LessonLive.Show`** - Lesson detail view
  - Title, description, lesson number
  - Progress bar (placeholder for authenticated users)
  - Grid of kanji in the lesson
  - "Start Learning" / "Sign in" button
  - Back navigation

### 6. Routes & Navigation

- `/lessons` - Lesson browser (public)
- `/lessons/:id` - Lesson detail (public)
- Updated "Lessons" link in navigation (was placeholder, now functional)

### 7. Validation

- Difficulty must be 1-5
- Order index must be non-negative
- Unique constraint on (difficulty, order_index)
- Unique constraint on (lesson_id, kanji_id) - no duplicate kanji in same lesson

### 8. Tests

- **`test/medoru/content_test.exs`** - 30 new tests for Lesson and LessonKanji
  - CRUD operations
  - Validation tests
  - Transaction rollback tests
  - Association tests

- **`test/medoru_web/live/lesson_live_test.exs`** - 13 LiveView tests
  - Index page tests (list, filter, navigation)
  - Show page tests (details, kanji display, progress)
  - Authenticated vs anonymous user tests

## Test Results

```
Running ExUnit with seed: 978995, max_cases: 48
............................................................................................................................................................
Finished in 2.2 seconds (1.1s async, 1.0s sync)
157 tests, 0 failures
```

## Code Quality

- `mix precommit` passes
- Zero compiler warnings
- All 157 tests passing (118 from previous + 39 new)

## Key Design Decisions

1. **Order Index** - Lessons have an order_index for proper sequencing within each difficulty level
2. **Position Tracking** - LessonKanjis track position for potential reordering
3. **No Duplicate Kanji** - Same kanji can't be added twice to one lesson
4. **Public Access** - Lessons are browsable by anyone; progress tracking requires auth
5. **Template Separation** - Both LiveViews use extracted `.html.heex` templates following project convention
6. **Preloading** - `list_lessons_by_difficulty/1` preloads `lesson_kanjis` to avoid N+1 queries

## Files Created/Modified

### New Files (12):
- `lib/medoru/content/lesson.ex`
- `lib/medoru/content/lesson_kanji.ex`
- `lib/medoru_web/live/lesson_live/index.ex`
- `lib/medoru_web/live/lesson_live/index.html.heex`
- `lib/medoru_web/live/lesson_live/show.ex`
- `lib/medoru_web/live/lesson_live/show.html.heex`
- `priv/repo/migrations/20260306075336_create_lessons.exs`
- `priv/repo/migrations/20260306075344_create_lesson_kanjis.exs`
- `priv/repo/seeds/lessons_n5.json`
- `test/medoru_web/live/lesson_live_test.exs`
- `.agents/logs/ITERATION-04-lessons.md`

### Modified Files (4):
- `lib/medoru/content.ex` - Added Lesson and LessonKanji functions
- `priv/repo/seeds.exs` - Added lesson seeding logic
- `lib/medoru_web/router.ex` - Added lesson routes, removed placeholder
- `test/support/fixtures/content_fixtures.ex` - Added lesson fixtures
- `test/medoru/content_test.exs` - Added lesson tests

## Database Status

- ✅ `lessons` table created with indexes
- ✅ `lesson_kanjis` table created with foreign keys and unique constraints

## Next Steps (Iteration 5)

**Learning Core**
- UserProgress schema - track learned kanji/words, mastery level
- LessonProgress schema - started/completed lessons
- Learning context - start/complete lessons
- "Learn" mode UI - lesson study interface
- Tests for progress tracking

---

**Ready for review. Please review the changes and approve to proceed to Iteration 5.**
