# Iteration 2026-06-24: Grammar Index Learned Indicator

**Status**: COMPLETED  
**Date**: 2026-06-24  
**Reviewed By**: user  
**Approved**: PENDING

## What Was Implemented

Added a visual "learned" indicator to grammar cards on the public `/grammars` index page, matching the existing words/kanji index UX.

1. **Backend**
   - Added `Learning.list_learned_grammar_definition_ids_for_user/1` to efficiently fetch learned grammar IDs for a user.
   - `GrammarDefinitionLive.Index` now loads the current user's learned grammar IDs in `mount` and assigns them to the socket.

2. **Frontend**
   - Each grammar card computes `is_learned = grammar.id in @learned_grammar_ids`.
   - Learned cards get:
     - a green-tinted background and green border,
     - a green title color,
     - a `Learned` badge with a checkmark next to the JLPT level badge.

3. **Tests**
   - Added two tests in `GrammarDefinitionLiveTest`:
     - learned grammar definitions display the "Learned" badge,
     - unlearned grammar definitions do not display the badge.

## Files Created/Modified

- `lib/medoru/learning.ex`
- `lib/medoru_web/live/grammar_definition_live/index.ex`
- `lib/medoru_web/live/grammar_definition_live/index.html.heex`
- `test/medoru_web/live/grammar_definition_live_test.exs`
- `AGENTS.md`

## Schema Changes

None.

## LiveViews/Routes Added

None.

## Known Issues / TODOs

- `mix precommit` currently fails at the compile step because of a pre-existing HEEx syntax error in `lib/medoru_web/live/admin/game_live/game.html.heex` (missing closing `}` on line 32). That file is part of the game work and was not modified here.
- `mix test` passes cleanly (1456 tests, 0 failures).

## Next Steps

- Continue with the remaining v0.7.0 fixes.
