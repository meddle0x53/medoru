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
| 10 | Badge System | ✅ APPROVED | 2026-03-07 |
| 11 | Logging Infrastructure | ✅ APPROVED | 2026-03-08 |
| 12 | Kanji Stroke Animation | ✅ APPROVED | 2026-03-08 |
| 14 | Multi-Step Test System | ✅ APPROVED | 2026-03-08 |
| 16 | Auto-Generated Daily Tests | ✅ COMPLETED | 2026-03-09 |
| 17 | Vocabulary Lesson System | ✅ COMPLETED | 2026-03-08 |
| 14 | Multi-Step Test System | ✅ APPROVED | 2026-03-08 |
| 16 | Auto-Generated Daily Tests | ✅ COMPLETED | 2026-03-09 |
| 17 | Vocabulary Lesson System | ✅ COMPLETED | 2026-03-08 |
| 13 | Admin Badge Management | ⏳ PLANNED | - |
| 15 | Teacher Test Creation | ⏳ PLANNED | - |
| 16 | Daily Tests | ⏳ PLANNED | - |
| 17 | Vocabulary Lesson System | ⏳ PLANNED | - |
| 18 | Classroom Core | ⏳ PLANNED | - |
| 19 | Classroom Membership | ⏳ PLANNED | - |
| 20 | Classroom Tests, Lessons & Rankings | ⏳ PLANNED | - |
| 21 | Admin Dashboard | ⏳ PLANNED | - |

## Version 0.2.0 (Social Features) - Planned

| # | Title | Status | Date |
|---|-------|--------|------|
| 22 | Friends System | ⏳ PLANNED | - |
| 23 | Real-time Duels | ⏳ PLANNED | - |
| 24 | Rankings & Leaderboards | ⏳ PLANNED | - |
| 25 | Duel History & Stats | ⏳ PLANNED | - |
| 26 | Notifications System | ⏳ PLANNED | - |

## Version 0.3.0 (Content Expansion) - Planned

| # | Title | Status | Date |
|---|-------|--------|------|
| 27 | N4 Kanji & Words | ⏳ PLANNED | - |
| 28 | Grammar Content | ⏳ PLANNED | - |
| 29 | Listening Exercises | ⏳ PLANNED | - |
| 30 | Stroke Drawing | ⏳ PLANNED | - |

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
- **Phase**: Iteration 16 COMPLETE - Ready for Iteration 13+
- **Last completed**: Iteration 16 - Auto-Generated Daily Tests
- **Current**: ⏳ 6 PENDING iterations ([see PENDING.md](./PENDING.md))
- **Overall Progress**: 15/21 iterations for v0.1.0 (6 remaining)

## ⏳ Pending Work (Priority Order)
1. **🔴 HIGH**: Iteration 14 - Multi-Step Test System
2. **🔴 HIGH**: Iteration 16 - Auto-Generated Daily Tests  
3. **🟡 MEDIUM**: Iteration 17 - Vocabulary Lesson System
4. **🟡 MEDIUM**: Iteration 13 - Admin Badge Management
5. **🟢 LOWER**: Iterations 15, 18-21 - Classroom System

See [PENDING.md](./PENDING.md) for detailed breakdown.

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

### ✅ Completed (Iterations 8-10)
- User types (student/teacher/admin)
- Admin authorization plugs
- Admin user management interface
- Mix task for first admin
- Enhanced profiles (display name, bio, avatar)
- Profile settings page
- Public profile pages
- Badge system (13 badges, auto-award, featured badge, notifications)

### ✅ Completed (Iteration 11)
- Structured logging with `Medoru.Logger`
- Environment-specific configuration (dev/test/prod)
- JSON formatting for production
- File backend with rotation (10MB per file, keep 5)
- Request logging plug with metadata (request_id, user_id, IP, duration)
- Audit logging for security events
- Logrotate configuration for system-level rotation
- Documentation in LOGGING.md

### ✅ Completed (Iteration 16)
- Daily Test Generator with SRS integration
- `/daily-test` LiveView for taking daily tests
- `/daily-test/complete` completion screen
- Streak updates on test completion
- Review items + new words mix (up to 5 new)
- One test per user per day

### ⏳ Pending (Iterations 13, 15, 18-21) - MVP Extended
- Admin badge management (13)
- Teacher test creation (15)
- Classroom system (18-20)
- Admin dashboard (21)

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
4. **Ask meddle** which iteration to work on (currently: Iteration 11 - Logging Infrastructure)
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

**Last updated**: 2026-03-07  
**Status**: Iteration 10 COMPLETE - Iteration 11 PLANNED
