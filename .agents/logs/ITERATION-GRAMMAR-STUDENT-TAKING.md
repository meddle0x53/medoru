# Iteration: Grammar Test Taking for Students

**Status**: IN PROGRESS
**Goal**: Implement student interface for taking tests with grammar steps

## Overview

Students can now view and take tests containing grammar steps. Tests can mix vocabulary and grammar steps.

## Step Types & Scoring

### 1. Sentence Validation (Pattern Builder)
- **Points**: 10 base
- **Attempts**: Up to 4 attempts
- **Scoring**: 10 → 7 → 4 → 1 → 0 (fail)
- **Mechanism**: Student enters sentences, validated against pattern

### 2. Conjugation (Text Input)
- **Points**: 3
- **Attempts**: 1
- **Mechanism**: Student types conjugated form

### 3. Conjugation Multichoice
- **Points**: 3
- **Attempts**: 1
- **Mechanism**: Student selects from 4-8 options

### 4. Word Order
- **Points**: 3
- **Attempts**: 1 (exact match required)
- **Mechanism**: Click words to build sentence in correct order
  - Two areas: source (shuffled) and answer (empty)
  - Click word in source → moves to answer
  - Click word in answer → moves back to source

## Implementation Plan

### Phase 1: Test Session Support
- [ ] Update `TestSession` to handle grammar step types
- [ ] Add scoring logic for sentence validation (degrading points)
- [ ] Add step type routing in test taking LiveView

### Phase 2: UI Components
- [ ] Sentence validation component with pattern display
- [ ] Conjugation input component
- [ ] Conjugation multichoice component  
- [ ] Word order drag-and-drop component

### Phase 3: Validation
- [ ] Pattern validation for sentences
- [ ] Conjugation answer checking
- [ ] Word order exact match checking

## Files to Modify

- `lib/medoru/tests/test_session.ex` - Add grammar step handling
- `lib/medoru_web/live/test_session_live/show.ex` - Main test taking UI
- `lib/medoru_web/live/test_session_live/step_components.ex` - Step rendering
