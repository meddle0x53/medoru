# Iteration Log: v0.1.8 Kana Cascade Polish

**Date**: 2026-05-14
**Status**: In Progress
**Tests**: 761 passing

---

## Changes Summary

### Navigation Restructuring
- New `/teacher` dashboard with cards: My Classrooms, My Tests, Custom Lessons, Grammar Lessons
- New `/games` index showing all published games from user's classrooms
- Desktop nav: Dashboard, Classrooms, Kanji, Words, Games, [Teacher], [Admin]
- Mobile drawer with smart grouping (Learning / Teacher / Admin sections)
- i18n extracted for all navigation labels
- `ClassroomGameLive.Play` refactored into reusable `KanjiFallingGameLive`

### Kana Cascade Polish
- **"du" accepted for づ/ヅ**: `kana_romaji_list/1` returns `["zu", "du"]`; exact match uses `in` operator, prefix uses `Enum.any?`
- **Flick keyboard popup Android Firefox fix**: Popup appended to pressed key button with `position: absolute` (key gets `position: relative` inline). Removed `flick-popup` animation class that caused `opacity: 0`. Added explicit `opacity: 1`, `visibility: visible`, `display: block`.
- **Dakuten active state on touch devices**: Fixed modifier button orange state persistence
  - Changed modifier buttons from `click` to `pointerdown` with `e.stopPropagation()`
  - Added `phx-update="ignore"` on flick keyboard container to prevent LiveView DOM patches from resetting classes
  - High-specificity CSS `.flick-modifier-btn.flick-modifier-active` with `!important` background/color/border and `box-shadow` glow
- **Grid hiragana keyboard removed**: Flick keyboard now used on all screen sizes. CSS changed from `max-width: 1366px` gated to aspect-ratio only.

### Kanji Falling Game
- Reuses Kana Cascade game engine infrastructure
- Students type on'yomi or kun'yomi readings for falling kanji
- Teacher-configurable kanji pool by JLPT level (N5–N1)
- Reading type selection: on'yomi only, kun'yomi only, or mixed

---

## Files Modified

### JS Hooks
- `assets/js/hooks/flick_keyboard.js` — `pointerdown` for modifiers, popup positioning, `phx-update="ignore"` compatibility
- `assets/js/hooks/kana_falling_input.js` — Game engine reused for kanji falling

### CSS
- `assets/css/app.css` — Flick keyboard styles, `.flick-modifier-btn.flick-modifier-active` with `!important`

### LiveViews
- `lib/medoru_web/live/teacher/dashboard_live.ex` — New teacher dashboard
- `lib/medoru_web/live/games_live/index.ex` — Games index
- `lib/medoru_web/live/kana_falling_game_live/play.ex` — "du" support, grid keyboard removal
- `lib/medoru_web/live/kanji_falling_game_live/play.ex` — Kanji falling game (new)
- `lib/medoru_web/live/kanji_falling_game_live/play.html.heex` — Flick keyboard template with `phx-update="ignore"`
- `lib/medoru_web/components/layouts.ex` — Navigation restructuring

### Contexts
- `lib/medoru/games.ex` — `list_user_games/1`, `create_memory_card_game_words` tuple fix

---

## Deployment Notes

No migrations required for this iteration.
