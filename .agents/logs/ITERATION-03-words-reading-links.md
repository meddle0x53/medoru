# Iteration 3: Words with Reading Links

**Status**: COMPLETED  
**Date**: 2026-03-06  
**Reviewed By**: meddle  
**Approved**: ✅ YES

---

## Summary

Iteration 3 is complete. The Words with Reading Links system provides a way to store Japanese vocabulary with proper kanji-to-reading associations, enabling accurate word breakdowns and reading validation.

## What Was Implemented

### 1. Schemas Created

- **`Medoru.Content.Word`** - Text, meaning, reading (hiragana), difficulty (1-5), usage_frequency
- **`Medoru.Content.WordKanji`** - Join table linking words to specific kanji AND specific readings
  - `position` - Position of kanji in word (0-indexed)
  - `word_id` - Reference to word
  - `kanji_id` - Reference to kanji
  - `kanji_reading_id` - Reference to specific reading used (nullable for okurigana)

### 2. Migrations

- `20260306070645_create_words.exs` - Words table with indexes on difficulty, usage_frequency, and unique text
- `20260306070652_create_word_kanjis.exs` - Word-kanji join table with composite unique index

### 3. Content Context Updates (`lib/medoru/content.ex`)

Key functions:
- `list_words/0` - List all words ordered by frequency
- `list_words_by_difficulty/1` - Filter by JLPT difficulty level (1-5)
- `list_words_by_kanji/1` - Find words containing a specific kanji
- `get_word!/1` - Get word by ID
- `get_word_with_kanji!/1` - Get word with kanji and readings preloaded
- `get_word_by_text/1` - Lookup word by text
- `create_word/1` - Create word
- `create_word_with_kanji/2` - Transaction to create word with kanji links atomically
- Full CRUD for word_kanjis

### 4. Seed Data

- `priv/repo/seeds/words_n5.json` - 31 common N5 vocabulary words using the seeded kanji
- `priv/repo/seeds.exs` - Updated to load word data with proper kanji/reading linking

### 5. LiveViews

- **`MedoruWeb.WordLive.Index`** - Browse vocabulary by JLPT difficulty
  - Grid display of words with text, reading, and meaning
  - Difficulty selector (N1-N5)
  - Word count display
  - Links to detail page

- **`MedoruWeb.WordLive.Show`** - Word detail view
  - Large word display with reading
  - JLPT level and common word badges
  - Meaning section
  - Kanji breakdown with specific readings highlighted
  - Links to individual kanji pages
  - "Add to Study List" button (for authenticated users)

### 6. Routes & Navigation

- `/words` - Vocabulary browser (public)
- `/words/:id` - Word detail (public)
- Added "Words" link to navigation for authenticated users
- Added "Browse Vocabulary" card to dashboard

### 7. Validation

- Word text must contain valid Japanese characters (kanji, hiragana, katakana)
- Reading must contain only kana (hiragana/katakana)
- Difficulty must be 1-5
- Text must be unique
- Position in word_kanjis must be non-negative

### 8. Tests

- **`test/medoru/content_test.exs`** - 42 new tests for Word and WordKanji
  - CRUD operations
  - Validation tests (Japanese text, kana reading, uniqueness)
  - Transaction rollback tests
  - Association tests (kanji links, preloading)

- **`test/medoru_web/live/word_live_test.exs`** - 10 LiveView tests
  - Index page tests (list, filter, navigation)
  - Show page tests (details, kanji breakdown)
  - Authenticated navigation tests

## Test Results

```
Running ExUnit with seed: 208296, max_cases: 48
.....................................................................................................................
Finished in 1.5 seconds (0.7s async, 0.7s sync)
118 tests, 0 failures
```

## Code Quality

- `mix precommit` passes
- Zero compiler warnings
- All 118 tests passing (76 from previous + 42 new)

## Key Design Decisions

1. **Reading Links** - Each WordKanji references a specific KanjiReading, ensuring the correct reading is shown for words with multiple possible readings (e.g., 日 in 日本 uses ニチ, not ジツ or ひ)

2. **Nullable reading_id** - Okurigana (suffix kana like 〜い in 大きい) don't have associated kanji_readings, so the field is nullable

3. **Position tracking** - WordKanjis track position to preserve word character order

4. **Japanese text validation** - Ensures word text contains only valid CJK characters and Japanese kana

5. **Kana-only reading** - Reading field must be pure hiragana/katakana for accurate pronunciation

6. **Transaction safety** - `create_word_with_kanji/2` ensures atomic creation of word and kanji links

## Files Created/Modified

### New Files (10):
- `lib/medoru/content/word.ex`
- `lib/medoru/content/word_kanji.ex`
- `lib/medoru_web/live/word_live/index.ex`
- `lib/medoru_web/live/word_live/show.ex`
- `priv/repo/migrations/20260306070645_create_words.exs`
- `priv/repo/migrations/20260306070652_create_word_kanjis.exs`
- `priv/repo/seeds/words_n5.json`
- `test/medoru_web/live/word_live_test.exs`
- `.agents/logs/ITERATION-03-words-reading-links.md`

### Modified Files (5):
- `lib/medoru/content.ex` - Added Word and WordKanji functions
- `priv/repo/seeds.exs` - Added word seeding logic
- `lib/medoru_web/router.ex` - Added word routes
- `lib/medoru_web/components/layouts.ex` - Added Words nav link
- `lib/medoru_web/live/dashboard_live.ex` - Added Browse Vocabulary card
- `test/support/fixtures/content_fixtures.ex` - Added word fixtures
- `test/medoru/content_test.exs` - Added word tests

## Database Status

- ✅ `words` table created with indexes
- ✅ `word_kanjis` table created with foreign keys and composite unique index
- ✅ 31 N5 words seeded with proper kanji/reading links

## Next Steps (Iteration 4)

**Lessons System**
- Lesson schema (title, description, difficulty, ordered kanji list)
- LessonKanji join table
- Lessons context functions
- Lessons LiveViews (index, show)
- Seed data for sample lessons

---

**Ready for review. Please review the changes and approve to proceed to Iteration 4.**
