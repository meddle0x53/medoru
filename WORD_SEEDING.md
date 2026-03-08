# Word Seeding Guide

This guide explains how to seed the Medoru database with Japanese vocabulary words from JMdict.

## Overview

There are two ways to seed words into the database:

1. **Two-step process**: Export from Python pipeline → Import via Mix task
2. **Direct seeding**: Use existing seed files

---

## Method 1: Two-Step Process (Recommended for Custom Lists)

### Step 1: Export Words from JMdict

From the `data/` directory:

```bash
cd data

# Download JMdict (one-time)
medoru-data jmdict download
```

#### Option A: Export Words for Specific Kanji

```bash
# Export words for specific kanji (seeding format)
medoru-data jmdict export-for-seeding \
  --kanji "日,月,火,水,木,金,土" \
  --max-per-kanji 10 \
  --output ../priv/repo/seeds/words_custom.json
```

The `--kanji` option accepts a comma-separated list of kanji characters. The tool will find words containing any of these kanji.

#### Option B: Export ALL Words

```bash
# Export ALL words (~170,000 words, ~500MB file)
medoru-data jmdict export-all-for-seeding \
  --output ../priv/repo/seeds/words_all.json

# Export with limit for testing
medoru-data jmdict export-all-for-seeding \
  --limit 5000 \
  --output ../priv/repo/seeds/words_5k.json
```

### Step 2: Import Words into Database

```bash
# From project root
mix medoru.seed_words --file priv/repo/seeds/words_custom.json

# Dry run (preview without importing)
mix medoru.seed_words --file priv/repo/seeds/words_custom.json --dry-run
```

---

## Method 2: Direct Seeding with Existing Files

The default seed file is already configured in `priv/repo/seeds.exs`:

```bash
# Seed all data (kanji + words + lessons + badges)
mix run priv/repo/seeds.exs
```

---

## Generating Words by JLPT Level

To generate vocabulary for specific JLPT levels, you need to specify the kanji for that level:

### N5 Vocabulary

```bash
cd data

# N5 kanji list (80 characters)
N5_KANJI="日,一,国,人,年,大,十,二,本,中,長,出,三,時,行,見,月,分,後,前,内,生,五,間,上,東,四,今,金,九,入,学,高,円,子,外,八,六,下,来,気,小,七,山,女,百,先,名,川,千,水,男,西,木,聞,口"

medoru-data jmdict export-for-seeding \
  --kanji "$N5_KANJI" \
  --max-per-kanji 5 \
  --output ../priv/repo/seeds/words_n5_jmdict.json

cd ..
mix medoru.seed_words --file priv/repo/seeds/words_n5_jmdict.json
```

### N4 Vocabulary

```bash
cd data

# N4 kanji list (166 characters) - add to N5
N4_KANJI="会,同,事,社,自,発,者,地,業,方,新,場,員,立,開,手,力,問,代,明,動,京,目,通,言,理,体,田,主,題,意,不,作,用,度,強,公,持,野,以,思,家,世,多,正,安,院,心,界,教,文,重,近,考,画,海,去,走,集,知,別,物,使,待,系,親,乗,飲,品,商"

medoru-data jmdict export-for-seeding \
  --kanji "$N4_KANJI" \
  --max-per-kanji 5 \
  --output ../priv/repo/seeds/words_n4_jmdict.json

cd ..
mix medoru.seed_words --file priv/repo/seeds/words_n4_jmdict.json
```

---

## CLI Reference

### Python Pipeline Commands

```bash
# Download JMdict data
medoru-data jmdict download

# Show JMdict statistics
medoru-data jmdict stats

# Export all words (raw format)
medoru-data jmdict export --output seeds/words_all.json

# Export words for specific kanji (raw format)
medoru-data jmdict export-for-kanji \
  --kanji "日,月,火" \
  --max-per-kanji 10 \
  --output seeds/words_by_kanji.json

# Export words for seeding (database format) - specific kanji
medoru-data jmdict export-for-seeding \
  --kanji "日,月,火" \
  --max-per-kanji 10 \
  --output ../priv/repo/seeds/words.json

# Export ALL words for seeding (database format)
# WARNING: This creates a large file (~500MB, ~170k words)
medoru-data jmdict export-all-for-seeding \
  --output ../priv/repo/seeds/words_all.json

# Export limited set for testing
medoru-data jmdict export-all-for-seeding \
  --limit 1000 \
  --output ../priv/repo/seeds/words_1k.json
```

### Elixir Mix Tasks

```bash
# Seed words from file (default: priv/repo/seeds/words_n5.json)
mix medoru.seed_words

# Seed from specific file
mix medoru.seed_words --file priv/repo/seeds/words_custom.json

# Dry run (preview only)
mix medoru.seed_words --file words.json --dry-run
```

---

## Data Format

### Input Format (JSON)

The seeding task accepts JSON files in this format:

```json
[
  {
    "text": "日本",
    "meaning": "Japan",
    "reading": "にほん",
    "difficulty": 5,
    "usage_frequency": 1000,
    "word_type": "noun",
    "kanji": [
      {"character": "日", "position": 0, "reading": ""},
      {"character": "本", "position": 1, "reading": ""}
    ]
  }
]
```

**Fields:**
- `text`: The word in Japanese (kanji)
- `meaning`: English meaning (max 250 chars, truncated if longer)
- `reading`: Hiragana reading
- `difficulty`: JLPT level (5=N5, 4=N4, 3=N3, 2=N2, 1=N1)
- `word_type`: Part of speech (noun, verb, adjective, adverb, expression, particle, pronoun, counter, other)
- `kanji`: Array of kanji characters with their positions

### Word Classification

Words are automatically classified during export:

#### Word Type (POS)
Derived from JMdict part-of-speech tags:

| Type | JMdict Tags |
|------|-------------|
| `noun` | noun (common), proper noun, prefix, suffix |
| `verb` | Godan verb, Ichidan verb, suru verb, transitive/intransitive |
| `adjective` | i-adjective, na-adjective, pre-noun adjectival |
| `adverb` | adverb (fukushi), adverb taking 'to' |
| `expression` | expressions, interjections |
| `particle` | particle, conjunction, copula |
| `pronoun` | pronoun |
| `counter` | numeric, counter |
| `other` | unclassified, auxiliary |

#### JLPT Level (Difficulty)
Calculated based on kanji composition:

| Level | Rule | Example |
|-------|------|---------|
| 5 (N5) | All kanji are N5 | 日本 (日=N5, 本=N5) |
| 4 (N4) | All kanji are N5 or N4 | 会社 (会=N4, 社=N4) |
| 3 (N3+) | Contains N3+ or unknown kanji | 加工 (加=N4, 工=N3+) |

### Database Schema

Words are stored with:
- `text`: The word in Japanese (kanji)
- `meaning`: English meaning (truncated to 250 chars if longer)
- `reading`: Hiragana reading
- `difficulty`: 1-5 scale (N1=1, N5=5)
- `usage_frequency`: Frequency rank (default 1000)
- `word_type`: noun, verb, adjective, etc.

Word-kanji links connect words to their constituent kanji.

---

## Troubleshooting

### "Kanji not found" warnings

The import will skip words that contain kanji not in the database. Make sure to seed kanji first:

```bash
mix medoru.seed_kanji --all
```

### Duplicate words

The importer automatically skips words that already exist (matched by `text` field).

### Empty output

If `export-for-seeding` returns 0 words:
1. Make sure JMdict is downloaded: `medoru-data jmdict download`
2. Check that kanji characters are valid
3. Try with fewer kanji or higher `--max-per-kanji`

### All words have type "other" or no JLPT classification

If you exported words before the classification feature was added, re-export them:

```bash
cd data
pip install -e .  # Update the exporter

# Re-export with classification
medoru-data jmdict export-all-for-seeding \
  --limit 5000 \
  --output ../priv/repo/seeds/words_classified.json
```

### Long meaning errors

If you see `string_data_right_truncation` errors, the exporter has been updated to automatically truncate meanings to 250 characters. Re-export your data to get the fix.

---

## Complete Workflow Example

### Example 1: Export Words for Specific Kanji

```bash
# 1. Start fresh
mix ecto.reset

# 2. Seed kanji (required for word linking)
mix medoru.seed_kanji --all

# 3. Generate word data from JMdict
cd data
medoru-data jmdict download
medoru-data jmdict export-for-seeding \
  --kanji "日,一,国,人,年,大,十,二,本,中" \
  --max-per-kanji 5 \
  --output ../priv/repo/seeds/words_sample.json

# 4. Import words
cd ..
mix medoru.seed_words --file priv/repo/seeds/words_sample.json

# 5. Check stats
mix medoru.seed_words  # Shows current word count
```

### Example 2: Export ALL Words

```bash
# 1. Start fresh
mix ecto.reset

# 2. Seed kanji (required for word linking)
mix medoru.seed_kanji --all

# 3. Generate ALL word data from JMdict (takes a while!)
cd data
medoru-data jmdict download
medoru-data jmdict export-all-for-seeding \
  --output ../priv/repo/seeds/words_all.json

# 4. Import all words (this will take several minutes)
cd ..
mix medoru.seed_words --file priv/repo/seeds/words_all.json

# 5. Check final stats
mix medoru.seed_words
```

### Example 3: Export Top N Most Common Words

Since JMdict entries are roughly ordered by frequency, you can export the most common words:

```bash
cd data

# Export first 5000 entries (most common words)
medoru-data jmdict export-all-for-seeding \
  --limit 5000 \
  --output ../priv/repo/seeds/words_top5k.json

cd ..
mix medoru.seed_words --file priv/repo/seeds/words_top5k.json
```

---

## JMdict Data Source

- **Source**: https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project
- **License**: CC BY-SA 4.0
- **Copyright**: © EDRG
- **Entries**: ~215,000 total (~175,000 with kanji)
