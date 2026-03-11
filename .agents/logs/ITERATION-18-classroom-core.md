# Iteration 18: Classroom Core

**Status**: COMPLETED ✅  
**Date**: 2026-03-11  
**Reviewed By**: User  
**Approved**: YES

## What Was Implemented

### Schemas & Migrations
- **Classroom schema** (`lib/medoru/classrooms/classroom.ex`)
  - Fields: name, slug, description, invite_code, status (active/archived/closed), settings
  - Auto-generates slug from name
  - Auto-generates 8-character invite code
  - Belongs to teacher (User)
  - Has many memberships and students

- **ClassroomMembership schema** (`lib/medoru/classrooms/classroom_membership.ex`)
  - Fields: status (pending/approved/rejected/left/removed), role (student/assistant), joined_at, points, settings
  - Belongs to classroom and user
  - Helper changesets for approve/reject/remove/leave actions

- **Migrations**:
  - `20260311085827_create_classrooms.exs`
  - `20260311085840_create_classroom_memberships.exs`

### Classrooms Context (`lib/medoru/classrooms.ex`)
Full CRUD operations for classroom management:

**Classroom Management:**
- `list_teacher_classrooms/1` - List active classrooms for a teacher
- `list_student_classrooms/1` - List approved classrooms for a student
- `get_classroom!/1`, `get_classroom_by_slug/1`, `get_classroom_by_invite_code/1`
- `create_classroom/1`, `update_classroom/2`, `archive_classroom/1`, `close_classroom/1`
- `regenerate_invite_code/1`

**Membership Management:**
- `apply_to_join/2` - Student applies to join classroom
- `approve_membership/1`, `reject_membership/1` - Teacher approval workflow
- `remove_member/1` - Teacher removes student
- `leave_classroom/1` - Student leaves voluntarily
- `is_member?/2`, `is_approved_member?/2` - Membership checks
- `list_classroom_members/1`, `list_pending_memberships/1`
- `update_member_points/2`, `add_member_points/2`
- `get_classroom_stats/1` - Statistics (total members, pending, points)

### Teacher LiveViews

**Index** (`lib/medoru_web/live/teacher/classroom_live/index.ex`)
- Lists all teacher's classrooms in a card grid
- Shows member count, creation date, status badge
- Empty state with CTA for new teachers
- "Create Classroom" button

**New** (`lib/medoru_web/live/teacher/classroom_live/new.ex`)
- Form to create new classroom
- Fields: name, slug (optional), description
- Auto-generates slug from name if not provided
- Tips section for best practices

**Show** (`lib/medoru_web/live/teacher/classroom_live/show.ex`)
- Main classroom management interface
- **Tabs:** Overview, Students, Lessons, Tests, Settings
- **Overview tab:**
  - Invite code display with regenerate button
  - Quick links to Students and Rankings
- **Students tab:**
  - Pending applications section (if any)
  - Approved members list with points
  - Approve/Reject/Remove actions
- Stats cards showing members, pending apps, total points

### Routes
Added teacher scope in router:
```elixir
scope "/teacher", MedoruWeb.Teacher do
  live "/classrooms", ClassroomLive.Index
  live "/classrooms/new", ClassroomLive.New
  live "/classrooms/:id", ClassroomLive.Show
end
```

### Tests
- **31 tests** in `test/medoru/classrooms_test.exs`
- Full coverage of context functions
- Tests for classroom CRUD, membership workflow, statistics

## Schema Changes

### classrooms table
```elixir
id :binary_id
name :string (not null)
slug :string (not null, unique)
description :text
invite_code :string (not null, unique)
status :string (default: "active")
settings :map
teacher_id :references users (not null)
timestamps
```

### classroom_memberships table
```elixir
id :binary_id
status :string (default: "pending")
role :string (default: "student")
joined_at :utc_datetime
points :integer (default: 0)
settings :map
classroom_id :references classrooms (not null)
user_id :references users (not null)
timestamps
```

Indexes:
- `classrooms_slug_index` (unique)
- `classrooms_invite_code_index` (unique)
- `classroom_memberships_classroom_id_user_id_index` (unique)

## Known Issues / TODOs

- Lessons and Tests tabs show "Coming Soon" - to be implemented in Iteration 20
- No email notifications yet (only in-app notifications)
- No classroom lesson assignments yet
- No classroom rankings/leaderboards yet (depends on Iteration 20)

## Next Steps

**Iteration 19: Classroom Membership & Applications**
- Student interface to join classrooms by invite code
- Student "My Classrooms" page
- Notifications for membership events (application submitted, approved, rejected)

## Technical Notes

- Invite codes are auto-generated as 8-character uppercase alphanumeric strings
- Slugs are auto-generated from classroom names (lowercase, hyphenated)
- Both invite codes and slugs have uniqueness checks
- Membership status flow: pending → approved|rejected, or approved → removed|left
- Preloading strategy: teacher and memberships preloaded for show page

## Test Results

```
389 tests, 0 failures
```

All tests pass including 31 new tests for the Classrooms context.
