
## 2026-03-26 - Grammar Validator Performance Optimization

### Summary
Implemented ETS-based caching for the Grammar Validator to eliminate O(n²) database queries during sentence validation. Reduced validation time from 2500ms+ to ~50ms per sentence.

### Problem
The grammar validator was checking every possible substring of the input sentence against the database, causing 100+ queries per validation:
- A 10-character sentence generated ~55 substring checks
- Each check queried `word_conjugations` table
- Total time: 2500ms+ per sentence validation

### Solution

#### 1. ETS Cache Module
**File**: `lib/medoru/grammar/validator_cache.ex`
- Public ETS table with `:read_concurrency` and `:write_concurrency`
- GenServer for cache lifecycle management
- Key structure: `{:conjugation, text, word_type, allowed_forms, field_type}`
- Lazy loading: populates cache on first access

#### 2. Validator Integration
**File**: `lib/medoru/grammar/validator.ex`
- `lookup_dictionary_form/3` - cache-first with DB fallback
- `lookup_conjugated_form/4` - cache-first with DB fallback
- `do_lookup_conjugated_form_db/3` - DB query for cache misses

#### 3. Application Integration
**File**: `lib/medoru/application.ex`
- Added `Medoru.Grammar.ValidatorCache` to supervision tree
- Starts before Endpoint to ensure cache is ready

### Cache Strategy
1. **First access**: Cache miss → Query DB → Store in ETS
2. **Subsequent accesses**: O(1) ETS lookup
3. **Cache warming**: Lazy (on-demand) per word type
4. **Fallback**: Always query DB on cache miss (ensures correctness)

### Performance Impact
| Metric | Before | After |
|--------|--------|-------|
| DB queries/sentence | 100+ | 0-5 |
| Validation time | 2500ms+ | ~50ms |
| Improvement | - | **50x faster** |

### Test Results
- All 585 tests passing ✓
- Validator tests: 15/15 passing ✓

### Files Modified
- `lib/medoru/grammar/validator_cache.ex` (new)
- `lib/medoru/grammar/validator.ex` (cached lookups)
- `lib/medoru/application.ex` (supervision tree)

---

## 2026-03-08 - Lessons Pagination, Kanji Progression & Reading Extraction

### Summary
Major improvements to lesson generation algorithm, word-kanji reading associations, and view-layer reading extraction.

### Changes Made

#### 1. Lessons Pagination & Sorting Fix
**File**: `lib/medoru/content.ex`
- Fixed sorting order to prioritize `order_index` over title length
- Lessons now display in proper progression order (Focus ① → ② → ③)

#### 2. Progressive Kanji Learning Algorithm (v3)
**File**: `lib/mix/tasks/medoru.generate_lessons_v3.ex`
- Implemented research-based kanji progression:
  - Tier ①: Numbers (一-十, 百, 千)
  - Tier ②: Time/Date (日, 月, 年, 時, 分)
  - Tier ③: Directions (上, 下, 中, 前, 後)
  - Tier ④+: Descriptors, People, Nature, Verbs
- Created 824 N5 lessons with 3,132 words
- Lesson titles show tier badges: "一 Focus ①", "日 Focus ②"

#### 3. Word-Kanji Reading Fix Task
**File**: `lib/mix/tasks/medoru.fix_word_readings.ex`
- Created batch processing task to fix missing reading associations
- Fixed 1,218 out of 4,861 N5 word-kanji associations (25.1% coverage)
- Covers single-kanji words and first-position kanji in compounds

#### 4. KanjiReadingExtractor Module
**File**: `lib/medoru/content/kanji_reading_extractor.ex`
- Smart extraction of kanji readings by comparing word text vs reading
- Algorithm:
  1. Find common kana prefix/suffix
  2. Isolate kanji portion
  3. Extract corresponding reading
- Examples:
  - ついこの間 + ついこのあいだ → 間 = あいだ
  - のし上がる + のしあがる → 上 = あ
  - 行けない + いけない → 行 = い

#### 5. Python Pipeline Fix
**Files**: 
- `data/src/medoru_data/spiders/jmdict.py`
- `data/src/medoru_data/cli.py`
- `data/src/medoru_data/exporters/word_exporter.py`
- Added `--kanji-data` option to export commands
- `_match_kanji_readings()` function matches readings during export
- Future word exports will include kanji reading links

#### 6. View Updates for Reading Display
**Files**:
- `lib/medoru_web/live/word_live/show.html.heex`
- `lib/medoru_web/live/learn_live.ex`
- Shows extracted readings when database link missing
- Displays "(inferred)" label for dynamically extracted readings

#### 7. Optimized Lesson Generator (v4)
**File**: `lib/mix/tasks/medoru.generate_lessons_v4.ex`
- Two-phase lesson structure:
  - **Phase 1**: Short Focus Lessons (single kanji, 2-3 char words only)
  - **Phase 2**: Themed Mixed Lessons (interleaved word types)
- Smart rotation: 2-3 Noun lessons → 1 Verb → 1 Adjective
- Selective focus: Max 2 lessons per kanji in Phase 1
- Creates ~734 N5 lessons (more selective than v3)

### Content Statistics

| Level | Lessons | Words | Coverage |
|-------|---------|-------|----------|
| N5    | 833     | 3,132 | 25% reading links |
| N4    | 1,750   | 6,796 | (estimated) |
| N3    | 34,764  | 135,831 | (estimated) |

### Test Results
- All 277 tests passing ✓

### Next Steps
- Consider running v4 generator to replace v3 lessons
- Further improve multi-kanji reading extraction
- Add themed lesson categories (Family, Food, Actions, etc.)

