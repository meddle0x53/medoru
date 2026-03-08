# Medoru Data Pipeline - Development Index

**Last Updated:** 2026-03-08  
**Status:** Milestone 5 Complete ✅

---

## Quick Stats

| Metric | Count |
|--------|-------|
| Total Kanji | 13,108 |
| With N5-N1 Levels | 2,211 |
| With Stroke Data | 2,211 (100%) |
| With Radical Data | 2,132 (96%) |

---

## Milestones

### ✅ Milestone 1: KanjiVG Integration
**Status:** COMPLETE  
**Date:** 2026-03-08

- [x] Download KanjiVG SVG files from GitHub
- [x] Parse SVG stroke paths with cubic bezier curves
- [x] Extract stroke order, type, and direction
- [x] Export to Medoru JSON format
- [x] CLI interface with `medoru-data kanjivg` commands
- [x] Attribution handling

**Files:**
- `src/medoru_data/spiders/kanjivg.py`
- `src/medoru_data/exporters/kanji_exporter.py`

---

### ✅ Milestone 2: KANJIDIC2 Integration
**Status:** COMPLETE  
**Date:** 2026-03-08

- [x] Download KANJIDIC2 XML
- [x] Parse kanji metadata (meanings, readings, stroke count)
- [x] Export to Medoru seed format
- [x] Romaji generation for readings
- [x] **Note:** Uses OLD JLPT levels (1-4), not N5-N1

**Files:**
- `src/medoru_data/spiders/kanjidic2.py`

---

### ✅ Milestone 3: Comprehensive Kanji Data (N5-N1)
**Status:** COMPLETE  
**Date:** 2026-03-08

- [x] Download from davidluzgouveia/kanji-data
- [x] NEW JLPT levels (N5-N1) mapping
- [x] Stroke counts
- [x] Complete readings with romaji
- [x] Frequency and grade information
- [x] Export all levels N5-N1

**Export Counts:**
| Level | Count |
|-------|-------|
| N5 | 79 |
| N4 | 166 |
| N3 | 367 |
| N2 | 367 |
| N1 | 1,232 |
| **Total** | **2,211** |

**Files:**
- `src/medoru_data/spiders/kanji_data.py`

---

### ✅ Milestone 4: Combined Data (Metadata + Strokes)
**Status:** COMPLETE  
**Date:** 2026-03-08

- [x] Cross-reference kanji-data (N5-N1 levels) with KanjiVG (stroke data)
- [x] 100% stroke data coverage for all JLPT levels
- [x] Combined export with metadata + stroke SVG paths
- [x] CLI command: `medoru-data kanji-data export-with-strokes`

**Command:**
```bash
medoru-data kanji-data export-with-strokes --level N5 --output seeds/kanji_n5_with_strokes.json
```

**Files:**
- `src/medoru_data/exporters/combined_kanji_exporter.py`

---

### ✅ Milestone 5: Radical Data (Make Me A Hanzi)
**Status:** COMPLETE  
**Date:** 2026-03-08

- [x] Download from skishore/makemeahanzi
- [x] Extract radical information for each kanji
- [x] Character decomposition data (IDS format)
- [x] Etymology/hint information
- [x] Full combined export (metadata + strokes + radicals)
- [x] Import into Medoru database

**Radical Coverage:**
| Level | Kanji | With Radicals |
|-------|-------|---------------|
| N5 | 79 | 76 (96%) |
| N4 | 166 | 153 (92%) |
| N3 | 367 | 327 (89%) |
| N2 | 367 | 330 (90%) |
| N1 | 1,232 | 1,075 (87%) |
| **Total** | **2,211** | **1,961 (89%)** |

**Command:**
```bash
# Export full data
medoru-data export-full --level N5 --output seeds/kanji_n5_full.json

# Import into Medoru
mix medoru.seed_radicals --all
```

**Files:**
- `src/medoru_data/spiders/makemeahanzi.py`
- `src/medoru_data/exporters/full_kanji_exporter.py`

---

## Data Sources

| Source | Data | License | Attribution |
|--------|------|---------|-------------|
| [Kanji Data](https://github.com/davidluzgouveia/kanji-data) | JLPT N5-N1 levels, metadata | MIT | © davidluzgouveia |
| [KanjiVG](http://kanjivg.tagaini.net) | Stroke order SVGs | CC BY-SA 3.0 | © Ulrich Apel |
| [Make Me A Hanzi](https://github.com/skishore/makemeahanzi) | Radicals, decomposition | CC BY-SA 4.0 | © skishore |
| [KANJIDIC2](https://www.edrdg.org/wiki/index.php/KANJIDIC_Project) | Dictionary data | CC BY-SA 4.0 | © EDRG |

---

## CLI Commands Reference

### KanjiVG (Strokes)
```bash
medoru-data kanjivg download
medoru-data kanjivg export --level N5 --output seeds/strokes_n5.json
medoru-data kanjivg status
```

### KANJIDIC2 (Old Levels 1-4)
```bash
medoru-data kanjidic2 download
medoru-data kanjidic2 export --level N1 --output seeds/kanji_old_n1.json
medoru-data kanjidic2 stats
```

### Kanji Data (N5-N1 Levels)
```bash
medoru-data kanji-data download
medoru-data kanji-data export --level N5 --output seeds/kanji_n5.json
medoru-data kanji-data export-with-strokes --level N5 --output seeds/kanji_n5_with_strokes.json
medoru-data kanji-data stats
```

### Make Me A Hanzi (Radicals)
```bash
medoru-data makemeahanzi download
medoru-data makemeahanzi lookup --characters "語明東国日"
medoru-data makemeahanzi status
```

### Full Export (Everything)
```bash
medoru-data export-full --level N5 --output seeds/kanji_n5_full.json
medoru-data export-full --level all --output seeds/kanji_all_full.json
```

---

## Output Files

### Seed Files (Ready for Medoru)
| File | Size | Contents |
|------|------|----------|
| `seeds/kanji_n5_full.json` | 186K | 79 N5 kanji with full data |
| `seeds/kanji_n4_full.json` | 484K | 166 N4 kanji with full data |
| `seeds/kanji_n3_full.json` | 1.2M | 367 N3 kanji with full data |
| `seeds/kanji_n2_full.json` | 1.2M | 367 N2 kanji with full data |
| `seeds/kanji_n1_full.json` | 4.2M | 1,232 N1 kanji with full data |

### Data Fields
Each kanji JSON includes:
```json
{
  "character": "語",
  "meanings": ["language", "words"],
  "stroke_count": 14,
  "jlpt_level": 5,
  "frequency": 65,
  "grade": 2,
  "radicals": ["言"],
  "stroke_data": {
    "bounds": {...},
    "strokes": [...]
  },
  "decomposition": "⿰言吾",
  "etymology": {
    "type": "pictophonetic",
    "hint": "words",
    "phonetic": "吾",
    "semantic": "言"
  },
  "readings": [
    {"reading_type": "on", "reading": "ゴ", "romaji": "go"}
  ]
}
```

---

## Next Steps / Future Milestones

### Milestone 6: JMdict Integration (Words)
- [ ] Download JMdict
- [ ] Parse word entries
- [ ] Cross-reference with kanji
- [ ] Export vocabulary lists by JLPT level

### Milestone 7: Example Sentences
- [ ] Integrate Tatoeba or similar corpus
- [ ] Match sentences to kanji/words
- [ ] Difficulty grading

### Milestone 8: Audio Data
- [ ] Text-to-speech integration
- [ ] Native speaker recordings
- [ ] Pronunciation guides

---

## Project Structure

```
data/
├── README.md                 # This file
├── INDEX.md                  # Development tracking (this document)
├── milestones/               # Detailed milestone docs
│   ├── M1-kanjivg.md
│   ├── M2-kanjidic2.md
│   ├── M3-kanji-data.md
│   ├── M4-combined-export.md
│   └── M5-radicals.md
├── src/medoru_data/          # Python package
│   ├── spiders/              # Data downloaders
│   │   ├── kanjivg.py
│   │   ├── kanjidic2.py
│   │   ├── kanji_data.py
│   │   └── makemeahanzi.py
│   ├── exporters/            # JSON exporters
│   │   ├── kanji_exporter.py
│   │   ├── combined_kanji_exporter.py
│   │   └── full_kanji_exporter.py
│   ├── cli.py                # CLI entry point
│   └── config.py             # Configuration
├── seeds/                    # Output JSON files
├── raw/                      # Downloaded raw data
└── processed/                # Processed intermediate files
```

---

## License Compliance Checklist

- [x] All data sources attributed in `_meta` of exported JSON
- [x] Attribution page updated in Medoru web app
- [x] Footer shows data source credits
- [x] README documents all licenses
- [x] Commercial use verified (MIT + CC BY-SA compatible)

---

## Notes

- **KanjiVG** data uses CC BY-SA 3.0 (ShareAlike)
- **KANJIDIC2** uses CC BY-SA 4.0
- **Make Me A Hanzi** uses CC BY-SA 4.0
- **Kanji Data** uses MIT (most permissive)

All licenses allow commercial use with proper attribution.
