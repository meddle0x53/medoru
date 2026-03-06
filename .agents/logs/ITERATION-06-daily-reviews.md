# Iteration 6: Daily Reviews & Streaks

**Status**: IN_PROGRESS  
**Date**: 2026-03-06  
**Reviewed By**: -  
**Approved**: NO

---

## Goals

Implement the daily review system with streak tracking to encourage consistent learning habits.

## Tasks

- [ ] Create DailyStreak schema and migration
- [ ] Create ReviewSchedule schema and migration (for SRS)
- [ ] Create DailyReview context functions
- [ ] Build Daily Review LiveView (test interface)
- [ ] Update Dashboard to show streak and daily goal
- [ ] Write comprehensive tests

## Technical Plan

### Schemas

**DailyStreak** - Track consecutive study days:
- `user_id` (references users)
- `current_streak` (integer)
- `longest_streak` (integer)
- `last_study_date` (date)
- `timezone` (string, for proper day boundaries)

**ReviewSchedule** - SRS scheduling for reviews:
- `user_id` (references users)
- `user_progress_id` (references user_progress)
- `next_review_at` (datetime)
- `interval` (integer, days)
- `ease_factor` (float, SM-2 algorithm)

### DailyReview Context Functions

- `get_daily_review_words(user_id, count)` - Get words due for review + new words
- `record_review(user_id, word_id, result)` - Update mastery and schedule next review
- `get_user_streak(user_id)` - Get current streak info
- `update_streak(user_id)` - Update streak after daily review completion
- `get_study_stats(user_id)` - Stats for dashboard

### LiveViews

**DailyReviewLive** (`/daily-review`) - Daily test interface:
- Shows words due for review
- Multiple choice questions
- Immediate feedback
- Progress through daily goal
- Streak celebration on completion

### Dashboard Updates

- Show current streak with flame icon
- Show daily goal progress (X/Y words reviewed today)
- "Start Daily Review" button
- Weekly activity heatmap (optional)

## Definition of Done

- [ ] All migrations run successfully
- [ ] Daily review generation works
- [ ] Streak tracking functional
- [ ] SRS scheduling implemented
- [ ] Dashboard shows streak and daily goal
- [ ] All 214+ tests passing
- [ ] `mix precommit` passes
- [ ] Code reviewed and approved

---

**Ready to begin Iteration 6.**
