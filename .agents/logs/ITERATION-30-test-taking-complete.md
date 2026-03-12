# Iteration 30: Complete Classroom Test Taking Experience

**Status**: 🚧 IN PROGRESS  
**Started**: 2026-03-12  
**Priority**: 🔴 HIGH

## Overview

The current test-taking experience is incomplete. Students can start tests but many critical features are missing or broken.

## Issues to Fix

### 1. Timer Not Working ⏱️
- **Current**: Timer display shows but doesn't countdown
- **Expected**: Live countdown, auto-submit when time reaches 0
- **Files**: `ClassroomLive.Test`, JavaScript hook needed

### 2. No Test Results/Review Screen 📊
- **Current**: After last question, just redirects to classroom
- **Expected**: Results page showing:
  - Score (X/Y points)
  - Percentage
  - Which answers were correct/incorrect
  - Correct answers for wrong responses
  - Time spent
- **Files**: New `ClassroomLive.TestResults` LiveView

### 3. Timer Not Recorded 📝
- **Current**: Time remaining not updated in real-time
- **Expected**: Track actual time spent, save to attempt

### 4. No Auto-Submit ⏹️
- **Current**: Timer hits 0 but nothing happens
- **Expected**: Auto-submit test with current answers

### 5. Step Progress Not Saved 💾
- **Current**: If student refreshes, they lose progress
- **Expected**: Progress saved after each answer

### 6. No Resume Support 🔄
- **Current**: "Continue" button exists but may not work properly
- **Expected**: Seamless resume from where they left off

## Files to Create/Modify

### New Files
- `lib/medoru_web/live/classroom_live/test_results.ex` - Results/review screen
- `assets/js/hooks/test_timer.js` - Timer countdown hook

### Modified Files
- `lib/medoru_web/live/classroom_live/test.ex` - Core test taking logic
- `lib/medoru/classrooms.ex` - Timer updates, auto-submit
- `lib/medoru/tests.ex` - Step answer recording
- `lib/medoru_web/components/test_components.ex` - Reusable test UI

## Technical Tasks

1. [ ] Create JavaScript timer hook with 1-second countdown
2. [ ] Add `tick` event handler to update time_remaining in DB
3. [ ] Implement auto-submit when timer reaches 0
4. [ ] Create test results LiveView with score breakdown
5. [ ] Show correct/incorrect for each question
6. [ ] Add progress saving after each answer
7. [ ] Test resume functionality thoroughly

## UI Mockup

```
┌─────────────────────────────────────┐
│ Test Results: Test 2               │
│                                     │
│ Score: 6/8 points (75%)            │
│ Time: 4m 32s / 10m                 │
│                                     │
├─────────────────────────────────────┤
│ Q1: What is 日本?                  │
│ Your answer: Japan ✓               │
│ Points: 1/1                        │
├─────────────────────────────────────┤
│ Q2: How do you read "黒色"?        │
│ Your answer: 白色 ✗                │
│ Correct: 黒色                       │
│ Points: 0/1                        │
├─────────────────────────────────────┤
│ ... more questions ...             │
│                                     │
│ [Back to Classroom]                │
└─────────────────────────────────────┘
```

## Acceptance Criteria

- [ ] Timer counts down every second
- [ ] Test auto-submits at 0 seconds
- [ ] Results page shows score breakdown
- [ ] Correct/incorrect clearly marked
- [ ] Wrong answers show correct answer
- [ ] Time spent recorded accurately
- [ ] Can resume in-progress tests
- [ ] Progress saved after each question

## Estimated Time

2-3 days
