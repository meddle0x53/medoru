# ⏳ Pending Iterations - Phase 1 (v0.1.0 MVP)

**Last Updated**: 2026-03-08  
**Completed**: 12/21 iterations  
**Remaining**: 9 iterations

---

## 🔴 HIGH PRIORITY (Core Learning Loop)

### Iteration 14: Multi-Step Test System Architecture
**Status**: ⏳ NOT STARTED | **Estimated**: 3-4 days  
**Files to Create**:
- `lib/medoru/tests/test.ex` - Schema
- `lib/medoru/tests/test_step.ex` - Schema  
- `lib/medoru/tests/test_session.ex` - Schema
- `lib/medoru/tests/test_step_answer.ex` - Schema
- `lib/medoru/tests.ex` - Context
- `priv/repo/migrations/*_create_tests.exs`
- `priv/repo/migrations/*_create_test_steps.exs`
- `priv/repo/migrations/*_create_test_sessions.exs`
- `test/medoru/tests_test.exs`

**Key Features**:
- Test schema with steps (reading/writing/listening/grammar/speaking)
- Sub-types: multichoice (1pt), fill (2pt)
- TestSession tracks progress step-by-step
- Step answers with time tracking

---

### Iteration 16: Auto-Generated Daily Tests  
**Status**: ⏳ NOT STARTED | **Estimated**: 2-3 days  
**Depends On**: Iteration 14
**Files to Create/Modify**:
- `lib/medoru/learning/daily_test_generator.ex` - Service module
- `lib/medoru_web/live/daily_test_live.ex` - Main LiveView
- Update `lib/medoru/learning.ex` - Add daily test functions

**Key Features**:
- SRS-based review items + new words (up to 5)
- Mix multichoice and fill questions
- One daily test per user per day
- Completing updates streak

---

## 🟡 MEDIUM PRIORITY (Content Expansion)

### Iteration 17: Vocabulary Lesson System (Partially Complete)
**Status**: 🟡 IN PROGRESS | **Estimated**: 2-3 days remaining  
**Files Created**:
- ✅ `lib/mix/tasks/medoru.generate_lessons.ex` - System lesson generation
- ✅ `LESSON_GENERATION.md` - Documentation

**Completed**:
- ✅ System lessons auto-generated from existing words
- ✅ 36,451 lessons created (145,803 word links)
- ✅ 3-5 words per lesson (4.0 avg)
- ✅ Ordered by frequency (most common first)
- ✅ Grouped by JLPT level (N5, N4, N3+)

**Remaining**:
- ⏳ Teacher custom lesson builder UI
- ⏳ Lesson completion tracking
- ⏳ Test integration at end of lessons
- ⏳ Progress tracking per user
- ⏳ Prerequisites (complete N5 before N4)

**Usage**:
```bash
mix medoru.generate_lessons  # Generate all system lessons
```

---

### Iteration 13: Admin Badge Management
**Status**: ⏳ NOT STARTED | **Estimated**: 1-2 days  
**Files to Create**:
- `lib/medoru_web/live/admin/badge_live/index.ex`
- `lib/medoru_web/live/admin/badge_live/edit.ex`
- Update `lib/medoru/gamification.ex` - Add admin functions

**Key Features**:
- CRUD for badges in admin panel
- Manual badge award to users
- Badge statistics view

---

## 🟢 LOWER PRIORITY (Classroom System)

### Iteration 18: Classroom Core
**Status**: ⏳ NOT STARTED | **Estimated**: 2-3 days  
**Depends On**: User types (✅ done)
**Files to Create**:
- `lib/medoru/classrooms/classroom.ex` - Schema
- `lib/medoru/classrooms/classroom_membership.ex` - Schema
- `lib/medoru/classrooms.ex` - Context
- `lib/medoru_web/live/teacher/classroom_live/index.ex`
- `lib/medoru_web/live/teacher/classroom_live/show.ex`
- `lib/medoru_web/live/teacher/classroom_live/new.ex`
- `priv/repo/migrations/*_create_classrooms.exs`
- `priv/repo/migrations/*_create_classroom_memberships.exs`
- `test/medoru/classrooms_test.exs`

**Key Features**:
- Create classrooms (name, slug, invite code)
- Teacher management interface
- Tabs: Overview, Students, Lessons, Tests, Settings

---

### Iteration 19: Classroom Membership & Applications
**Status**: ⏳ NOT STARTED | **Estimated**: 2-3 days  
**Depends On**: Iteration 18, Notifications (✅ done)
**Files to Create**:
- `lib/medoru_web/live/classroom_live/join.ex` - Student join page
- `lib/medoru_web/live/classroom_live/index.ex` - Student's classrooms
- `lib/medoru_web/live/teacher/classroom_live/applications.ex`
- Update `lib/medoru/notifications.ex` - Membership notifications

**Key Features**:
- Join by invite code
- Application workflow (pending → approved/rejected)
- Teacher approval interface
- Kick/remove students
- Notifications for membership events

---

### Iteration 20: Classroom Tests, Lessons & Rankings
**Status**: ⏳ NOT STARTED | **Estimated**: 3-4 days  
**Depends On**: Iterations 14, 17, 18, 19
**Files to Create**:
- `lib/medoru/classrooms/classroom_test_attempt.ex` - Schema
- `lib/medoru/classrooms/classroom_lesson_progress.ex` - Schema
- `lib/medoru_web/live/classroom_live/rankings.ex`
- `lib/medoru_web/live/teacher/classroom_live/analytics.ex`
- Update `lib/medoru_web/components/classroom_components.ex`

**Key Features**:
- Classroom-specific test attempts
- Points system (tests + lessons)
- Leaderboards (overall, per-test, per-lesson)
- Teacher analytics dashboard

---

### Iteration 15: Teacher Test Creation Interface
**Status**: ⏳ NOT STARTED | **Estimated**: 3-4 days  
**Depends On**: Iteration 14, User types (✅ done)
**Files to Create**:
- `lib/medoru_web/live/teacher/test_builder_live/index.ex` - List teacher tests
- `lib/medoru_web/live/teacher/test_builder_live/new.ex` - Create test
- `lib/medoru_web/live/teacher/test_builder_live/edit.ex` - Edit test steps
- `lib/medoru_web/live/teacher/test_builder_live/preview.ex` - Preview test
- `lib/medoru_web/components/test_builder_components.ex`

**Key Features**:
- Test builder workflow: created → ready → published
- Step builder with kanji/word search
- Drag-drop step reordering
- Test preview mode

---

### Iteration 21: Admin Dashboard & System Management
**Status**: ⏳ NOT STARTED | **Estimated**: 2-3 days  
**Depends On**: All above
**Files to Create**:
- `lib/medoru_web/live/admin/dashboard_live.ex` - Main admin dashboard
- `lib/medoru_web/live/admin/content_live/kanji.ex`
- `lib/medoru_web/live/admin/content_live/words.ex`
- `lib/medoru_web/live/admin/content_live/lessons.ex`
- `lib/medoru_web/live/admin/classrooms_live.ex`
- `lib/medoru_web/live/admin/settings_live.ex`

**Key Features**:
- System stats (users, content, activity)
- Content CRUD (kanji, words, lessons)
- Badge management
- Classroom oversight
- System settings

---

## 📊 Summary

| Priority | Iterations | Total Days |
|----------|------------|------------|
| 🔴 High | 14, 16 | 5-7 days |
| 🟡 Medium | 13, 17 | 4-6 days |
| 🟢 Lower | 15, 18, 19, 20, 21 | 12-17 days |
| **Total** | **9** | **21-30 days** |

---

## 🎯 Recommended Order

1. **Iteration 14** (Multi-Step Test) - Foundation for tests
2. **Iteration 16** (Daily Tests) - Uses test system
3. **Iteration 17** (Vocabulary Lessons) - Expand content
4. **Iteration 13** (Admin Badge Management) - Quick win
5. **Iteration 15** (Teacher Test Creation) - Teacher features
6. **Iteration 18** (Classroom Core) - Classroom foundation
7. **Iteration 19** (Classroom Membership) - Student joining
8. **Iteration 20** (Classroom Tests/Rankings) - Full classroom
9. **Iteration 21** (Admin Dashboard) - Admin polish

---

## 📁 Quick Links

- Full Plan: [ITERATION-PLAN-v0.1.0.md](./ITERATION-PLAN-v0.1.0.md)
- Roadmap: [ROADMAP.md](./ROADMAP.md)
- Main Index: [INDEX.md](./INDEX.md)
- Project Skills: [../skills/medoru/SKILL.md](../skills/medoru/SKILL.md)
