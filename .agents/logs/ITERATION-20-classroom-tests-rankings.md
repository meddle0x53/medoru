# Iteration 20: Classroom Tests, Lessons & Rankings

**Status**: COMPLETED ✅  
**Date**: 2026-03-11  
**Reviewed By**: -  
**Approved**: -

## What Was Implemented

### Database Schema

**Classroom Test Attempts** (`classroom_test_attempts` table)
- Tracks timed test attempts within classrooms
- Supports auto-submission when timer expires
- Points can go negative during test, minimum final score is 0
- Time remaining used as tie-breaker for rankings
- Reset functionality for teachers to allow retakes

**Classroom Lesson Progress** (`classroom_lesson_progress` table)
- Tracks lesson completion within classroom context
- Records points earned from lesson tests
- Status tracking: not_started → in_progress → completed

### Context Functions (Classrooms)

**Test Attempt Management:**
- `can_take_test?/3` - Check if user can take a test
- `start_test_attempt/4` - Begin a new timed test
- `update_test_progress/2` - Update score/time during attempt
- `complete_test_attempt/2` - Finish test and award points
- `auto_submit_test/3` - Auto-submit when time expires
- `reset_test_attempt/2` - Teacher reset for retakes
- `get_test_attempt/3` - Get specific attempt
- `list_classroom_test_attempts/2` - List attempts for classroom

**Lesson Progress:**
- `get_or_create_lesson_progress/3` - Get or initialize progress
- `start_lesson/3` - Mark lesson as started
- `complete_lesson/5` - Complete lesson with test results
- `list_user_lesson_progress/2` - User's lesson progress

**Rankings & Leaderboards:**
- `get_classroom_leaderboard/2` - Overall rankings by points
- `get_test_leaderboard/3` - Per-test rankings (points + time tie-breaker)
- `get_user_classroom_rank/2` - User's position in classroom
- `get_user_test_rank/3` - User's position for specific test

**Teacher Analytics:**
- `get_classroom_analytics/1` - Comprehensive analytics bundle
- `get_test_completion_stats/1` - Test attempt statistics
- `get_lesson_completion_stats/1` - Lesson progress statistics
- `get_recent_activity/2` - Activity over time (for charts)

### LiveViews

**Student Rankings Page** (`/classrooms/:id/rankings`)
- Overall classroom leaderboard with top 50 students
- Per-test rankings with time-based tie-breaking
- Personal stats card showing rank and points
- Tab navigation between overall and test rankings
- Visual rank indicators (🥇🥈🥉 for top 3)

**Teacher Analytics Dashboard** (`/teacher/classrooms/:id/analytics`)
- Stats overview cards (students, attempts, completions, avg score)
- Test performance breakdown
- Lesson progress statistics
- Top performers list
- Recent activity feed (last 30 days)
- Recent test attempts with status indicators

### Routes Added

```elixir
# Student rankings
live "/:id/rankings", ClassroomLive.Rankings

# Teacher analytics
live "/classrooms/:id/analytics", ClassroomLive.Analytics
```

### Navigation Updates

- Student classroom show page: "Full Rankings" link in rankings tab
- Teacher classroom show page: "Analytics" button in header

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `lib/medoru/classrooms/classroom_test_attempt.ex` | 180 | Test attempt schema with timed test support |
| `lib/medoru/classrooms/classroom_lesson_progress.ex` | 95 | Lesson progress schema |
| `priv/repo/migrations/*_create_classroom_test_attempts.exs` | 50 | Test attempts migration |
| `priv/repo/migrations/*_create_classroom_lesson_progress.exs` | 40 | Lesson progress migration |
| `lib/medoru_web/live/classroom_live/rankings.ex` | 395 | Student rankings page |
| `lib/medoru_web/live/teacher/classroom_live/analytics.ex` | 443 | Teacher analytics dashboard |

## Files Modified

| File | Changes |
|------|---------|
| `lib/medoru/classrooms.ex` | +400 lines - Test/lesson/ranking functions |
| `lib/medoru/tests.ex` | +15 lines - Batch test step fetch |
| `lib/medoru/tests/lesson_test_session.ex` | +10 lines - Use batch fetch |
| `lib/medoru_web/live/classroom_live/show.ex` | +5 lines - Rankings link |
| `lib/medoru_web/live/teacher/classroom_live/show.ex` | +5 lines - Analytics link |
| `lib/medoru_web/router.ex` | +2 lines - New routes |

## Key Features

### Timed Tests with Auto-Submission
- Tests have configurable time limits
- Timer visible to students during test
- Auto-submission when time expires
- Unanswered steps don't add or remove points

### Scoring System
- Correct answers add points (based on step type)
- Wrong answers subtract points (based on step type)
- Minimum final score: 0 (negative scores clamped)
- Time remaining used as tie-breaker

### Rankings
- **Overall**: Ranked by total points
- **Per-test**: Ranked by score, then time remaining
- Visual medals for top 3 positions
- Personal rank highlighting

### Teacher Analytics
- Completion rates and averages
- Activity tracking over time
- Top performer identification
- Recent attempt monitoring

## Technical Notes

### Ranking Score Calculation
```elixir
# Points are primary, time is tie-breaker
ranking_score = points + (time_remaining / time_limit) * 0.01
```

### Database Indexes
- Composite indexes for leaderboard queries
- Unique constraint on (classroom_id, test_id, user_id) with reset handling
- Indexed status fields for filtering

## Test Results

```
397 tests, 0 failures
```

All tests pass including existing classroom functionality.

## Next Steps

**Iteration 15: Teacher Test Creation Interface**
- Test builder UI for teachers
- Step creation with kanji/word search
- Drag-drop reordering
- Preview mode

**Iteration 13: Admin Badge Management**
- Badge CRUD in admin panel
- Manual badge awarding
- Badge statistics

## Screenshots/Flow

```
Student Flow:
/classrooms/:id → Click "Rankings" tab → Click "Full Rankings" → /classrooms/:id/rankings

Teacher Flow:
/teacher/classrooms/:id → Click "Analytics" → /teacher/classrooms/:id/analytics
```
