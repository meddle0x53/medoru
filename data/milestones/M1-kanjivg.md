# Milestone 1: KanjiVG Integration

**Status:** ✅ COMPLETE  
**Date:** 2026-03-08  
**Priority:** High

## Overview

Implemented animated kanji stroke order visualization using KanjiVG real SVG stroke data.

## Goals

1. Download KanjiVG data from GitHub
2. Parse SVG stroke paths
3. Export to Medoru JSON format
4. Provide CLI interface

## Implementation

### Files Created
- `src/medoru_data/spiders/kanjivg.py` - Spider for downloading/parsing
- `src/medoru_data/exporters/kanji_exporter.py` - Export functions

### CLI Commands
```bash
medoru-data kanjivg download
medoru-data kanjivg export --level N5 --output seeds/strokes_n5.json
medoru-data kanjivg status
```

### Data Format
```json
{
  "bounds": {"width": 109, "height": 109, "viewBox": "0 0 109 109"},
  "strokes": [
    {
      "order": 1,
      "path": "M30,30 Q50,20 70,30",
      "type": "vertical",
      "direction": "top-to-bottom"
    }
  ]
}
```

## Technical Details

- Uses cubic bezier curves (not straight lines)
- 109x109 viewBox (Japanese schoolbook proportions)
- Proper stroke types from Unicode CJK Strokes

## Attribution

- **Source:** KanjiVG (http://kanjivg.tagaini.net)
- **License:** CC BY-SA 3.0
- **Copyright:** © Ulrich Apel

## Definition of Done

- [x] Python data pipeline created
- [x] KanjiVG downloader/parser implemented
- [x] N5 kanji have stroke data imported
- [x] Stroke animation displays correctly
- [x] Attribution implemented
- [x] License compliance documented
