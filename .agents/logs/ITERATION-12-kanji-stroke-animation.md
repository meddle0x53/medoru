# Iteration 11: Kanji Stroke Animation

**Status**: PLANNED  
**Date**: 2026-03-07  
**Priority**: High

## Overview

Implement animated kanji stroke order visualization using SVG stroke data. This feature helps users learn proper stroke order and direction when studying kanji characters.

## Goals

1. **Stroke Data Storage**
   - SVG path data for each kanji stroke
   - Stroke order metadata (sequence, direction)
   - Radical decomposition data

2. **Stroke Animation Component**
   - Animated drawing of each stroke
   - Play/pause/reset controls
   - Adjustable animation speed
   - Step-by-step mode

3. **Practice Mode**
   - User draws strokes with mouse/touch
   - Real-time feedback on stroke accuracy
   - Progress tracking for stroke practice

4. **Integration**
   - Show on kanji detail pages
   - Include in lessons
   - Practice mode in daily reviews

## User Stories

As a learner, I want to:
- See how each kanji stroke is drawn in correct order
- Control the animation (play, pause, step-by-step)
- Practice drawing strokes myself
- Get feedback on my stroke accuracy

## Technical Approach

### Data Source
- KanjiVG (Kanji Vector Graphics) - open source SVG stroke data
- Or generate simplified SVG paths from stroke order data
- Store as JSONB in `kanji` table (already has `stroke_data` field)

### Schema Extension

```elixir
# Using existing kanji.stroke_data JSONB field
%Kanji{
  stroke_data: %{
    svg_paths: [
      %{path: "M 10 10 L 50 10", order: 1, type: "horizontal"},
      %{path: "M 30 10 L 30 90", order: 2, type: "vertical"}
    ],
    bounds: %{width: 100, height: 100},
    radicals: ["日"]
  }
}
```

### Components

**1. StrokeAnimator Component**
- Renders SVG with animated paths
- Controls: play, pause, reset, speed
- Step forward/backward
- Auto-loop option

**2. StrokePractice Component**
- Canvas for user drawing
- Stroke recognition
- Accuracy scoring
- Feedback overlay

## UI Design

### Kanji Detail Page Enhancement
```
┌─────────────────────────────────────────────────────────────┐
│ 日 - Sun / Day / Japan                                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    ┌───────────┐                            │
│                    │           │  ┌──────────────────┐      │
│                    │   ╔═══╗   │  │ Stroke Order:    │      │
│                    │   ║ 日 ║   │  │ 1. ━ (horizontal)│      │
│                    │   ╚═══╝   │  │ 2. │ (vertical)   │      │
│                    │           │  │ 3. ━ (horizontal)│      │
│                    │  [▶ Play] │  │ 4. │ (vertical)   │      │
│                    │  [◀ Prev] │  │                  │      │
│                    │  [▶ Next] │  │ Speed: [●━━━]    │      │
│                    └───────────┘  └──────────────────┘      │
│                                                             │
│  [Practice Mode]  [Slow Motion]  [Loop]                     │
└─────────────────────────────────────────────────────────────┘
```

### Practice Mode
```
┌─────────────────────────────────────────────────────────────┐
│ Practice: 日                                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    ┌───────────┐                            │
│                    │           │                            │
│                    │  [draw    │   Draw stroke 1:           │
│                    │   here]   │   Horizontal line          │
│                    │           │   from left to right       │
│                    └───────────┘                            │
│                                                             │
│  Progress: ████░░░░ 4/10                                   │
│                                                             │
│  [Hint] [Skip] [Give Up]                                   │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Tasks

### 1. Data Import
- Download/import KanjiVG data for N5 kanji
- Parse SVG paths into structured JSON
- Create migration to populate `stroke_data`

### 2. Core Components

**StrokeAnimator LiveComponent** (`lib/medoru_web/components/stroke_animator.ex`)
- SVG renderer with animated paths
- CSS animations or JS-controlled drawing
- Playback controls

**StrokePractice LiveComponent** (`lib/medoru_web/components/stroke_practice.ex`)
- Canvas-based drawing interface
- Stroke recognition algorithm
- Scoring/feedback system

### 3. Page Integration

**Kanji Show Page** (`lib/medoru_web/live/kanji_live/show.ex`)
- Add stroke animation tab/panel
- Embed StrokeAnimator component

**New Practice Page** (`lib/medoru_web/live/kanji_practice_live.ex`)
- Standalone stroke practice mode
- Random kanji selection
- Progress tracking

### 4. Algorithm

**Stroke Recognition (Simplified)**
- Capture user stroke as point array
- Compare to template stroke path
- Calculate similarity score
- Threshold for pass/fail

**Scoring Criteria:**
- Direction correctness (start → end)
- Shape similarity
- Proportions
- Overall smoothness

## Files to Create

```
lib/medoru_web/components/
├── stroke_animator.ex
├── stroke_practice.ex
└── stroke_renderer.ex

lib/medoru_web/live/kanji_live/
└── practice.ex (new file for practice mode)

lib/medoru/stroke_recognition.ex (optional - for scoring)

priv/repo/seeds/kanjivg/ (stroke data JSON files)
```

## Files to Modify

```
lib/medoru_web/live/kanji_live/show.ex
lib/medoru_web/live/kanji_live/show.html.heex
priv/repo/seeds.exs (add stroke data seeding)
```

## Dependencies

- KanjiVG data (open source)
- Optional: JavaScript for complex canvas interactions
- Existing `kanji` schema with `stroke_data` JSONB field

## Testing

### Unit Tests
- Stroke data parsing
- Animation state machine
- Scoring algorithm

### Integration Tests
- Animation playback
- Practice mode flow
- Canvas interactions

## Definition of Done

- [ ] N5 kanji have stroke data imported
- [ ] Stroke animation plays correctly
- [ ] Playback controls work (play/pause/step)
- [ ] Animation speed is adjustable
- [ ] Practice mode allows drawing
- [ ] Basic stroke scoring implemented
- [ ] Integrated on kanji detail pages
- [ ] Tests passing

## Next Steps After Completion

**Iteration 13: Admin Badge Management**
- Admin interface for managing badges
- Create/edit/delete badges
- Icon selector and preview

## Notes

- KanjiVG license: Creative Commons BY-SA 3.0
- Start with N5 kanji only (~80 characters)
- Can expand to N4, N3, etc. in later iterations
- Consider using existing JS libraries like HanziWriter if needed
