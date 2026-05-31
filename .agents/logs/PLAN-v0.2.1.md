# Medoru v0.2.1 Release Plan — Activity Stream

## Overview
Minor release adding a social activity stream to the dashboard, showing followed users' learning achievements.

**Estimated Duration**: 1-2 weeks
**Depends On**: v0.2.0 completion
**Theme**: Social Discovery & Engagement

---

## Feature: Following Activity Stream

### User Story
As a learner, when I open my dashboard, I want to see what the people I follow have been up to — so I feel motivated and connected to the community.

### Event Types

| Event | Source Table/Hook | Visibility |
|---|---|---|
| **Badge earned** | `user_badges` | Public |
| **Level up** | `xp_transactions` (inferred) | Public |
| **Lesson completed** | `classroom_lesson_progress` | Public classroom only |
| **Test completed** | `test_sessions` + classroom tests | Public classroom only |
| **Streak milestone** | `daily_streak` (longest updated) | Public |

### Technical Design

#### Option A: Query Existing Tables (Simpler)
- Union query across `user_badges`, `classroom_lesson_progress` (public), `test_sessions` (public classrooms), `xp_transactions`, `daily_streak`
- Filter by `user_id IN (SELECT following_id FROM follows WHERE follower_id = current_user)`
- Order by timestamp, paginate 5 at a time
- **Pros**: No new table
- **Cons**: Complex query, hard to filter level-ups and streak changes (no history)

#### Option B: Activity Events Table (Recommended)
- New table `activity_events`:
  ```elixir
  create table(:activity_events, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :user_id, references(:users, type: :binary_id), null: false
    add :event_type, :string, null: false  # "badge_earned", "level_up", "lesson_completed", "test_completed", "streak_milestone"
    add :data, :map, default: %{}  # event-specific payload
    add :happened_at, :utc_datetime, null: false
    timestamps(type: :utc_datetime)
  end
  ```
- Hooks write events as they happen:
  - `Gamification.award_badge` → `badge_earned`
  - `Accounts.add_xp` (when `leveled_up`) → `level_up`
  - `Classrooms.complete_lesson` / `complete_custom_lesson` (public only) → `lesson_completed`
  - `Tests.complete_session` (public classroom tests only) → `test_completed`
  - `Learning.update_streak` (when `longest_streak` increases) → `streak_milestone`
- Query: simple `WHERE user_id IN (followed_ids) ORDER BY happened_at DESC LIMIT 5 OFFSET n`
- **Pros**: Clean, fast, extensible
- **Cons**: Requires migration + schema + hooks

### UI Design

**Dashboard section** below stats grid:
```
┌─────────────────────────────────────────────────────┐
│  Following Activity                    [Load more]  │
│                                                     │
│  🎉 Alice earned "Kanji Master"         2h ago      │
│  🆙 Bob reached Level 5                  3h ago      │
│  📚 Carol completed "Grammar 101"        5h ago      │
│  🏆 Dave scored 95% on N5 Test           1d ago      │
│  🔥 Eve hit a 14-day streak              2d ago      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Empty state**: "Follow users to see their learning journey here!"

### Implementation Tasks

- [ ] Migration: `create_activity_events`
- [ ] Schema: `ActivityEvent` with changeset
- [ ] Context: `Social.create_activity_event/1`, `Social.list_following_activity/2`
- [ ] Hooks: Insert events in `award_badge`, `add_xp`, `complete_lesson`, `complete_session`, `update_streak`
- [ ] Dashboard: New section in `DashboardLive` with event list + "Load more"
- [ ] i18n: All stream labels
- [ ] Tests: Context tests + LiveView tests

---

## Deferred from v0.2.0
This feature was deferred from v0.2.0 to keep the release focused on core social/XP infrastructure.
