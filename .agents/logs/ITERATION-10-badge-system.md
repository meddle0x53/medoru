# Iteration 10: Badge System

**Status**: APPROVED  
**Date**: 2026-03-07  
**Reviewed By**: meddle  
**Approved**: YES

## What Was Implemented

### Schema Changes
- **Badge schema** (`lib/medoru/gamification/badge.ex`)
  - name, description, icon, color
  - criteria_type (enum: manual, streak, kanji_count, words_count, lessons_completed, daily_reviews)
  - criteria_value (threshold for auto-award)
  - order_index (for display ordering)

- **UserBadge schema** (`lib/medoru/gamification/user_badge.ex`)
  - Tracks which users have earned which badges
  - awarded_at timestamp
  - is_featured boolean
  - Proper foreign key types (user_id as UUID, badge_id as integer)

- **Migration**: `20260307183527_create_badges.exs`
- **Migration**: `20260307183538_create_user_badges.exs`
- **Migration**: `20260307183550_add_featured_badge_to_user_profiles.exs`

### Gamification Context
- **File**: `lib/medoru/gamification.ex`
- Badge CRUD operations
- User badge management
- Featured badge functionality
- Auto-award checking functions:
  - `check_streak_badges/2`
  - `check_kanji_badges/2`
  - `check_words_badges/2`
  - `check_lesson_badges/2`
  - `check_daily_reviews_badges/2`

### Auto-Award Hooks in Learning Context
- `complete_lesson/2` → awards lesson badges
- `track_kanji_learned/2` → awards kanji count badges
- `track_word_learned/2` → awards word count badges
- `update_streak/1` → awards streak badges

### Badge Seeds
- **File**: `priv/repo/seeds/badges.json`
- 13 initial badges:
  - First Steps (1 lesson)
  - Lesson Enthusiast (5 lessons)
  - Lesson Master (10 lessons)
  - Kanji Beginner (10 kanji)
  - Kanji Scholar (50 kanji)
  - Kanji Master (100 kanji)
  - Word Collector (25 words)
  - Word Hoarder (100 words)
  - Streak Starter (3-day streak)
  - Streak Keeper (7-day streak)
  - Streak Champion (30-day streak)
  - Daily Warrior (10 daily reviews)
  - Daily Devotee (50 daily reviews)

### LiveView Updates

#### Public Profile (`lib/medoru_web/live/user_live/show.ex`)
- Displays all earned badges in a grid
- Shows featured badge prominently with gradient background
- Badge color classes for Tailwind styling

#### Profile Settings (`lib/medoru_web/live/settings_live/profile.ex`)
- Badge selection UI to choose featured badge
- Remove featured badge option
- Displays all earned badges with click-to-select

### Accounts Context Updates
- Helper functions for badge management:
  - `get_user_badges/1`
  - `set_user_featured_badge/2`
  - `remove_user_featured_badge/1`
  - `get_user_featured_badge/1`
  - `award_badge_to_user/2`

### Tests
- **File**: `test/medoru/gamification_test.exs`
- 28 tests covering:
  - Badge CRUD
  - User badge operations
  - Featured badge functionality
  - Auto-award logic

## Files Created/Modified

### New Files
- `lib/medoru/gamification/badge.ex`
- `lib/medoru/gamification/user_badge.ex`
- `lib/medoru/gamification.ex`
- `priv/repo/seeds/badges.json`
- `test/medoru/gamification_test.exs`
- `priv/repo/migrations/20260307183527_create_badges.exs`
- `priv/repo/migrations/20260307183538_create_user_badges.exs`
- `priv/repo/migrations/20260307183550_add_featured_badge_to_user_profiles.exs`

### Modified Files
- `lib/medoru/accounts/user_profile.ex` - Added featured_badge relation
- `lib/medoru/accounts.ex` - Added badge helper functions
- `lib/medoru/learning.ex` - Added auto-award hooks
- `lib/medoru_web/live/user_live/show.ex` - Display badges
- `lib/medoru_web/live/user_live/show/profile_page.html.heex` - Badge display template
- `lib/medoru_web/live/settings_live/profile.ex` - Featured badge selection
- `lib/medoru_web/live/settings_live/profile/profile.html.heex` - Badge selection UI
- `priv/repo/seeds.exs` - Load badge seeds

## Test Results
- **257 tests passing** (28 new tests added)
- All existing tests continue to pass
- No compiler warnings

## Key Decisions

1. **Badge ID as integer**: Badges use default bigint IDs for simplicity and ordering
2. **UserBadge IDs as UUID**: Consistent with other user-related tables
3. **Auto-award on action completion**: Badges are checked/awarded immediately when criteria might be met
4. **Featured badge in user_badges table**: Rather than on profile, to keep it with badge data
5. **Multiple badges can be earned**: A 7-day streak earns both 3-day and 7-day badges

## Notification System (Added Enhancement)

When a badge is earned, users now receive a notification:

### Schema
- `notifications` table with type, title, message, read_at, data (JSONB)
- Types: `badge_earned`, `streak_milestone`, `lesson_complete`, `daily_reminder`

### UI Components
- **Header notification bell** with unread count badge
- **Notification dropdown** - shows 5 most recent unread notifications
- **Notifications page** (`/notifications`) - full list with filtering
- **Mark as read** - individual or mark all as read

### Auto-created Notifications
- Badge earned → "🎉 Badge Earned!" notification
- Can extend to streak milestones, lesson completion, daily reminders

### New Files
- `lib/medoru/notifications/notification.ex`
- `lib/medoru/notifications.ex`
- `lib/medoru_web/components/notification_dropdown.ex`
- `lib/medoru_web/live/notifications_live/notifications_live.ex`
- `lib/medoru_web/live/notifications_live/notifications_live.html.heex`
- `priv/repo/migrations/20260307184743_create_notifications.exs`
- `test/medoru/notifications_test.exs`

### Modified Files
- `lib/medoru/gamification.ex` - Creates notification when badge awarded
- `lib/medoru_web/user_auth.ex` - Loads unread count into scope
- `lib/medoru_web/components/layouts.ex` - Added notification bell dropdown
- `lib/medoru_web/router.ex` - Added `/notifications` route

## Known Issues / TODOs

- Daily reviews badge logic needs to be connected when daily review tracking is implemented
- Badge icons use Heroicons - custom icons could be added later
- Badge rarity/points system not implemented
- Toast/popup notifications not implemented (just the bell/badge system)

## Next Steps

**Iteration 11: Logging Infrastructure**
- Structured logging with JSON formatting
- Log rotation
- Replace IO.puts/inspect with proper Logger

**Iteration 12: Kanji Stroke Animation**
- SVG stroke data for kanji
- Animated stroke order visualization
- Practice drawing mode

---

**Definition of Done**
- [x] Badge schema created
- [x] UserBadge schema created
- [x] Gamification context with CRUD
- [x] 13 badges seeded
- [x] Auto-award hooks in Learning context
- [x] Featured badge functionality
- [x] Badge display on public profile
- [x] Badge selection in settings
- [x] Notification system for badge awards
- [x] Header notification bell with unread count
- [x] Notifications page with filtering
- [x] Tests passing (274 total)
