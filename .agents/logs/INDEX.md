# Medoru Development Logs

## Version 0.1.0 (MVP) - Current

| # | Title | Status | Date |
|---|-------|--------|------|
| 1 | OAuth & Accounts | ✅ APPROVED | 2026-03-05 |
| 2 | Kanji & Readings | ✅ APPROVED | 2026-03-05 |
| 3 | Words with Reading Links | ✅ APPROVED | 2026-03-06 |
| 4 | Lessons | ✅ APPROVED | 2026-03-06 |
| 5 | Learning Core | ✅ APPROVED | 2026-03-06 |
| 6 | Daily Reviews & Streaks | ✅ APPROVED | 2026-03-06 |
| 7 | Polish & Integration | ✅ APPROVED | 2026-03-07 |
| 8 | User Types & Admin Foundation | ✅ APPROVED | 2026-03-07 |
| 9 | Enhanced Profiles | ✅ APPROVED | 2026-03-07 |
| 10 | Badge System | ⏳ PLANNED | - |
| 11 | Multi-Step Test System | ⏳ PLANNED | - |
| 12 | Teacher Test Creation | ⏳ PLANNED | - |
| 13 | Daily Tests | ⏳ PLANNED | - |
| 14 | Vocabulary Lesson System | ⏳ PLANNED | - |
| 15 | Kanji Stroke Animation | ⏳ PLANNED | - |
| 16 | Classroom Core | ⏳ PLANNED | - |
| 17 | Classroom Membership | ⏳ PLANNED | - |
| 18 | Classroom Tests, Lessons & Rankings | ⏳ PLANNED | - |
| 19 | Admin Dashboard | ⏳ PLANNED | - |

## Version 0.2.0 (Social Features) - Planned

| # | Title | Status | Date |
|---|-------|--------|------|
| 20 | Friends System | ⏳ PLANNED | - |
| 21 | Real-time Duels | ⏳ PLANNED | - |
| 22 | Rankings & Leaderboards | ⏳ PLANNED | - |
| 23 | Duel History & Stats | ⏳ PLANNED | - |
| 24 | Notifications | ⏳ PLANNED | - |

## Version 0.3.0 (Content Expansion) - Planned

| # | Title | Status | Date |
|---|-------|--------|------|
| 25 | N4 Kanji & Words | ⏳ PLANNED | - |
| 26 | Grammar Content | ⏳ PLANNED | - |
| 27 | Listening Exercises | ⏳ PLANNED | - |
| 28 | Stroke Drawing | ⏳ PLANNED | - |

## Future Ideas (Backlog)
- Mobile app (React Native/Flutter)
- AI-powered pronunciation feedback
- Community-created lessons
- JLPT practice exams
- Offline mode
- Dark mode UI
- API for third-party integrations

## Current State
- **Version**: 0.1.0 (MVP Extended)
- **Phase**: Iteration 10 IN PROGRESS
- **Last completed**: Iteration 9 - Enhanced Profiles (APPROVED)
- **Current**: Iteration 10 - Badge System
- **Overall Progress**: 7/19 iterations for v0.1.0 (12 remaining)

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

### ✅ Completed (Iterations 1-7) - Core MVP
- OAuth & Accounts ✅
- Kanji & Readings ✅
- Words with Reading Links ✅
- Lessons ✅
- Learning Core ✅
- Daily Reviews & Streaks ✅
- Polish & Integration ✅

### ✅ Completed (Iterations 8-9)
- User types (student/teacher/admin)
- Admin authorization plugs
- Admin user management interface
- Mix task for first admin
- Enhanced profiles (display name, bio, avatar)
- Profile settings page
- Public profile pages

### ⏳ Pending (Iterations 10-19) - MVP Extended
- Badge system (10)
- Test system overhaul (11-13)
- Vocabulary lessons (14)
- Kanji stroke animation (15)
- Classroom system (16-18)
- Admin dashboard (19)

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
2. **Check the latest ITERATION-XX-*.md** for detailed implementation notes
3. **Verify database is running** before starting work
4. **Ask meddle** which iteration to work on (currently: Iteration 10 - Badge System)
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

**Last updated**: 2026-03-06  
**Status**: Iteration 8 IN PROGRESS
