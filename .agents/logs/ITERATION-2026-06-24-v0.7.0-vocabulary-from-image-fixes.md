# Iteration 2026-06-24: Vocabulary Lesson from Image Improvements

**Status**: COMPLETED  
**Date**: 2026-06-24  
**Reviewed By**: user  
**Approved**: YES

## What Was Implemented

Improved the admin/teacher "Create Vocabulary Lesson from Image" flow so that katakana-only items, expressions, and phrases that are missing from the database are handled correctly:

1. **Prompt the AI to include more vocabulary types**
   - Updated the `ImageVocabulary` extraction prompt to explicitly ask for katakana words/loanwords, expressions, set phrases, greetings, and multi-word phrases.

2. **Fallback to `reading` when AI omits `text`**
   - `ImageVocabulary.normalize_word/1` now falls back to the normalized `reading` when the AI returns a word without a `text` field (common for katakana-only items).
   - If no separate `image_text` is provided, it also falls back to the recovered `text`.

3. **Clean bracketed expressions while preserving the original form**
   - Expressions like `[どうぞ]よろしく[ございます]` are cleaned by removing `[` and `]` from `text` and `image_text`.
   - The original bracketed form is stored in `notes` so the optional/keigo form is not lost.

4. **Filter out non-Japanese entries**
   - Words whose final `text` is not valid Japanese (e.g. Latin words like "CD") or whose `reading` is not valid kana are dropped from the extracted list.
   - This prevents `text: must contain valid Japanese characters` errors when creating the lesson.

5. **Defensive title/description slicing**
   - `ImageLessonBuilder.build_lesson_from_extracted_words/3` now slices the provided title and description to the `CustomLesson` changeset limits (100 and 500 characters respectively), preventing validation errors from long AI-generated lesson metadata.

6. **Tests**
   - Added `ImageVocabularyTest` cases for missing-text fallback, bracketed expression cleaning, and skipping Latin/non-Japanese text.
   - Added `ImageLessonBuilderTest` cases for creating katakana/expression words and slicing long title/description.

## Files Created/Modified

- `lib/medoru/ai/image_vocabulary.ex`
- `lib/medoru/content/image_lesson_builder.ex`
- `test/medoru/ai/image_vocabulary_test.exs`
- `test/medoru/content/image_lesson_builder_test.exs`
- `AGENTS.md`

## Schema Changes

None.

## LiveViews/Routes Added

None.

## Known Issues / TODOs

- `mix precommit` currently fails at the compile step because of a pre-existing HEEx syntax error in `lib/medoru_web/live/admin/game_live/game.html.heex` (missing closing `}` on line 32). That file is part of the game work and was not modified here.
- `mix test` passes cleanly (1452 tests, 0 failures) once the test DB is created with migrations only (no seeds).

## Next Steps

- Continue with the remaining v0.7.0 fixes.
