# Milestone 5: Radical Data (Make Me A Hanzi)

**Status:** ✅ COMPLETE  
**Date:** 2026-03-08  
**Priority:** High

## Overview

Added radical information, character decomposition, and etymology from Make Me A Hanzi.

## Why This Matters

Radicals are essential for:
- Understanding kanji structure
- Looking up characters in dictionaries
- Learning etymology and memorization

## Data Coverage

| Level | Kanji | With Radicals | Coverage |
|-------|-------|---------------|----------|
| N5 | 79 | 76 | 96% |
| N4 | 166 | 153 | 92% |
| N3 | 367 | 327 | 89% |
| N2 | 367 | 330 | 90% |
| N1 | 1,232 | 1,075 | 87% |
| **Total** | **2,211** | **1,961** | **89%** |

## Data Fields Added

### Radical
Main radical for the kanji:
```json
{
  "character": "語",
  "radical": "言",
  "radicals": ["言"]
}
```

### Decomposition
IDS (Ideographic Description Sequence) format:
```json
{
  "decomposition": "⿰言吾"
}
```

Common operators:
- `⿰` - Left-right (e.g., 明 = ⿰日月)
- `⿱` - Top-bottom (e.g., 書 = ⿱聿曰)
- `⿴` - Surround (e.g., 国 = ⿴玉囗)
- `⿻` - Overlay (e.g., 東 = ⿻木日)

### Etymology
Origin and meaning:
```json
{
  "etymology": {
    "type": "ideographic",
    "hint": "The light of the sun 日 and moon 月",
    "phonetic": "吾",
    "semantic": "言"
  }
}
```

Types:
- `pictographic` - Drawn from nature (日, 山, 水)
- `ideographic` - Combined meanings (明 = sun + moon)
- `pictophonetic` - Meaning + sound component (語 = 言 + 吾)

## Implementation

### Files Created
- `src/medoru_data/spiders/makemeahanzi.py`
- `src/medoru_data/exporters/full_kanji_exporter.py`

### CLI Commands
```bash
# Download radical data
medoru-data makemeahanzi download

# Look up specific kanji
medoru-data makemeahanzi lookup --characters "語明東国日"

# Export full data (includes radicals)
medoru-data export-full --level N5 --output seeds/kanji_n5_full.json
```

### Import into Medoru
```bash
# Seed radical data into database
mix medoru.seed_radicals --all
```

## Attribution

- **Source:** https://github.com/skishore/makemeahanzi
- **License:** CC BY-SA 4.0
- **Copyright:** © skishore
- **Derived from:** TW-Sung fonts

## Definition of Done

- [x] Download Make Me A Hanzi data
- [x] Extract radical information
- [x] Parse decomposition (IDS format)
- [x] Extract etymology/hints
- [x] Full combined export (kanji-data + KanjiVG + MakeMeAHanzi)
- [x] Import into Medoru database
- [x] Display on kanji detail page
- [x] Attribution compliance
