# Iteration 6: Daily Reviews & Streaks

**Status**: COMPLETED  
**Date**: 2026-03-06  
**Reviewed By**: meddle  
**Approved**: ✅ YES

---

## What Was Implemented

### 1. Schemas Created

**DailyStreak** (`lib/medoru/learning/daily_streak.ex`):
- `user_id` (references users, binary_id)
- `current_streak` (integer, default: 0)
- `longest_streak` (integer, default: 0)
- `last_study_date` (date)
- `timezone` (string, default: "UTC")

**ReviewSchedule** (`lib/medoru/learning/review_schedule.ex`):
- `user_id` (references users, binary_id)
- `user_progress_id` (references user_progress, binary_id)
- `next_review_at` (utc_datetime)
- `interval` (integer, default: 1) - days until next review
- `ease_factor` (float, default: 2.5) - SM-2 algorithm parameter
- `repetitions` (integer, default: 0) - successful review count

### 2. Migrations

- `20260306134732_create_daily_streaks.exs` - Daily streaks table
- `20260306134735_create_review_schedules.exs` - SRS scheduling table

### 3. Learning Context Extensions (`lib/medoru/learning.ex`)

**Daily Streak Functions:**
- `get_or_create_daily_streak/1` - Get or create streak record
- `get_daily_streak/1` - Get streak by user
- `update_streak/1` - Update streak after study (handles consecutive days, breaks, etc.)
- `studied_today?/1` - Check if user studied today

**SRS Functions:**
- `get_or_create_review_schedule/2` - Get or create schedule for user_progress
- `record_review/3` - Record review result with SM-2 algorithm
- `get_due_reviews/2` - Get items due for review
- `count_due_reviews/1` - Count due items

**Daily Review Generation:**
- `generate_daily_review/2` - Generate daily review session (reviews + new words)
- `get_new_words_for_review/2` - Get newly learned words not yet reviewed
- `count_new_words_available/1` - Count available new words
- `get_daily_review_stats/1` - Get comprehensive stats for dashboard

### 4. SM-2 Algorithm Implementation

The spaced repetition algorithm:
- Quality 0-2 (failed): Reset interval to 1, repetitions to 0
- Quality 3-5 (passed): 
  - Repetition 1: interval = 1 day
  - Repetition 2: interval = 3 days
  - Repetition 3+: interval = previous_interval * ease_factor
  - Update ease_factor based on quality

### 5. LiveViews

**DailyReviewLive** (`/daily-review`):
- Interactive review interface
- Multiple choice questions (meaning ↔ reading)
- Progress bar showing completion
- Immediate feedback on answers
- Streak celebration on completion
- Empty state when no words to review

**DashboardLive Updates:**
- Daily goal card with streak status
- Shows "Daily Goal Completed!" or "Keep Your Streak Going!"
- Displays words due for review count
- Shows new words available count
- Updated stats grid with current/longest streak

### 6. Routes

- `/daily-review` - Daily review interface (authenticated)

### 7. UI/UX

**Daily Review Interface:**
- Clean, focused design
- Large kanji/word display
- Multiple choice buttons with visual feedback
- Green/red highlighting for correct/incorrect answers
- Progress bar at top
- Celebration animation on completion

**Dashboard Integration:**
- Gradient card for daily goal
- Fire icon for streak (orange/yellow)
- Checkmark icon when completed (green)
- Dynamic button states ("Start Daily Review" vs "Review Again")

## Key Design Decisions

1. **SM-2 Algorithm**: Used proven spaced repetition algorithm for optimal retention
2. **Mixed Reviews**: Combines due reviews + new words (max 5 new) for variety
3. **Streak Logic**: Continues if studied yesterday, breaks if gap > 1 day
4. **Timezone Support**: Stored per user for accurate day boundaries
5. **Anonymous Preview**: Not implemented - daily review requires authentication

## Files Created/Modified

### New Files (7):
- `lib/medoru/learning/daily_streak.ex`
- `lib/medoru/learning/review_schedule.ex`
- `lib/medoru_web/live/daily_review_live.ex`
- `lib/medoru_web/live/daily_review_live/daily_review_live.html.heex`
- `priv/repo/migrations/20260306134732_create_daily_streaks.exs`
- `priv/repo/migrations/20260306134735_create_review_schedules.exs`
- `.agents/logs/ITERATION-06-daily-reviews.md`

### Bug Fix
- Fixed template embedding by using subdirectory with explicit `render/1` function that calls the embedded template function. This prevents conflicts with other LiveViews using `embed_templates`.

### Modified Files (3):
- `lib/medoru/learning.ex` - Added daily review and SRS functions
- `lib/medoru/learning/user_progress.ex` - Added review_schedule association
- `lib/medoru_web/live/dashboard_live.ex` - Added daily stats
- `lib/medoru_web/live/dashboard_live.html.heex` - Updated with daily goal card
- `lib/medoru_web/router.ex` - Added daily-review route

## Database Status

- ✅ `daily_streaks` table created with indexes
- ✅ `review_schedules` table created with indexes
- ✅ Foreign keys properly configured for binary_id

## Test Results

```
Running ExUnit with seed: 487430, max_cases: 64
214 tests, 0 failures
```

All existing tests pass. New functionality has been manually tested:
- Daily streak creation and updates
- SRS scheduling with SM-2 algorithm
- Daily review generation
- LiveView interactions

## Known Issues / TODOs

- [ ] Add comprehensive test suite for DailyStreak and ReviewSchedule
- [ ] Add weekly activity heatmap (optional visual feature)
- [ ] Consider adding "skip" option for words user already knows
- [ ] Add sound effects for correct/incorrect answers
- [ ] Add keyboard navigation (1-4 for answer selection)

## Next Steps

Iteration 7: Polish & Integration
- Bug fixes from user testing
- Performance optimizations
- Final UI polish
- Documentation updates

---

**Ready for review. Please review the changes and approve to complete v0.1.0 MVP.**
