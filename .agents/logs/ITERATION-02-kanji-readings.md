# Iteration 2: Kanji & Readings

**Status**: COMPLETED  
**Date**: 2026-03-05  
**Reviewed By**: meddle  
**Approved**: ✅ YES

---

## Summary

Iteration 2 is complete. The Kanji & Readings system provides a foundation for the Japanese learning content, with N5 kanji seeded and a functional browse UI.

## What Was Implemented

### 1. Schemas Created
- **`Medoru.Content.Kanji`** - Character, meanings (array), stroke_count, jlpt_level (1-5), stroke_data (JSONB), radicals (array), frequency
- **`Medoru.Content.KanjiReading`** - reading_type (:on/:kun enum), reading (kana), romaji, usage_notes

### 2. Migrations
- `20260305201400_create_kanji.exs` - Kanji table with indexes on character (unique), jlpt_level, frequency
- `20260305201404_create_kanji_readings.exs` - Readings table with foreign key to kanji

### 3. Content Context (`lib/medoru/content.ex`)
Key functions:
- `list_kanji/0` - List all kanji
- `list_kanji_by_level/1` - Filter by JLPT level (1-5), ordered by frequency
- `get_kanji!/1` - Get kanji by ID
- `get_kanji_by_character/1` - Lookup by character
- `get_kanji_with_readings!/1` - Get kanji with preloaded readings
- `create_kanji/1` - Create kanji
- `create_kanji_with_readings/2` - Transaction to create kanji + readings atomically
- Full CRUD for kanji readings

### 4. Seed Data
- `priv/repo/seeds/kanji_n5.json` - 30 most common N5 kanji with readings
- `priv/repo/seeds.exs` - Script to load kanji data from JSON

### 5. LiveViews
- **`MedoruWeb.KanjiLive.Index`** - Browse kanji by JLPT level
  - Grid display of kanji characters
  - Level selector (N1-N5)
  - Shows character + first meaning
  - Links to detail page
  
- **`MedoruWeb.KanjiLive.Show`** - Kanji detail view
  - Large kanji display
  - JLPT level, stroke count, frequency badges
  - Meanings list
  - Radicals display
  - On'yomi readings (katakana)
  - Kun'yomi readings (hiragana)
  - Back navigation
  - "Add to Study List" button (for authenticated users)

### 6. Routes & Navigation
- `/kanji` - Kanji browser (public)
- `/kanji/:id` - Kanji detail (public)
- Added "Kanji" link to navigation for authenticated users
- Added "Browse Kanji" card to dashboard

### 7. Validation
- Kanji character must be in CJK range (U+4E00-U+9FFF or U+3400-U+4DBF)
- On readings must use katakana (U+30A0-U+30FF)
- Kun readings must use hiragana (U+3040-U+309F)
- JLPT level must be 1-5
- Character must be unique

### 8. Tests
- **`test/medoru/content_test.exs`** - 38 tests for Content context
  - CRUD operations for kanji and readings
  - Validation tests (character range, kana type, uniqueness)
  - Transaction rollback tests
  
- **`test/medoru_web/live/kanji_live_test.exs`** - 16 LiveView tests
  - Index page tests (list, filter, navigation)
  - Show page tests (details, readings display)
  - Authenticated navigation tests

- **Test Fixtures** - `test/support/fixtures/content_fixtures.ex`

### 9. Test Helper
- Added `log_in_user/2` helper to `test/support/conn_case.ex`

## Test Results

```
Running ExUnit with seed: 494663, max_cases: 48
............................................................................
Finished in 0.9 seconds (0.3s async, 0.5s sync)
76 tests, 0 failures
```

## Code Quality

- `mix precommit` passes
- Zero compiler warnings
- All 76 tests passing (31 from Iteration 1 + 45 new)

## Key Design Decisions

1. **Separate readings table** - Each kanji can have multiple on'yomi and kun'yomi readings
2. **Kana validation** - Enforces correct kana type for reading type (on=katakana, kun=hiragana)
3. **CJK validation** - Only accepts valid kanji characters, not hiragana/katakana/latin
4. **Transaction safety** - `create_kanji_with_readings/2` ensures atomic creation
5. **Public access** - Kanji browser is public; authentication only required for study list features
6. **Frequency ordering** - Kanji listed by usage frequency within each JLPT level

## Files Created/Modified

### New Files (16):
- `lib/medoru/content.ex`
- `lib/medoru/content/kanji.ex`
- `lib/medoru/content/kanji_reading.ex`
- `lib/medoru_web/live/kanji_live/index.ex`
- `lib/medoru_web/live/kanji_live/show.ex`
- `priv/repo/migrations/20260305201400_create_kanji.exs`
- `priv/repo/migrations/20260305201404_create_kanji_readings.exs`
- `priv/repo/seeds/kanji_n5.json`
- `test/medoru/content_test.exs`
- `test/medoru_web/live/kanji_live_test.exs`
- `test/support/fixtures/content_fixtures.ex`

### Modified Files (4):
- `priv/repo/seeds.exs` - Updated to load kanji data
- `lib/medoru_web/router.ex` - Added kanji routes with public live_session
- `lib/medoru_web/components/layouts.ex` - Added Kanji link to nav
- `lib/medoru_web/live/dashboard_live.ex` - Added Browse Kanji card
- `test/support/conn_case.ex` - Added log_in_user helper

## Database Status

- ✅ `kanji` table created with indexes
- ✅ `kanji_readings` table created with foreign keys
- ✅ 30 N5 kanji seeded (~85 readings total)

## Next Steps (Iteration 3)

**Words with Reading Links**
- Word schema (text, meaning, difficulty)
- WordKanji join table (links words to specific kanji AND specific readings)
- Content context functions for words
- Seed data for common words
- Word browse UI

---

**Ready for review. Please review the changes and approve to proceed to Iteration 3.**
