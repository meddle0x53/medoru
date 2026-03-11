# Iteration 15A: Test Management Core

**Status**: COMPLETED ✅  
**Date**: 2026-03-11  
**Reviewed By**: User  
**Approved**: YES

## What Was Implemented

### Database Changes

**Tests Table Updates** (`tests` table):
- Added `setup_state` field (string): `"in_progress" | "ready" | "published" | "archived"`
- Added `max_attempts` field (integer, nullable): Limit student attempts
- Time limit already existed but now configurable for teacher tests
- Added indexes: `[:creator_id, :setup_state]`, `[:setup_state]`

**Migration**: `20260311151118_add_setup_state_to_tests.exs`

### Schema Updates

**Test Schema** (`lib/medoru/tests/test.ex`):
- Added `@setup_states` constant
- Added `setup_state` field with default `"in_progress"`
- Added `max_attempts` field
- Added `teacher_create_changeset/2` for creating teacher tests
- Added `setup_state_changeset/2` for state transitions
- Added `mark_ready_changeset/1`, `publish_teacher_changeset/1`, `archive_teacher_changeset/1`

### Context Functions (Tests)

**Teacher Test Management** (`lib/medoru/tests.ex`):
- `list_teacher_tests/2` - List tests with optional state filter
- `create_teacher_test/2` - Create a new teacher test
- `is_test_owner?/2` - Check if user owns a test
- `transition_test_state/2` - Generic state transition
- `mark_test_ready/1` - Mark test as ready
- `publish_teacher_test/1` - Publish test
- `archive_teacher_test/1` - Archive test
- `count_test_steps/1` - Count steps in a test

### LiveViews Created

**Teacher Tests List** (`/teacher/tests`)
- File: `lib/medoru_web/live/teacher/test_live/index.ex`
- Features:
  - Filter by setup_state: all, in_progress, ready, published, archived
  - Test cards showing: title, description, step count, time limit, max attempts
  - State badges with colors
  - Action buttons based on state (Edit, Review, View Results, etc.)
  - Archive functionality

**Create Test** (`/teacher/tests/new`)
- File: `lib/medoru_web/live/teacher/test_live/new.ex`
- Features:
  - Test title (required)
  - Description (optional)
  - Time limit dropdown (1 min - 2 hours, optional)
  - Max attempts dropdown (1-10, optional)
  - Validation with debounce
  - Creates test in "in_progress" state

**Test Show/Overview** (`/teacher/tests/:id`)
- File: `lib/medoru_web/live/teacher/test_live/show.ex`
- Features:
  - Test details and stats
  - State progress visualization (step-by-step workflow)
  - State transition buttons (Mark Ready, Publish, Archive, Republish)
  - Danger zone for archiving
  - Step count preview

**Test Edit (Placeholder)** (`/teacher/tests/:id/edit`)
- File: `lib/medoru_web/live/teacher/test_live/edit.ex`
- Placeholder for Iteration 15B (Step Builder)
- Only accessible for "in_progress" tests
- Shows current step count

### Routes Added

```elixir
# Teacher routes
live "/tests", TestLive.Index
live "/tests/new", TestLive.New
live "/tests/:id", TestLive.Show
live "/tests/:id/edit", TestLive.Edit
```

## Navigation

Added "My Tests" link in the main navigation bar (visible to teachers and admins):
- Location: Top navbar, next to "Classrooms"
- Icon: `hero-clipboard-document-list`
- Visible only for users with type `"teacher"` or `"admin"`

### Test States Workflow

```
┌─────────────┐     Add steps      ┌────────┐     Publish      ┌───────────┐
│ in_progress │ ──────────────────▶ │ ready  │ ───────────────▶ │ published │
└─────────────┘                     └────────┘                  └───────────┘
       │                                                    │           │
       │                                                    │           │
       ▼                                                    ▼           │
  [Edit Mode]                                           [Live]          │
                                                   (students can         │
                                                    take test)          │
                                                                       │
                                                                       ▼
                                                                 ┌───────────┐
                                                                 │ archived  │
                                                                 └───────────┘
                                                                  (hidden from
                                                                   students)
```

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `lib/medoru/tests/test.ex` | +40 | Schema updates for setup_state, max_attempts |
| `priv/repo/migrations/*_add_setup_state_to_tests.exs` | 18 | Database migration |
| `lib/medoru/tests.ex` | +120 | Teacher test management functions |
| `lib/medoru_web/live/teacher/test_live/index.ex` | 300 | Tests list page |
| `lib/medoru_web/live/teacher/test_live/new.ex` | 180 | Create test form |
| `lib/medoru_web/live/teacher/test_live/show.ex` | 450 | Test overview page |
| `lib/medoru_web/live/teacher/test_live/edit.ex` | 80 | Edit placeholder |

## Files Modified

| File | Changes |
|------|---------|
| `lib/medoru_web/router.ex` | +6 lines - Added teacher test routes |
| `lib/medoru_web/components/layouts.ex` | +7 lines - Added "My Tests" nav link |
| `lib/medoru/tests/test.ex` | +10 lines - Fixed max_attempts validation |
| `test/medoru/tests_test.exs` | +20 lines - Added max_attempts tests |

## Key Features

✅ **Test Lifecycle**: in_progress → ready → published → archived  
✅ **Time Limits**: Configurable 1 min - 2 hours  
✅ **Attempt Limits**: 1-10 or unlimited  
✅ **Ownership**: Only creators can manage their tests  
✅ **State Visualization**: Clear progress indicators  
✅ **Filtering**: Filter tests by state on list page  

## Bug Fixes

### max_attempts Validation Bug
**Issue**: `validate_number/3` doesn't support `:allow_nil` option, causing crashes when max_attempts was nil.

**Fix**: Replaced with custom `maybe_validate_max_attempts/1` function that:
- Allows `nil` values (unlimited attempts)
- Validates range 1-10 when value is present
- Uses pattern matching instead of `:allow_nil`

**Test Coverage**: Added 3 tests for max_attempts validation:
- `create_test/1 with nil max_attempts is valid`
- `create_test/1 with valid max_attempts is valid`
- `create_test/1 with invalid max_attempts returns error`

## Test Results

```
400 tests, 0 failures
```

All tests pass including existing tests functionality.

## Next Steps

**Iteration 15B: Step Builder Framework**
- Add/remove/reorder steps
- Step type selector
- Step list with drag-drop reordering
- Empty step placeholders

## Screenshots/Flow

```
Teacher Flow:
/teacher/tests (list) → /teacher/tests/new (create) → /teacher/tests/:id (overview)
                                          ↓
                              /teacher/tests/:id/edit (steps - placeholder)
```

## UI Screens

**List Page** (`/teacher/tests`):
- Filter buttons: All | In Progress | Ready | Published | Archived
- Grid of test cards with state badges
- Quick action buttons based on state

**Create Page** (`/teacher/tests/new`):
- Clean form with title, description
- Time limit and max attempts dropdowns
- Info box explaining next steps

**Show Page** (`/teacher/tests/:id`):
- Header with state badge and actions
- Stats cards: Steps, Time Limit, Max Attempts
- Workflow progress visualization
- Sidebar with state info and actions
