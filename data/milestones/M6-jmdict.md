# Milestone 6: JMdict Integration (Words)

**Status:** ✅ COMPLETE  
**Date:** 2026-03-08  
**Priority:** High

---

## Overview

Integrate JMdict for comprehensive Japanese-English dictionary data including vocabulary words with automatic classification.

## Goals

1. ✅ Download JMdict
2. ✅ Parse word entries
3. ✅ Cross-reference with kanji
4. ✅ Export vocabulary lists
5. ✅ Word type classification
6. ✅ JLPT level calculation

## Implementation

### Files Created

- `src/medoru_data/spiders/jmdict.py` - JMdict spider with classification
- `src/medoru_data/exporters/word_exporter.py` - Word export utilities
- `lib/mix/tasks/medoru.seed_words.ex` - Elixir import/update task

### CLI Commands Added

```bash
# Download JMdict
medoru-data jmdict download

# Export all words
medoru-data jmdict export --output seeds/words_all.json

# Export words for specific kanji
medoru-data jmdict export-for-kanji --kanji "日,月,火" --output seeds/words_sample.json

# Export for database seeding (by kanji list)
medoru-data jmdict export-for-seeding \
  --kanji "日,月,火,水,木" \
  --max-per-kanji 10 \
  --output ../priv/repo/seeds/words_custom.json

# Export ALL words for seeding
medoru-data jmdict export-all-for-seeding \
  --output ../priv/repo/seeds/words_all.json

# Export with limit for testing
medoru-data jmdict export-all-for-seeding \
  --limit 1000 \
  --output ../priv/repo/seeds/words_1k.json

# Check status
medoru-data jmdict status

# Show statistics
medoru-data jmdict stats
```

### Elixir Mix Task

```bash
# Import words (creates new or updates existing)
mix medoru.seed_words --file priv/repo/seeds/words_custom.json

# Dry run (preview without changes)
mix medoru.seed_words --file words.json --dry-run
```

## Features

### Word Type Classification

Automatically classifies words by part-of-speech:

| Type | Description |
|------|-------------|
| `noun` | Common nouns, proper nouns, prefixes, suffixes |
| `verb` | Godan, Ichidan, irregular, suru verbs |
| `adjective` | i-adjectives, na-adjectives |
| `adverb` | fukushi adverbs |
| `expression` | Phrases, interjections |
| `particle` | Particles, conjunctions, copula |
| `pronoun` | Pronouns |
| `counter` | Counters, numerics |
| `other` | Unclassified, auxiliary |

### JLPT Level Calculation

Calculates word difficulty based on kanji composition:

| Level | Rule | Example |
|-------|------|---------|
| 5 (N5) | All kanji are N5 | 日本 (日=N5, 本=N5) |
| 4 (N4) | All kanji are N5 or N4 | 会社 (会=N4, 社=N4) |
| 3 (N3+) | Contains N3+ or unknown kanji | 加工 (加=N4, 工=N3+) |

### Data Quality

- **Long meaning truncation**: Meanings >250 chars are truncated with "..."
- **Duplicate handling**: Existing words are updated with new classification
- **Kanji validation**: Only words with known CJK kanji are exported

## Data Fields

Each word entry includes:

```json
{
  "text": "日本語",
  "meaning": "Japanese language",
  "reading": "にほんご",
  "difficulty": 5,
  "usage_frequency": 1000,
  "word_type": "noun",
  "kanji": [
    {"character": "日", "position": 0, "reading": ""},
    {"character": "本", "position": 1, "reading": ""},
    {"character": "語", "position": 2, "reading": ""}
  ]
}
```

## Data Source

- **Source:** https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project
- **License:** CC BY-SA 4.0
- **Copyright:** © EDRG

## Statistics

JMdict contains approximately:
- **215,594 total entries**
- **~175,000 words with kanji**
- **~40,000 kana-only words**

## Definition of Done

- [x] Download JMdict XML
- [x] Parse word entries (kanji forms, readings, senses, POS)
- [x] Cross-reference with kanji
- [x] Export to Medoru format
- [x] Word type classification
- [x] JLPT level calculation
- [x] Attribution in metadata
- [x] CLI commands implemented
- [x] Elixir mix task for import/update
- [x] Documentation (WORD_SEEDING.md)

## Next Steps

Use this data to:
1. Generate word lists for N5-N1 based on kanji coverage
2. Cross-reference with existing kanji data
3. Build vocabulary lessons with proper classification
