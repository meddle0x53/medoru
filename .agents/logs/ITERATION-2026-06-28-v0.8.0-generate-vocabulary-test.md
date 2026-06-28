# Iteration Log: Generate Vocabulary Test for Classrooms

**Date:** 2026-06-28
**Version:** v0.8.0
**Branch:** master

## Goal
Implement a teacher-facing flow to generate and publish a vocabulary test from the words in a classroom's published vocabulary lessons.

## Implementation

### Generator
- `lib/medoru/tests/classroom_vocabulary_test_generator.ex` (new) builds a `test_type: :teacher` test from selected words and question types, then publishes it to the classroom in a transaction.
- Supports `word_to_meaning`, `word_to_reading`, `reading_text`, `image_to_meaning`, and `kanji_writing` step types using local step builders.
- Caps total questions to the available word/type pool and clamps `max_times_per_word` to 1–3.

### Context
- `lib/medoru/content.ex` — added `list_classroom_vocabulary_lessons_with_words/1` to load active vocabulary lessons and their words for a classroom.

### LiveView
- `lib/medoru_web/live/teacher/classroom_live/generate_vocabulary_test.ex` (new) at `/teacher/classrooms/:id/generate-vocabulary-test`.
- Lets teachers pick question types, select/deselect whole lessons or individual words, set max repetitions per word (1–3), set total questions, and edit the title.
- Submission reads the actual checked `word_ids` from the form so excluded words are never used even if a toggle event is lost.

### Entry Point
- `lib/medoru_web/live/teacher/classroom_live/show.ex` — added a "Generate Vocabulary Test" button on the classroom Tests tab for teachers.

### UI Polish
- Replaced the non-functional range slider with a validated number input for max repetitions.
- Added inline validation/error display for invalid max repetitions and total questions exceeding `selected_words × max_times`.

### Related Bug Fixes
- `Tests.archive_teacher_test/1` now archives associated `classroom_tests` records so archived tests no longer appear as published inside classrooms.
- Migration `20260629000406_fix_classroom_test_attempts_test_id_on_delete.exs` changes `classroom_test_attempts.test_id` from `on_delete: :nilify_all` to `on_delete: :delete_all` (the column is `NOT NULL`, so nilify caused deletions to crash).

## Files Changed

- `lib/medoru/content.ex`
- `lib/medoru/tests/classroom_vocabulary_test_generator.ex` (new)
- `lib/medoru/tests.ex`
- `lib/medoru_web/live/teacher/classroom_live/generate_vocabulary_test.ex` (new)
- `lib/medoru_web/live/teacher/classroom_live/show.ex`
- `priv/repo/migrations/20260629000406_fix_classroom_test_attempts_test_id_on_delete.exs` (new)
- `test/medoru/tests/classroom_vocabulary_test_generator_test.exs` (new)
- `test/medoru/tests_test.exs`
- `test/medoru_web/live/teacher/classroom_live_test.exs`

## Tests Added

- `Medoru.Tests.ClassroomVocabularyTestGeneratorTest` — generation, capping, validation, and clamping.
- `MedoruWeb.Teacher.ClassroomLiveTest` — permissions, empty state, word selection, max-times validation, total-questions validation, and excluded-word handling.
- `Medoru.TestsTest` — `archive_teacher_test/1` archives classroom publications and `delete_test/1` succeeds when attempts exist.

## Verification

- `mix format --check-formatted` — clean.
- `mix ecto.migrate` — `fix_classroom_test_attempts_test_id_on_delete` applied.
- Targeted tests — 83 tests, 0 failures.
- Full suite (`--exclude slow --exclude openai`) — 1534 tests, 0 failures.

## Notes

- The generator is intentionally independent of `WordSetTestGenerator` so classroom test generation can diverge later.
- Unrelated existing failures in `ImageVocabularyTest` and `ImageGrammarTest` (OpenAI API key setup) remain out of scope.
