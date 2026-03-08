# Iteration 12: Kanji Stroke Animation

**Status**: ✅ APPROVED  
**Date**: 2026-03-08  
**Priority**: High

## Overview

Implemented animated kanji stroke order visualization using **KanjiVG** real SVG stroke data. This feature helps users learn proper stroke order and direction when studying kanji characters.

## Changes Made

### 1. KanjiVG Data Integration

**New Python Data Pipeline** (`data/`)
```
data/
├── pyproject.toml           # Python project config
├── requirements.txt         # Dependencies
├── README.md               # Documentation
├── src/medoru_data/        # Main package
│   ├── spiders/kanjivg.py  # KanjiVG downloader/parser
│   ├── exporters/          # Export to Medoru format
│   └── config.py          # Source configurations
├── raw/                    # Downloaded data
├── processed/              # Parsed data
└── seeds/                  # Output for Medoru
```

**Features:**
- Downloads KanjiVG from GitHub
- Parses SVG stroke paths with cubic bezier curves
- Extracts stroke order, type, and direction
- Exports to Medoru JSON format
- CLI interface with `medoru-data` command

### 2. KanjiVG Format

Real KanjiVG data includes:
```json
{
  "bounds": {"width": 109, "height": 109, "viewBox": "0 0 109 109"},
  "strokes": [
    {
      "order": 1,
      "path": "M31.5,24.5c1.12,1.12...",  // Cubic bezier curves
      "type": "vertical",
      "direction": "top-to-bottom"
    }
  ]
}
```

**Key improvements over handmade data:**
- **Cubic bezier curves** (not straight lines) - accurate stroke shapes
- **109x109 viewBox** - Japanese schoolbook font proportions
- **Proper stroke types** - Based on Unicode CJK Strokes

### 3. Seeded Kanji (16 characters with KanjiVG data)

一, 二, 三, 四, 五, 六, 七, 八, 九, 十, 人, 国, 大, 年, 日, 月, 本, 中, 上, 九, 口, 左, 右

### 4. Core Component

**lib/medoru_web/components/stroke_animator.ex**
LiveComponent with:
- SVG renderer with animated paths
- Playback controls (play, pause, step forward/backward, reset, loop)
- Stroke order list with visual indicators
- Adjustable animation speed (0.5x - 3x)
- Toggle for stroke number display
- Progress indicator

### 5. Page Integration

- **Kanji detail page** - Shows stroke animation when data available
- **CSS animations** - `draw` keyframe for stroke effect

### 6. Attribution & Licensing

- **Footer** with KanjiVG attribution on every page
- **Attribution page** at `/attribution` with full details
- **README.md** updated with data sources

**License Compliance:**
- KanjiVG: CC BY-SA 3.0 (commercial use allowed with attribution)
- KANJIDIC2: CC BY-SA 4.0 (commercial use allowed with attribution)

### 7. Tests

- Component rendering tests
- Empty state handling
- Stroke count display

## Files Created

```
data/                                    # NEW Python sub-project
├── pyproject.toml
├── requirements.txt
├── requirements-dev.txt
├── README.md
├── .gitignore
├── src/medoru_data/
│   ├── __init__.py
│   ├── config.py
│   ├── cli.py
│   ├── spiders/
│   │   ├── __init__.py
│   │   └── kanjivg.py
│   ├── exporters/
│   │   ├── __init__.py
│   │   └── kanji_exporter.py
│   ├── db/
│   │   └── __init__.py
│   ├── parsers/
│   │   └── __init__.py
│   └── utils/
│       └── __init__.py
├── spiders/
│   └── README.md
├── raw/.gitkeep
├── processed/.gitkeep
└── seeds/.gitkeep

priv/repo/seeds/kanjivg_strokes.json     # Real KanjiVG stroke data
lib/medoru/release/seeds/kanjivg.ex     # KanjiVG seeder module
test/medoru_web/components/stroke_animator_test.exs
lib/medoru_web/live/settings_live/attribution.ex  # Attribution page
```

## Files Modified

```
lib/medoru/release/seeds.ex              # Added KanjiVG seeding
lib/medoru_web/live/kanji_live/show.ex   # Added has_stroke_data assign
lib/medoru_web/live/kanji_live/show.html.heex  # Added stroke animation
lib/medoru_web/components/layouts.ex     # Added footer with attribution
lib/medoru_web/components/stroke_animator.ex   # Fixed string key access
lib/medoru_web/router.ex                 # Added attribution route
assets/css/app.css                       # Added animation styles
README.md                                # Added attribution info
```

## Usage

### Python Data Pipeline

```bash
cd data
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt

# Download KanjiVG
medoru-data kanjivg download

# Export N5 kanji
medoru-data kanjivg export --level N5 --output seeds/kanjivg_n5.json

# Show status
medoru-data kanjivg status
```

### Elixir Seeding

```bash
mix run -e "Medoru.Release.Seeds.KanjiVG.seed()"
```

## Technical Details

### KanjiVG SVG Format

KanjiVG files are named with Unicode codepoint in hex (e.g., `04e00.svg` for 一).
Each SVG contains:
- `StrokePaths` group with `<path>` elements for each stroke
- `kvg:type` attribute with stroke type (㇐, ㇑, ㇒, etc.)
- Path data using only M, C, S commands (cubic bezier curves)
- `StrokeNumbers` group with position hints

### Animation

Uses CSS `stroke-dasharray` and `stroke-dashoffset`:
```css
@keyframes draw {
  to { stroke-dashoffset: 0; }
}
```

## Test Results

```
277 tests, 0 failures
```

## Definition of Done

- [x] Python data pipeline created
- [x] KanjiVG downloader/parser implemented
- [x] N5 kanji have stroke data imported (16+ characters)
- [x] Stroke animation displays correctly
- [x] Playback controls work
- [x] Animation speed is adjustable
- [x] Stroke numbers can be toggled
- [x] Integrated on kanji detail pages
- [x] Attribution implemented (footer + page)
- [x] License compliance documented
- [x] Tests passing (277 tests)

## Next Steps

**Iteration 13: Admin Badge Management**
- Admin interface for managing badges
- Create/edit/delete badges
- Icon selector and preview
