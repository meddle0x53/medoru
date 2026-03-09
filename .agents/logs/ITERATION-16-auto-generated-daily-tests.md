# Iteration 16: Auto-Generated Daily Tests

**Status**: COMPLETED  
**Date**: 2026-03-09  
**Reviewed By**: meddle  
**Approved**: PENDING

## What Was Implemented

### Core Features
- **Daily Test Generation**: Auto-generated daily tests that combine SRS-based review items with new words
- **One Test Per Day**: Users get only one daily test per day, persisted across sessions
- **Streak Integration**: Completing daily tests updates the user's streak automatically
- **Review + New Words Mix**: Tests include due reviews (SRS-based) plus up to 5 new words

### Files Created

#### Backend
- `lib/medoru/learning/daily_test_generator.ex` - Core service module
  - `get_or_create_daily_test/1` - Gets existing test for today or creates new one
  - `generate_daily_test/1` - Generates fresh daily test from due reviews + new words
  - `daily_test_completed_today?/1` - Checks if user completed daily test
  - `get_todays_daily_test/1` - Retrieves today's test if exists
  - `archive_old_daily_tests/1` - Archives previous day's tests

#### Frontend
- `lib/medoru_web/live/daily_test_live.ex` - Main test-taking LiveView
- `lib/medoru_web/live/daily_test_live/daily_test_live.html.heex` - Test UI template
- `lib/medoru_web/live/daily_test_live/complete.ex` - Completion screen LiveView

#### Tests
- `test/medoru/learning/daily_test_generator_test.exs` - Unit tests for generator

### Files Modified
- `lib/medoru/learning.ex` - Added daily test functions
  - `get_or_create_daily_test/1`
  - `daily_test_completed_today?/1`
  - `get_todays_daily_test/1`
  - `get_daily_test_status/1`
- `lib/medoru_web/router.ex` - Added daily test routes
- `lib/medoru_web/live/dashboard_live.html.heex` - Updated links to use `/daily-test`

### Routes Added
- `GET /daily-test` - Daily test interface
- `GET /daily-test/complete` - Completion screen

## Key Decisions

### Test Content Strategy
Daily tests include:
1. **Review Items**: Words due for SRS review (based on `next_review_at`)
2. **New Words**: Mix of:
   - Words user learned but hasn't scheduled for review yet
   - Completely new words not yet in UserProgress

### Test Format
- 2 questions per word (meaning → reading, reading → meaning)
- Multiple choice format with 4 options
- Points: 1 point per question
- Test steps created using existing `Tests.create_test_steps/2`

### Streak Tracking
- Streak updates automatically when test session is completed
- Uses existing `Learning.update_streak/1` function
- Completion tracked via `TestSession.status = :completed`

## Schema Notes
- Daily tests use `test_type: :daily` 
- `creator_id` links to user who owns the test
- Tests archived after the day ends (new day = new test)

## Test Results
- All 333 tests passing
- New tests: 11 for DailyTestGenerator
- Precommit checks: PASS

## Known Issues / TODOs
- Test fixtures sometimes cause unique constraint violations (pre-existing issue)
- Could add more comprehensive LiveView tests for daily test flow
- Future: Add difficulty adaptation based on user performance

## Next Steps
- Iteration 13: Admin Badge Management (medium priority)
- Iteration 15: Teacher Test Creation (lower priority)
- Iteration 18+: Classroom system

## Usage Example

```elixir
# Get or create today's daily test
{:ok, test} = Learning.get_or_create_daily_test(user.id)

# Check if completed today
Learning.daily_test_completed_today?(user.id)

# Get full status
Learning.get_daily_test_status(user.id)
# => %{
#   has_test: true,
#   completed: false,
#   test_id: "...",
#   due_count: 5,
#   new_available: 3,
#   total_items: 16
# }
```
