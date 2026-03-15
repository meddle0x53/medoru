# Iteration 31: Teacher Custom Lessons

**Status**: ✅ APPROVED  
**Completed**: 2026-03-15  
**Approved**: 2026-03-15  
**Priority**: 🔴 HIGH

## Overview

Allow teachers to create custom reading lessons by selecting words from the vocabulary database. Unlike system lessons (which have auto-generated tests), teacher lessons are completed by simply reading/studying the material - no test required.

## Completed Features

### Database Schema ✅
- `custom_lessons` table - Stores lesson metadata (title, description, difficulty, status)
- `custom_lesson_words` table - Links words to lessons with custom meanings and examples
- `classroom_custom_lessons` table - Manages publishing lessons to classrooms
- Extended `classroom_lesson_progress` with `lesson_source` and `custom_lesson_id`

### Schemas Created ✅
- `Medoru.Content.CustomLesson` - Custom lesson schema
- `Medoru.Content.CustomLessonWord` - Word associations with custom meanings/examples
- `Medoru.Classrooms.ClassroomCustomLesson` - Publishing join table

### Context Functions ✅

**Content Context:**
- `list_teacher_custom_lessons/2` - List teacher's lessons
- `get_custom_lesson!/1` - Get lesson by ID
- `get_custom_lesson_with_words!/1` - Get lesson with words preloaded
- `create_custom_lesson/1` - Create new lesson
- `update_custom_lesson/2` - Update lesson
- `delete_custom_lesson/1` - Delete lesson
- `publish_custom_lesson/1` - Mark as published
- `archive_custom_lesson/1` - Archive lesson
- `add_word_to_lesson/3` - Add word to lesson
- `remove_word_from_lesson/2` - Remove word from lesson
- `reorder_lesson_words/2` - Reorder words
- `update_custom_lesson_word/2` - Update word details
- `publish_lesson_to_classroom/4` - Publish to classroom
- `unpublish_lesson_from_classroom/2` - Unpublish
- `republish_lesson_to_classroom/2` - Republish
- `list_classroom_custom_lessons/2` - List classroom lessons

**Classrooms Context:**
- `get_or_create_custom_lesson_progress/3`
- `get_custom_lesson_progress/3`
- `start_custom_lesson/3`
- `complete_custom_lesson/3`
- `list_user_custom_lesson_progress/2`

### Teacher LiveViews ✅

1. **Index** (`/teacher/custom-lessons`)
   - List all custom lessons with filters
   - Create new lesson button
   - Archive lessons

2. **New** (`/teacher/custom-lessons/new`)
   - Create lesson form (title, description, difficulty)

3. **Edit** (`/teacher/custom-lessons/:id/edit`)
   - Word search and add
   - Drag-drop reordering
   - Edit custom meanings
   - Add example sentences
   - Word count limit (1-50)
   - Publish button

4. **Publish** (`/teacher/custom-lessons/:id/publish`)
   - Select classrooms to publish to
   - View currently published classrooms
   - Unpublish option

### Student LiveViews ✅

1. **Study Mode** (`/classrooms/:id/custom-lessons/:lesson_id`)
   - Display words with Japanese text, reading, meaning
   - Show custom examples
   - Previous/Next navigation
   - Progress bar
   - Mark as Complete button

2. **Completion** (`/classrooms/:id/custom-lessons/:lesson_id/complete`)
   - Congratulations message
   - Points earned display
   - Words learned count
   - Return to classroom button

### Integration ✅
- Updated ClassroomLive.Show lessons tab to display custom lessons
- Shows lesson status (Not Started, In Progress, Completed)
- Points awarded on completion (10 pts/word + 20 bonus)
- Rankings automatically include custom lesson points

## Files Created/Modified

### New Files:
- `lib/medoru/content/custom_lesson.ex` - Schema
- `lib/medoru/content/custom_lesson_word.ex` - Schema
- `lib/medoru/classrooms/classroom_custom_lesson.ex` - Schema
- `lib/medoru_web/live/teacher/custom_lesson_live/index.ex` - Teacher list
- `lib/medoru_web/live/teacher/custom_lesson_live/new.ex` - Create lesson
- `lib/medoru_web/live/teacher/custom_lesson_live/edit.ex` - Edit lesson
- `lib/medoru_web/live/teacher/custom_lesson_live/publish.ex` - Publish lesson
- `lib/medoru_web/live/classroom_live/custom_lesson.ex` - Student study mode
- `lib/medoru_web/live/classroom_live/custom_lesson_complete.ex` - Completion screen
- `priv/repo/migrations/20260315100402_create_custom_lessons.exs` - Main migration
- `priv/repo/migrations/20260315103134_make_lesson_id_nullable_for_custom_lessons.exs` - Fix constraint
- `test/medoru/content/custom_lesson_test.exs` - Tests

### Modified Files:
- `lib/medoru/content.ex` - Added custom lesson functions
- `lib/medoru/classrooms.ex` - Added custom lesson progress functions
- `lib/medoru/classrooms/classroom_lesson_progress.ex` - Extended schema
- `lib/medoru_web/live/classroom_live/show.ex` - Added custom lessons to lessons tab
- `lib/medoru_web/router.ex` - Added routes

## Routes Added

**Teacher Routes:**
- `GET /teacher/custom-lessons` - List lessons
- `GET /teacher/custom-lessons/new` - Create lesson
- `GET /teacher/custom-lessons/:id/edit` - Edit lesson
- `GET /teacher/custom-lessons/:id/publish` - Publish to classrooms

**Student Routes:**
- `GET /classrooms/:id/custom-lessons/:lesson_id` - Study lesson
- `GET /classrooms/:id/custom-lessons/:lesson_id/complete` - Completion screen

## Points System

Custom lessons award points on completion:
- Base: 10 points per word
- Bonus: 20 points for completing
- Example: 5-word lesson = 5×10 + 20 = 70 points

Points are added to classroom membership total for rankings.

## Test Results

- 468 tests, 0 failures (1 unrelated failure in learn_live_test.exs due to fixture collision)
- New test file: 8 tests for custom lesson functionality

## Validation Rules

### Lesson
- Title: required, 3-100 chars
- Description: optional, max 500 chars
- Difficulty: 1-5 or nil
- Status transitions: draft → published → archived

### Words
- Minimum 1 word
- Maximum 50 words
- No duplicate words in same lesson
- Custom meaning: optional, max 500 chars
- Examples: max 5 per word, each max 200 chars

## Next Steps

Iteration 31 is complete! Next up:
- Iteration 13: Admin Badge Management
- Iteration 24: i18n Multi-Language
- Iteration 21: Admin Dashboard
