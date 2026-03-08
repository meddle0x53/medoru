# Medoru Data Collection Pipeline

Python sub-project for collecting and processing Japanese language data for the Medoru platform.

📊 **Development Status:** See [INDEX.md](INDEX.md) for detailed milestone tracking  
📁 **Milestones:** See [milestones/](milestones/) for detailed documentation

## Overview

This pipeline collects kanji and vocabulary data from various open sources, processes it, and exports seed files for the Medoru Elixir/Phoenix application.

## Data Sources

| Source | Data | License | Attribution |
|--------|------|---------|-------------|
| [KanjiVG](http://kanjivg.tagaini.net) | Kanji stroke order SVGs | CC BY-SA 3.0 | © Ulrich Apel |
| [KANJIDIC2](https://www.edrdg.org/wiki/index.php/KANJIDIC_Project) | Kanji metadata (readings, meanings, old JLPT 1-4) | CC BY-SA 4.0 | © EDRG |
| [Kanji Data](https://github.com/davidluzgouveia/kanji-data) | Comprehensive kanji with NEW JLPT N5-N1 | MIT | © davidluzgouveia |
| [Make Me A Hanzi](https://github.com/skishore/makemeahanzi) | Radicals, decomposition, etymology | CC BY-SA 4.0 | © skishore |
| [JMdict](https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project) | Japanese-English dictionary | CC BY-SA 4.0 | © EDRG |

## Project Structure

```
data/
├── src/medoru_data/       # Main Python package
│   ├── spiders/           # Data collection modules
│   ├── parsers/           # Data parsing utilities
│   ├── exporters/         # Export to Medoru format
│   └── db/                # Database models
├── raw/                   # Downloaded raw data (gitignored)
├── processed/             # Parsed/processed data (gitignored)
└── seeds/                 # Final seed files for Medoru
```

## Installation

```bash
cd data
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
```

## Usage

### Download KanjiVG Data
```bash
medoru-data kanjivg download
```

### Parse and Export
```bash
medoru-data kanjivg export --level N5 --output seeds/kanjivg_n5.json
```

### KANJIDIC2 Kanji Metadata
```bash
# Download KANJIDIC2 (old JLPT levels 1-4)
medoru-data kanjidic2 download

# Export all kanji
medoru-data kanjidic2 export --level all --output seeds/kanji_all.json

# Export specific level (uses old JLPT 1-4)
medoru-data kanjidic2 export --level N1 --output seeds/kanji_old_n1.json

# Show statistics
medoru-data kanjidic2 stats
```

### Comprehensive Kanji Data (Recommended - N5-N1 Levels)
```bash
# Download comprehensive kanji data with NEW JLPT levels
medoru-data kanji-data download

# Export specific JLPT level (N5-N1)
medoru-data kanji-data export --level N5 --output seeds/kanji_n5.json
medoru-data kanji-data export --level N4 --output seeds/kanji_n4.json
medoru-data kanji-data export --level N3 --output seeds/kanji_n3.json
medoru-data kanji-data export --level N2 --output seeds/kanji_n2.json
medoru-data kanji-data export --level N1 --output seeds/kanji_n1.json

# Export all kanji with new JLPT levels
medoru-data kanji-data export --level all --output seeds/kanji_all.json

# Show statistics
medoru-data kanji-data stats

# Check status
medoru-data kanji-data status
```

### Make Me A Hanzi (Radicals)
```bash
# Download radical data
medoru-data makemeahanzi download

# Look up radicals for specific kanji
medoru-data makemeahanzi lookup --characters "語明東国日"

# Check status
medoru-data makemeahanzi status
```

### Combined Export (Kanji + Stroke Data) ⭐ RECOMMENDED
```bash
# First ensure KanjiVG is downloaded
medoru-data kanjivg download

# Export kanji with N5-N1 levels AND stroke animation data
medoru-data kanji-data export-with-strokes --level N5 --output seeds/kanji_n5_with_strokes.json
medoru-data kanji-data export-with-strokes --level N4 --output seeds/kanji_n4_with_strokes.json
medoru-data kanji-data export-with-strokes --level N3 --output seeds/kanji_n3_with_strokes.json
medoru-data kanji-data export-with-strokes --level N2 --output seeds/kanji_n2_with_strokes.json
medoru-data kanji-data export-with-strokes --level N1 --output seeds/kanji_n1_with_strokes.json

# Export all levels with strokes
medoru-data kanji-data export-with-strokes --level all --output seeds/kanji_all_with_strokes.json
```

**Output includes:**
- Character, meanings, stroke count
- **NEW JLPT levels (N5-N1)** ✅
- Frequency and grade
- On/kun readings with romaji
- **Stroke animation data (SVG paths)** ✅

### Full Export (Kanji + Strokes + Radicals) ⭐ RECOMMENDED

First download all required data sources:
```bash
# Download all data sources
medoru-data kanji-data download
medoru-data kanjivg download
medoru-data makemeahanzi download
```

Then export complete kanji data:
```bash
# Export kanji with metadata + stroke data + radical data
medoru-data export-full --level N5 --output seeds/kanji_n5_full.json
medoru-data export-full --level N4 --output seeds/kanji_n4_full.json
medoru-data export-full --level N3 --output seeds/kanji_n3_full.json
medoru-data export-full --level N2 --output seeds/kanji_n2_full.json
medoru-data export-full --level N1 --output seeds/kanji_n1_full.json

# Or all levels at once
medoru-data export-full --level all --output seeds/kanji_all_full.json
```

**Output includes everything:**
- Character, meanings, stroke count
- **NEW JLPT levels (N5-N1)** ✅
- Frequency and grade
- On/kun readings with romaji
- **Stroke animation data (SVG paths)** ✅
- **Radical information** ✅
- **Character decomposition** ✅
- **Etymology/hints** ✅

## Development Milestones

### Milestone 1: KanjiVG Integration ✅
- [x] Download KanjiVG SVG files
- [x] Parse SVG stroke paths
- [x] Export to Medoru JSON format
- [x] Attribution handling

### Milestone 2: KANJIDIC2 Integration ✅
- [x] Download KANJIDIC2 XML
- [x] Parse kanji metadata (meanings, readings, stroke count, JLPT level)
- [x] Filter by JLPT levels
- [x] Export to Medoru seed format
- [x] Romaji generation for readings

### Milestone 3: Comprehensive Kanji Data with N5-N1 Levels ✅
- [x] Download from davidluzgouveia/kanji-data
- [x] New JLPT levels (N5-N1) mapping
- [x] Stroke counts
- [x] Complete readings with romaji
- [x] Frequency and grade information
- [x] Export all levels N5-N1

### Milestone 4: Combined Kanji Data with Stroke Animation ✅
- [x] Cross-reference kanji-data (N5-N1 levels) with KanjiVG (stroke data)
- [x] 100% stroke data coverage for all JLPT levels
- [x] Combined export with metadata + stroke SVG paths
- [x] Ready for stroke animation in Medoru

### Milestone 5: Radical Data from Make Me A Hanzi ✅
- [x] Download from skishore/makemeahanzi
- [x] Extract radical information for each kanji
- [x] Character decomposition data
- [x] Etymology/hint information
- [x] Full combined export (metadata + strokes + radicals)

### Milestone 6: JMdict Integration ✅
- [x] Download JMdict (215,000+ entries)
- [x] Parse word entries (kanji forms, readings, senses, POS tags)
- [x] Cross-reference with kanji
- [x] Export to Medoru word format
- [x] Word type classification (noun, verb, adjective, etc.)
- [x] JLPT level calculation based on kanji
- [x] CLI: `export-for-seeding`, `export-all-for-seeding`
- [x] Elixir mix task: `mix medoru.seed_words`

### JMdict Word Export
```bash
# Download JMdict
medoru-data jmdict download

# Export all words with kanji
medoru-data jmdict export --output seeds/words_all.json

# Export words for specific kanji (e.g., N5 set)
medoru-data jmdict export-for-kanji --kanji "日,月,火,水,木" --output seeds/words_sample.json

# Show statistics
medoru-data jmdict stats
```

### Milestone 7: Example Sentences (Planned)
- [ ] Integrate Tatoeba corpus
- [ ] Match sentences to kanji/words
- [ ] Difficulty grading

## License

This project is proprietary. Third-party data is used under their respective licenses as documented above.
