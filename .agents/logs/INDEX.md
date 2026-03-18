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
| 16 | Auto-Generated Daily Tests | ✅ APPROVED | 2026-03-09 |
| 17 | Vocabulary Lesson System | ✅ COMPLETED | 2026-03-08 |
| 13 | Admin Badge Management | ⏳ BACKLOGGED | Post v0.1.0 |
| 15 | Teacher Test Creation | ✅ APPROVED | 2026-03-15 |
| 18 | Classroom Core | ✅ APPROVED | 2026-03-11 |
| 19 | Classroom Membership | ✅ APPROVED | 2026-03-11 |
| 20 | Classroom Tests, Lessons & Rankings | ✅ COMPLETED | 2026-03-11 |
| 21 | Admin Dashboard | ✅ COMPLETED | 2026-03-16 |
| 24A | i18n UI (Bulgarian/Japanese) | ✅ APPROVED | 2026-03-15 |
| 24B | i18n Content Translation | ✅ APPROVED | 2026-03-18 |
| 32 | UI Polish & Mobile Responsiveness | ✅ APPROVED | 2026-03-18 |
| 33 | Deployment & Production Setup | ⏳ PLANNED | 🔴 HIGH | - |

## Future Ideas (Backlog - Post v0.1.0)
- Mobile app (React Native/Flutter)
- AI-powered pronunciation feedback
- Community-created lessons
- JLPT practice exams
- Offline mode
- Dark mode UI
- API for third-party integrations

## Current State
- **Version**: 0.1.0 (MVP Extended)
- **Phase**: Iteration 32 APPROVED - Ready for 33 (Deployment)
- **Last completed**: Iteration 32 - UI Polish & Mobile
- **Current**: ⏳ 1 PENDING iteration for v0.1.0
- **Overall Progress**: 29/30 iterations for v0.1.0 (1 remaining + 1 backlogged)

## ⏳ Pending Work for v0.1.0
1. **🔴 HIGH**: Iteration 33 - Deployment & Production Setup (medoru.net)

## 🗂️ Backlog (Post v0.1.0)
- **🟡 MEDIUM**: Iteration 13 - Admin Badge Management

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

### ⏳ Pending (Iterations 32, 33) - MVP Extended
- UI Polish & Mobile (32) 🔴 HIGH
- Deployment & Production Setup (33) 🔴 HIGH

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
4. **Ask meddle** which iteration to work on (currently: Iteration 33 - Deployment)
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

**Last updated**: 2026-03-18  
**Status**: Iteration 32 APPROVED
**Tests**: 468 passing
