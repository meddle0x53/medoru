# Iteration 2026-06-27: v0.8.0 Admin Remove Word Kanji

**Status**: COMPLETED  
**Date**: 2026-06-27  
**Reviewed By**: -  
**Approved**: PENDING

## What Was Implemented
- Added the ability to de-associate one or multiple kanji from a word on the admin/moderator word edit pages.
- Each kanji card in the "Kanji Associations" section now has a "Select" checkbox.
- Added a "Remove selected" button that bulk-deletes the checked `word_kanjis` rows.
- Added `Content.delete_word_kanjis/2` to delete associations scoped to a specific word.
- Wired the feature into both `/admin/words/:id/edit` and `/moderator/words/:id/edit`.
- Added LiveView tests covering single and multiple kanji removal.

## Files Modified
- `lib/medoru/content.ex` — added `delete_word_kanjis/2`
- `lib/medoru_web/live/admin/word_live/form.ex` — `selected_kanji_ids` state, `toggle_kanji_selection` and `remove_selected_kanjis` handlers
- `lib/medoru_web/live/admin/word_live/form/form_template.html.heex` — checkboxes, "Remove selected" button, `#kanji-associations` ID
- `lib/medoru_web/live/moderator/word_live/form.ex` — same handlers/state as admin
- `lib/medoru_web/live/moderator/word_live/form/form_template.html.heex` — same UI as admin
- `test/medoru_web/live/admin/word_live_test.exs` — 3 new tests
- `AGENTS.md` — updated test count and added v0.8.0 in-progress item

## Schema Changes
None.

## Routes Added
None.

## Known Issues / TODOs
None.

## Next Steps
- Await user review/approval before starting the next v0.8.0 task.
