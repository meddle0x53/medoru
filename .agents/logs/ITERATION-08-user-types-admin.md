# Iteration 8: User Types & Admin Foundation

**Status**: COMPLETED  
**Date**: 2026-03-07  
**Reviewed By**: meddle  
**Approved**: YES

## Goals

1. Add user type field (student/teacher/admin) to users
2. Create authorization system for admin-only and teacher+admin access
3. Build admin interface for managing users
4. Create mix task for bootstrapping first admin

## What Was Implemented

### Schema Changes
- Migration `add_user_type_to_users` - PostgreSQL enum type with student/teacher/admin
- Index on `type` for efficient querying
- Default value: `"student"`

### New Files
- `lib/medoru_web/plugs/admin_plug.ex` - Admin authorization plug and on_mount hook
- `lib/medoru_web/plugs/teacher_plug.ex` - Teacher+admin authorization plug and on_mount hook
- `lib/medoru_web/live/admin/user_live/index.ex` - Admin user list with filtering/pagination
- `lib/medoru_web/live/admin/user_live/index/index.html.heex` - User list template
- `lib/medoru_web/live/admin/user_live/edit.ex` - Edit user type
- `lib/medoru_web/live/admin/user_live/edit/edit.html.heex` - Edit user template
- `lib/mix/tasks/medoru/make_admin.ex` - Mix task for making first admin
- `test/medoru/accounts/user_type_test.exs` - Tests for user type functionality

### Modified Files
- `lib/medoru/accounts/user.ex` - Added type field, type_changeset, and helper functions (admin?, teacher?, student?)
- `lib/medoru/accounts.ex` - Added admin user management functions (list_users_for_admin, update_user_type, get_user_for_admin!)
- `lib/medoru_web/router.ex` - Added admin routes with authorization

## Features Delivered

1. **User Types**
   - `:student` (default) - Can learn, take tests, join classrooms
   - `:teacher` - Can create classrooms, lessons, and tests
   - `:admin` - Full system access, can manage users

2. **Authorization**
   - `MedoruWeb.Plugs.Admin` - Requires admin access
   - `MedoruWeb.Plugs.Teacher` - Requires teacher or admin access
   - Both provide `on_mount` hooks for LiveViews

3. **Admin Interface**
   - `/admin/users` - List all users with pagination
   - Filter by type (all/students/teachers/admins)
   - Search by email or name
   - `/admin/users/:id/edit` - Change user type with visual role cards

4. **Mix Task**
   - `mix medoru.make_admin user@example.com` - Promote user to admin

## Schema Changes

```elixir
# Migration: 20260307163344_add_user_type_to_users.exs
execute "CREATE TYPE user_type AS ENUM ('student', 'teacher', 'admin')"

alter table(:users) do
  add :type, :user_type, null: false, default: "student"
end

create index(:users, [:type])
```

## LiveViews/Routes Added

```elixir
scope "/admin", MedoruWeb.Admin do
  pipe_through [:browser, :require_authenticated_user]

  live_session :admin,
    on_mount: [
      {MedoruWeb.UserAuth, :require_authenticated_user},
      {MedoruWeb.Plugs.Admin, :default}
    ] do
    live "/users", UserLive.Index
    live "/users/:id/edit", UserLive.Edit
  end
end
```

## Test Results

- 225 tests passing (11 new tests added)
- All existing tests continue to pass

## Definition of Done
- [x] Migration created and run
- [x] User schema updated with type field
- [x] Authorization modules working
- [x] Admin LiveViews functional
- [x] Mix task for first admin
- [x] Tests passing

## Next Steps

**Iteration 9: Enhanced Profiles**
- Display name uniqueness
- Avatar upload
- Bio field
- Profile settings page
- Public profile pages
