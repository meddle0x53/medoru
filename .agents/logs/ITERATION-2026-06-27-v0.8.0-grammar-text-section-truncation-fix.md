# Iteration 2026-06-27: v0.8.0 Grammar Text Section Truncation Fix

**Status**: COMPLETED  
**Date**: 2026-06-27  
**Reviewed By**: -  
**Approved**: PENDING

## What Was Implemented
- Added migration to change `grammar_lesson_steps.explanation_sections` from `varchar(255)[]` to `text[]`.
- This prevents production crashes (`Postgrex.Error ERROR 22001 string_data_right_truncation`) when creating grammar lessons from images that produce long text-step sections.

## Files Modified
- `priv/repo/migrations/20260627224948_change_grammar_lesson_step_explanation_sections_to_text.exs` — new migration
- `AGENTS.md` — added v0.8.0 in-progress item

## Schema Changes
- `grammar_lesson_steps.explanation_sections` is now `{:array, :text}`.

## Routes Added
None.

## Known Issues / TODOs
None.

## Next Steps
- Await user review/approval before starting the next v0.8.0 task.
