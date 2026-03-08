# Medoru Data Collection Pipeline

Python sub-project for collecting and processing Japanese language data for the Medoru platform.

## Overview

This pipeline collects kanji and vocabulary data from various open sources, processes it, and exports seed files for the Medoru Elixir/Phoenix application.

## Data Sources

| Source | Data | License | Attribution |
|--------|------|---------|-------------|
| [KanjiVG](http://kanjivg.tagaini.net) | Kanji stroke order SVGs | CC BY-SA 3.0 | © Ulrich Apel |
| [KANJIDIC2](https://www.edrdg.org/wiki/index.php/KANJIDIC_Project) | Kanji metadata (readings, meanings) | CC BY-SA 4.0 | © EDRG |
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

### Run Full Pipeline for N5 Kanji
```bash
medoru-data pipeline run --level N5 --output-dir seeds/
```

## Development Milestones

### Milestone 1: KanjiVG Integration ✅
- [x] Download KanjiVG SVG files
- [x] Parse SVG stroke paths
- [x] Export to Medoru JSON format
- [x] Attribution handling

### Milestone 2: KANJIDIC2 Integration
- [ ] Download KANJIDIC2 XML
- [ ] Parse kanji metadata
- [ ] Cross-reference with KanjiVG
- [ ] Export to seeds

### Milestone 3: JMdict Integration
- [ ] Download JMdict
- [ ] Parse word entries
- [ ] Cross-reference with kanji
- [ ] Export to seeds

### Milestone 4: N-Level Filtering
- [ ] Filter by JLPT levels
- [ ] Frequency-based filtering
- [ ] Lesson-sized datasets

## License

This project is proprietary. Third-party data is used under their respective licenses as documented above.
