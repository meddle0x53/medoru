# Medoru Development Logs

## Iterations
| # | Title | Status | Date |
|---|-------|--------|------|
| 1 | OAuth & Accounts | ✅ APPROVED | 2026-03-05 |
| 2 | Kanji & Readings | ✅ APPROVED | 2026-03-05 |
| 3 | Words with Reading Links | 🔄 IN PROGRESS | 2026-03-05 |
| 4 | Lessons | ⏳ PENDING | - |
| 5 | Learning Core | ⏳ PENDING | - |
| 6 | Daily Reviews & Streaks | ⏳ PENDING | - |
| 7 | Polish & Integration | ⏳ PENDING | - |

## Current State
- **Phase**: Iteration 3 IN PROGRESS
- **Last completed**: Iteration 2 - Kanji & Readings
- **Current**: Iteration 3 - Words with Reading Links

## Project Status

### ✅ Completed (Iteration 1)
- Google OAuth authentication
- User, Profile, Stats schemas
- Accounts context with full CRUD
- Dashboard LiveView with stats display
- Auth plugs and LiveView on_mount callbacks
- 31 tests, all passing
- Database migrated and functional
- Local dev server running

### ✅ Completed (Iteration 2)
**Kanji & Readings**
- Kanji schema (character, meanings, stroke_count, jlpt_level, stroke_data JSONB)
- KanjiReading schema (reading_type, reading, romaji, usage_notes)
- Content context with full CRUD
- 30 N5 kanji seeded with readings
- Browse UI (filter by JLPT level N1-N5)
- Kanji detail view with readings display
- Navigation links and dashboard integration
- 45 new tests, all passing (76 total)

### ✅ Completed (Iteration 2)
- Kanji & Readings system
- 76 tests passing
- Approved by meddle

### ⏳ Pending (Iterations 3-7)
- Words with Reading Links
- Lessons
- Learning progress & tests
- Daily reviews & streaks
- Polish & integration

### ⏳ Pending (Iterations 3-7)
- Words with reading links
- Lessons system
- Learning progress & tests
- Daily reviews & streaks
- Polish & integration

## Environment

### Database
- **Name**: `medoru_dev`
- **Host**: Unix socket (`/var/run/postgresql`)
- **Auth**: Peer authentication (user `meddle`)
- **Status**: Migrated, functional

### OAuth (Dev)
- **Mode**: Testing (Google Cloud Console)
- **Provider**: Google
- **Callback**: `http://localhost:4000/auth/google/callback`
- **Status**: Configured, working locally

### Server
- **Command**: `mix phx.server`
- **URL**: http://localhost:4000
- **Status**: Running, functional

## Quick Commands

```bash
# Run server
mix phx.server

# Run tests
mix test

# Check code quality
mix precommit

# Database operations
mix ecto.create
mix ecto.migrate
mix ecto.reset
```

## Notes for Next Instance

1. **Always read this INDEX first** to understand current state
2. **Check ITERATION-02-kanji-readings.md** for detailed implementation notes
3. **Verify database is running** before starting work
4. **Ask meddle** which iteration to work on (currently: Iteration 3)
5. **Follow the workflow** from `.agents/skills/medoru-workflow/SKILL.md`

## Important Files

| File | Purpose |
|------|---------|
| `.agents/logs/ITERATION-01-oauth-accounts.md` | Complete details on Iteration 1 |
| `.agents/skills/medoru/SKILL.md` | Technical conventions |
| `.agents/skills/medoru-workflow/SKILL.md` | Development workflow |
| `lib/medoru/accounts.ex` | Accounts context |
| `lib/medoru_web/user_auth.ex` | Authentication |

---

**Last updated**: 2026-03-05  
**Status**: Iteration 3 IN PROGRESS
