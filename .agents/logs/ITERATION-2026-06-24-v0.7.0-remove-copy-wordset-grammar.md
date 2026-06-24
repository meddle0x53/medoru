# Iteration 2026-06-24: Remove Copy-to-Wordset Button and Word Count Badge for Grammar Lessons

**Status**: COMPLETED  
**Date**: 2026-06-24  
**Reviewed By**: user  
**Approved**: YES

## What Was Implemented

Removed word-set-related UI from grammar lessons in the classroom student view.

1. **Copy-to-wordset button removed for grammar lessons**
   - In `ClassroomLive.Show`, the copy-to-wordset button is now wrapped in `<%= if lesson.lesson_subtype != "grammar" do %>...<% end %>`.
   - Vocabulary lessons continue to show the button.

2. **Word count badge removed for grammar lessons**
   - The `{lesson.word_count} words` badge is also hidden for grammar lessons in the same list.

3. **Tests**
   - Added a new describe block in `ClassroomLive.ShowTest` that creates a published grammar lesson and asserts:
     - the copy button is absent,
     - the `0 words` word-count badge is absent.
   - Existing vocabulary copy-to-wordset tests still pass.

## Files Created/Modified

- `lib/medoru_web/live/classroom_live/show.ex`
- `test/medoru_web/live/classroom_live/show_test.exs`
- `AGENTS.md`

## Schema Changes

None.

## LiveViews/Routes Added

None.

## Known Issues / TODOs

- `mix precommit` currently fails at the compile step because of a pre-existing HEEx syntax error in `lib/medoru_web/live/admin/game_live/game.html.heex` (missing closing `}` on line 32). That file is part of the game work and was not modified here.
- `mix test` passes cleanly (1454 tests, 0 failures).

## Next Steps

- Continue with the remaining v0.7.0 fixes.
