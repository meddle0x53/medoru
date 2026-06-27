# Iteration 2026-06-27: v0.8.0 Draft Lesson Preview Crash Fix

**Status**: COMPLETED  
**Date**: 2026-06-27  
**Reviewed By**: -  
**Approved**: PENDING

## What Was Implemented
- Fixed a `KeyError` crash when previewing draft custom lessons that are not published to a classroom (`/teacher/custom-lessons/:id/preview`).
- The preview fallback classroom map now includes `theme: nil` so `data-theme={@classroom.theme}` does not crash.
- Added preview-safe behavior throughout `ClassroomLive.CustomLesson`:
  - Back link goes to the lesson editor instead of a non-existent classroom.
  - Vocabulary word links are rendered as plain text in preview mode.
  - Last-step navigation shows "Back to Editor" instead of complete/test/back-to-classroom buttons.
  - The `complete` event is a no-op in preview mode as a safety guard.
  - Grammar lessons with zero steps are handled gracefully (`current_step` can be `nil`).
- Added LiveView tests covering preview of a draft vocabulary lesson without a classroom and a draft grammar lesson with no steps.

## Files Modified
- `lib/medoru_web/live/classroom_live/custom_lesson.ex` — preview-safe classroom fallback, conditional back link, preview word text, preview navigation, `complete` no-op, nil-safe grammar step loading
- `test/medoru_web/live/classroom_live/custom_lesson_test.exs` — new tests for draft lesson preview and empty grammar lesson preview
- `AGENTS.md` — added v0.8.0 in-progress item

## Schema Changes
None.

## Routes Added
None.

## Known Issues / TODOs
None.

## Next Steps
- Await user review/approval before starting the next v0.8.0 task.
