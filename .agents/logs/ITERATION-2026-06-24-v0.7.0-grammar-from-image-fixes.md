# Iteration 2026-06-24: Grammar Lesson from Image Fixes

**Status**: COMPLETED  
**Date**: 2026-06-24  
**Reviewed By**: user  
**Approved**: YES

## What Was Implemented

Fixed two bugs in the admin "Create Grammar Lesson from Image" flow:

1. **Examples were lost for text steps**
   - `GrammarParser` no longer discards the `examples` array when a section is classified as a text step.
   - `GrammarImageBuilder` now builds a `full_description` that appends formatted examples to the section description for both grammar and text steps.
   - For grammar steps, the structured `examples` list is still stored so the existing examples UI keeps working, and the examples are also included in the explanation text.
   - For text steps, the examples are embedded into `explanation_sections` so they render in the step content.

2. **`string_data_right_truncation` error on lesson creation**
   - Added migration `20260624180614_ensure_grammar_explanation_text.exs` to guarantee `grammar_lesson_steps.explanation` is stored as `:text`.
   - `GrammarImageBuilder` now slices the custom lesson title to 100 chars and description to 500 chars, matching the `CustomLesson` changeset validation limits.
   - Step titles continue to be sliced to 100 chars.

3. **Fresh test database migration failure (bonus fix)**
   - Fixed `20260524175855_create_classroom_chats_for_existing.exs` so it only references columns that exist at that point in time (`classrooms.id/name/teacher_id/inserted_at`, `conversations` existing columns) and uses `insert_all` with the schema module for proper UUID encoding. This prevents the migration from breaking whenever a later migration adds columns such as `classrooms.theme`.

## Files Created/Modified

- `lib/medoru/ai/grammar_parser.ex`
- `lib/medoru/content/grammar_image_builder.ex`
- `priv/repo/migrations/20260624180614_ensure_grammar_explanation_text.exs`
- `priv/repo/migrations/20260524175855_create_classroom_chats_for_existing.exs`
- `test/medoru/ai/grammar_parser_test.exs`
- `test/medoru/content/grammar_image_builder_test.exs`
- `AGENTS.md`

## Schema Changes

- New migration: `EnsureGrammarExplanationText` — alters `grammar_lesson_steps.explanation` to `:text`.
- Fixed historical migration: `CreateClassroomChatsForExisting` — no schema change, only migration-time resilience.

## LiveViews/Routes Added

None.

## Known Issues / TODOs

- `mix precommit` currently fails at the compile step because of a pre-existing HEEx syntax error in `lib/medoru_web/live/admin/game_live/game.html.heex` (missing closing `}` on line 32). That file is part of the game work and was not modified here.
- `mix test` passes cleanly (1447 tests, 0 failures) once the test DB is created with migrations only (no seeds).

## Next Steps

- Continue with the remaining v0.7.0 fixes.
