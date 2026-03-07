# Iteration 9: Enhanced Profiles

**Status**: COMPLETED  
**Date**: 2026-03-07  
**Reviewed By**: meddle  
**Approved**: YES

## Goals

1. Unique display name validation
2. Avatar upload with file storage
3. Bio field for user profiles
4. Profile settings page (`/settings/profile`)
5. Public profile pages (`/users/:id` or `/u/:display_name`)
6. Update header to show display name instead of email

## What Was Implemented

### Schema Changes
- Migration `add_bio_to_user_profiles` - Added bio field and unique index on display_name
- Unique constraint allows NULLs (users without display names)
- Display name format validation (letters, numbers, spaces, underscores, hyphens)

### New Files
- `lib/medoru_web/live/settings_live/profile.ex` - Profile settings LiveView
- `lib/medoru_web/live/settings_live/profile/profile.html.heex` - Profile settings template
- `lib/medoru_web/live/user_live/show.ex` - Public profile LiveView
- `lib/medoru_web/live/user_live/show/profile_page.html.heex` - Public profile template
- `test/medoru_web/live/settings_live_test.exs` - Profile settings tests

### Modified Files
- `lib/medoru/accounts/user_profile.ex` - Added bio field, unique display_name constraint, format validation
- `lib/medoru/accounts.ex` - Added `get_user_by_display_name/1`, `get_user_with_profile!/1`
- `lib/medoru_web/components/layouts.ex` - Added user dropdown menu with Profile and Settings links
- `lib/medoru_web/router.ex` - Added routes for settings and public profiles

## Features Delivered

1. **Unique Display Names**
   - Format validation: letters, numbers, spaces, underscores, hyphens
   - Unique constraint at database level (partial index for non-NULL values)
   - Maximum 50 characters

2. **Bio Field**
   - Text field up to 500 characters
   - Optional (can be blank)
   - Displayed on public profile

3. **Avatar Upload**
   - LiveView file upload with drag-and-drop
   - Accepts JPG, PNG, GIF up to 2MB
   - Stored locally in `priv/static/uploads/avatars/`
   - Shows preview before upload
   - Current avatar displayed if exists

4. **Profile Settings Page** (`/settings/profile`)
   - Edit display name with live validation
   - Edit bio with character counter
   - Avatar upload with progress bar
   - Form validation errors displayed inline

5. **Public Profile Page** (`/users/:id`)
   - Shows avatar, display name, bio
   - User type badge (Admin/Teacher/Student)
   - Stats: level, streak, kanji learned, words learned
   - Member since date
   - Learning stats section

6. **Header Updates**
   - User dropdown menu with avatar and name
   - Links to: My Profile, Settings
   - Sign out option
   - Admin link for admin users (in main nav)

## Schema Changes

```elixir
# Migration: 20260307180532_add_bio_to_user_profiles.exs
alter table(:user_profiles) do
  add :bio, :text
end

execute "CREATE UNIQUE INDEX user_profiles_display_name_index 
         ON user_profiles (display_name) 
         WHERE display_name IS NOT NULL"
```

## LiveViews/Routes Added

```elixir
# Settings
live "/settings/profile", SettingsLive.Profile

# Public profiles
live "/users/:id", UserLive.Show
```

## Test Results

- 229 tests passing (4 new tests added)
- All existing tests continue to pass

## Known Issues / TODOs

- Avatar upload currently stores files locally
- For production, should use S3 or similar cloud storage
- Display name in header still uses `user.name` - could be updated to use profile display_name

## Next Steps

**Iteration 10: Badge System**
- Badge/achievement schema
- Auto-award badges on actions
- Featured badge on profile

---

**Definition of Done**
- [x] Display name is unique and validated
- [x] Avatar upload works (local storage for now)
- [x] Bio field added and editable
- [x] Profile settings page functional
- [x] Public profile page shows user info
- [x] Header shows user menu with profile/settings links
- [x] Tests passing
