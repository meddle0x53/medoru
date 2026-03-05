# Iteration 1: OAuth & Accounts

**Status**: ✅ APPROVED  
**Date**: 2026-03-05  
**Reviewed By**: meddle  
**Approved**: YES

---

## Summary

Iteration 1 is complete and approved. The OAuth authentication system and user account management are fully implemented and tested.

## What Was Implemented

### 1. Dependencies
- Added `ueberauth` (~> 0.10) and `ueberauth_google` (~> 0.12) to `mix.exs`

### 2. Schemas Created
- **`Medoru.Accounts.User`** - OAuth user data (email, provider, provider_uid, name, avatar_url)
- **`Medoru.Accounts.UserProfile`** - Display name, avatar, timezone, daily_goal, theme
- **`Medoru.Accounts.UserStats`** - Aggregate stats (kanji learned, words learned, streaks, XP, level, duels)

### 3. Context Module
- **`Medoru.Accounts`** - Full CRUD for users, profiles, stats
- **`register_user_with_oauth/1`** - Creates user + profile + stats in transaction
- **`get_user_by_email/1`**, **`get_user_by_provider_uid/2`** - Lookup functions
- **`update_profile/2`**, **`update_settings/2`** - Profile management
- **`add_xp/2`** - XP/Level system with formula: `level = floor(sqrt(xp / 100)) + 1`

### 4. Migrations
- `20260305184410_create_users.exs` - Users table with unique constraints
- `20260305184415_create_user_profiles.exs` - Profile table
- `20260305184416_create_user_stats.exs` - Stats table

### 5. Authentication System
- **`MedoruWeb.UserAuth`** - Plug module with:
  - `fetch_current_user/2` - Loads user from session
  - `require_authenticated_user/2` - Redirects if not logged in
  - `on_mount/4` callbacks for LiveView authentication
- **`MedoruWeb.AuthController`** - OAuth callback handler and logout

### 6. LiveViews & Routes
- **`MedoruWeb.DashboardLive`** - Authenticated dashboard with:
  - Welcome message with display name
  - Stats cards (streak, XP, level, kanji learned)
  - Quick action cards (Daily Review, Continue Learning)
- **`MedoruWeb.PageController`** (updated) - Landing page with Google sign-in

### 7. Layout Updates
- **`MedoruWeb.Layouts.app/1`** - Header with:
  - Medoru branding
  - Login/Logout buttons
  - User avatar and name when authenticated

### 8. Configuration
- `config/config.exs` - Ueberauth provider config
- `config/runtime.exs` - Google OAuth credentials from env vars
- `config/dev.exs` & `config/test.exs` - Unix socket, peer auth for PostgreSQL

### 9. Tests
- **`test/medoru/accounts_test.exs`** - 31 tests for all context functions
- **`test/support/fixtures/accounts_fixtures.ex`** - Test helpers

### 10. Routes
- `/auth/:provider` - OAuth request
- `/auth/:provider/callback` - OAuth callback
- `/auth/logout` - Logout (DELETE)
- `/dashboard` - Authenticated dashboard
- `/lessons` - Placeholder (redirects to dashboard)
- `/daily-review` - Placeholder (redirects to dashboard)

---

## Test Results

```
Running ExUnit with seed: 423898, max_cases: 64
.................................
Finished in 0.4 seconds (0.1s async, 0.2s sync)
31 tests, 0 failures
```

## Code Quality

- `mix precommit` passes (compile --warnings-as-errors, format, test)
- Zero compiler warnings
- All tests passing

---

## Database Status

- ✅ Database `medoru_dev` created
- ✅ All 3 migrations applied
- ✅ PostgreSQL using Unix socket with peer authentication
- ✅ User `meddle` has SUPERUSER/CREATEDB privileges

---

## Key Decisions

1. **Using Ueberauth** - Standard, well-maintained OAuth library
2. **Provider UID uniqueness** - Composite unique index on (provider, provider_uid)
3. **Transaction for registration** - User + Profile + Stats created atomically
4. **XP Level formula** - Simple sqrt-based progression
5. **Binary UUIDs** - Using `:binary_id` for all primary keys (Phoenix 1.8 standard)
6. **Unix socket + peer auth** - No passwords needed for local development

---

## Files Created/Modified

### New Files (12):
- `lib/medoru/accounts.ex`
- `lib/medoru/accounts/user.ex`
- `lib/medoru/accounts/user_profile.ex`
- `lib/medoru/accounts/user_stats.ex`
- `lib/medoru_web/user_auth.ex`
- `lib/medoru_web/controllers/auth_controller.ex`
- `lib/medoru_web/live/dashboard_live.ex`
- `priv/repo/migrations/20260305184410_create_users.exs`
- `priv/repo/migrations/20260305184415_create_user_profiles.exs`
- `priv/repo/migrations/20260305184416_create_user_stats.exs`
- `test/medoru/accounts_test.exs`
- `test/support/fixtures/accounts_fixtures.ex`

### Modified Files (9):
- `mix.exs`
- `config/config.exs`
- `config/runtime.exs`
- `config/dev.exs`
- `config/test.exs`
- `lib/medoru_web/router.ex`
- `lib/medoru_web/components/layouts.ex`
- `lib/medoru_web/controllers/page_html/home.html.heex`
- `test/medoru_web/controllers/page_controller_test.exs`

---

## Current State (For Next Instance)

- **Last completed**: Iteration 1 - OAuth & Accounts (APPROVED)
- **Next**: Iteration 2 - Kanji & Readings
- **Database**: Ready (migrated, test user can be created)
- **OAuth**: Configured for local dev with Google
- **Server**: Can run with `mix phx.server`

---

## Next Steps (Iteration 2)

**Iteration 2: Kanji & Readings**
- Create Kanji schema with stroke data (JSONB)
- Create KanjiReading schema (on/kun readings)
- Seed N5-N4 kanji data (~80 N5 + ~170 N4 characters)
- Build Content context with `list_kanji_by_level/1`
- Build kanji browse UI (list by JLPT level)
- Build kanji detail view

---

## Developer Notes

### To Test OAuth Locally:
1. Set env vars:
   ```bash
   export GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
   export GOOGLE_CLIENT_SECRET="your-client-secret"
   ```
2. Add your email as test user in Google Cloud Console
3. Run: `mix phx.server`
4. Visit: http://localhost:4000

### To Create Test User (without OAuth):
```elixir
alias Medoru.Accounts
{:ok, user} = Accounts.register_user_with_oauth(%{
  email: "test@example.com",
  provider: "google",
  provider_uid: "test123",
  name: "Test User"
})
```

---

**This iteration is COMPLETE and APPROVED. Do not modify unless explicitly requested.**
