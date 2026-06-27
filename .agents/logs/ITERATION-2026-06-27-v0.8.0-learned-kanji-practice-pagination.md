# Iteration 2026-06-27: v0.8.0 Learned Kanji Practice Pagination

**Status**: COMPLETED  
**Date**: 2026-06-27  
**Reviewed By**: -  
**Approved**: PENDING

## What Was Implemented
- Added server-side pagination to the learned kanji practice form (`/users/:id/kanji/practice`) at 30 kanji per page.
- Selection state (`selected_ids`) is preserved when navigating between pages, so users can select kanji from any page for drawing practice.
- Added Prev/Next and numbered page controls matching the learned kanji list page.
- Added page indicator ("Page X of Y") to the selection bar.
- Added LiveView tests covering rendering, pagination, and cross-page selection persistence.

## Files Modified
- `lib/medoru_web/live/learned_kanji_live/practice_form.ex` — pagination state, `change_page` handler, `list_learned_kanji_paginated/2` helper
- `lib/medoru_web/live/learned_kanji_live/practice_form.html.heex` — page info and pagination controls
- `test/medoru_web/live/learned_kanji_live_test.exs` — new test file with 3 tests
- `AGENTS.md` — updated test count and added v0.8.0 in-progress item

## Schema Changes
None.

## Routes Added
None.

## Known Issues / TODOs
None.

## Next Steps
- Await user review/approval before starting the next v0.8.0 task.
