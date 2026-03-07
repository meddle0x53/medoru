# Iteration 11: Admin Badge Management

**Status**: PLANNED  
**Date**: 2026-03-07  
**Priority**: High

## Overview

Admin interface for managing badges - allowing administrators to create, edit, and delete badges dynamically without database seeds.

## Goals

1. **Badge CRUD for Admins**
   - List all badges with search/filter
   - Create new badges with form validation
   - Edit existing badges
   - Delete badges (with safety checks)

2. **Badge Preview**
   - Live preview of badge appearance
   - Icon selection from Heroicons
   - Color selection

3. **Badge Statistics (Optional)**
   - How many users have earned each badge
   - Award rate analytics

## User Stories

As an admin, I want to:
- View all badges in the system
- Create new achievement badges for users
- Modify badge details (name, description, criteria)
- Remove outdated badges
- Preview how badges will look

## Schema

Using existing `badges` table from Iteration 10:

```elixir
%Badge{
  name: string,           # unique, required
  description: string,    # required
  icon: string,           # Heroicon name, required
  color: string,          # blue|green|yellow|orange|red|purple|pink|indigo|emerald
  criteria_type: enum,    # manual|streak|kanji_count|words_count|lessons_completed|daily_reviews
  criteria_value: integer,# threshold for auto-award
  order_index: integer    # display ordering
}
```

## Pages/Routes

| Route | LiveView | Description |
|-------|----------|-------------|
| `/admin/badges` | `Admin.BadgeLive.Index` | List all badges with actions |
| `/admin/badges/new` | `Admin.BadgeLive.Form` | Create new badge |
| `/admin/badges/:id/edit` | `Admin.BadgeLive.Form` | Edit existing badge |

## UI Design

### Badge List Page
```
┌─────────────────────────────────────────────────────────────┐
│ Badges                                    [+ New Badge]    │
├─────────────────────────────────────────────────────────────┤
│ Search: [____________] Filter: [All ▼]                      │
├─────────────────────────────────────────────────────────────┤
│ ┌───────────────────────────────────────────────────────┐  │
│ │ 🏆 First Steps         [Edit] [Delete]                │  │
│ │     Complete your first lesson                        │  │
│ │     Criteria: 1 lesson completed • 234 users earned   │  │
│ └───────────────────────────────────────────────────────┘  │
│ ┌───────────────────────────────────────────────────────┐  │
│ │ 🔥 Streak Starter      [Edit] [Delete]                │  │
│ │     Maintain a 3-day learning streak                  │  │
│ │     Criteria: 3 day streak • 156 users earned         │  │
│ └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Badge Form
```
┌─────────────────────────────────────────────────────────────┐
│ New Badge                                                   │
├─────────────────────────────────────────────────────────────┤
│ Badge Name *                                                │
│ [________________________]                                  │
│                                                             │
│ Description *                                               │
│ [________________________]                                  │
│                                                             │
│ Icon *                                      Preview:        │
│ [🔍 search icons...    ▼]                   ┌──────┐       │
│                                             │ 🏆   │       │
│ Color                                       └──────┘       │
│ [● Blue ▼]                                                  │
│                                                             │
│ Criteria Type              Value                            │
│ [Lessons Completed ▼]      [____]                           │
│                                                             │
│ Order Index                                                 │
│ [____]                                                      │
│                                                             │
│                         [Cancel]  [Create Badge]           │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Tasks

### 1. Context Functions
- Add to `Gamification` context:
  - `list_badges/1` - with search/filter (already exists, may need enhancement)
  - `count_users_with_badge/1` - for statistics
  - `reorder_badges/1` - update order_index for multiple badges

### 2. LiveViews

**Index LiveView** (`lib/medoru_web/live/admin/badge_live/index.ex`)
- List badges with pagination
- Search by name
- Filter by criteria_type
- Delete with confirmation
- Quick reorder (drag & drop optional)

**Form LiveView** (`lib/medoru_web/live/admin/badge_live/form.ex`)
- Create/edit badge
- Form validation
- Live icon preview
- Color picker
- Icon search/selector

### 3. Components

**Badge Card Component**
- Shows badge icon, name, description
- Edit/Delete actions
- User count statistic
- Criteria summary

**Icon Selector Component**
- Search Heroicons
- Grid display
- Selected state
- Preview

### 4. Routes

```elixir
# In router.ex under admin scope
live "/badges", BadgeLive.Index
live "/badges/new", BadgeLive.Form, :new
live "/badges/:id/edit", BadgeLive.Form, :edit
```

## Validation Rules

- `name` - Required, unique, max 100 chars
- `description` - Required, max 500 chars
- `icon` - Required, must be valid Heroicon name
- `color` - Required, must be from allowed list
- `criteria_type` - Required
- `criteria_value` - Required if criteria_type != manual, positive integer
- `order_index` - Required, integer

## Safety Considerations

- **Delete confirmation**: Warn if users have earned the badge
- **Soft delete?**: Consider keeping badge records but hide from new awards
- **Audit log**: Track who created/modified badges (future enhancement)

## Dependencies

- Existing `Gamification` context (Iteration 10)
- Existing admin authentication (Iteration 8)
- Heroicons for icon selection

## Testing

### Unit Tests
- Context functions for badge management
- Validation rules
- Authorization (only admins)

### Integration Tests
- Create badge flow
- Edit badge flow
- Delete badge with confirmation
- Search/filter functionality

## Files to Create

```
lib/medoru_web/live/admin/badge_live/
├── index.ex
├── index.html.heex
├── form.ex
└── form.html.heex

test/medoru_web/live/admin/badge_live_test.exs
```

## Files to Modify

```
lib/medoru/gamification.ex (add stats functions)
lib/medoru_web/router.ex (add routes)
```

## Definition of Done

- [ ] Admin can list all badges
- [ ] Admin can search/filter badges
- [ ] Admin can create new badge
- [ ] Admin can edit existing badge
- [ ] Admin can delete badge (with confirmation)
- [ ] Form validation works correctly
- [ ] Icon selector with preview
- [ ] Only admin users can access
- [ ] Tests passing

## Next Steps After Completion

**Iteration 14: Multi-Step Test System**
- Overhaul test system
- Multi-step test flow
- Better question types
