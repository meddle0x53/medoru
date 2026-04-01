# Medoru Development Roadmap

This document outlines the long-term development plan for Medoru.

---

## Version 0.1.4 - Grammar Lessons ✅ COMPLETE

**Status**: ✅ COMPLETE | **Completed**: 2026-03-31  
**Log**: [ITERATION-GRAMMAR-STUDENT-TAKING.md](./ITERATION-GRAMMAR-STUDENT-TAKING.md)

**Goal:** Grammar lesson system with pattern validation and alternative forms

**Features:**
- ✅ Grammar lesson creation by teachers
- ✅ Pattern builder with word types and forms
- ✅ Sentence validation against grammar patterns
- ✅ Alternative forms support (contracted Japanese forms like 来ない→来な)
- ✅ ETS caching for 50x validation performance improvement
- ✅ Admin progress reset feature

---

## Version 0.1.2 - Small Improvements ✅ COMPLETE

**Status**: ✅ COMPLETE | **Completed**: 2026-03-20  
**Plan**: [PLAN-v0.1.2.md](./PLAN-v0.1.2.md)

**Goal:** Bug fixes and small UX improvements

**Features:**
- ✅ Daily test step type preferences (user-configurable)
- ✅ Fix daily tests showing unlearned words
- ✅ Public access to kanji/words for anonymous users
- ✅ Language switching for non-logged-in users
- ✅ Word picture uploads (admin)

---

## Version 0.1.0 - MVP ✅ COMPLETE

**Status**: ✅ Released 2026-03-18  
**Iterations**: 33 complete

**Goal:** Core learning platform with content, progress tracking, and classroom support

**Features (Iterations 1-7):**
- ✅ Google OAuth authentication
- ✅ Kanji database (N5) with readings
- ✅ Words with kanji/reading links
- ⏳ Lessons system (1-3 kanji per lesson)
- ⏳ User progress tracking
- ⏳ Daily review tests with SRS
- ⏳ Streak tracking

**Features (Iterations 8-12) ✅ COMPLETE:**
- ✅ User types (admin, teacher, student)
- ✅ Admin interface for user management
- ✅ Enhanced profiles (display name, avatar, badges)
- ✅ Badge/achievement system
- ✅ Kanji stroke animation
- ✅ Logging infrastructure

**Features (Iterations 13-21) ⏳ PENDING:**
- ⏳ Admin badge management
- ⏳ **Multi-step tests** (reading/writing/listening/grammar/speaking)
- ⏳ **Test sub-types**: multichoice (1pt) and fill (2pt)
- ⏳ Teacher-created tests with workflow
- ⏳ **Auto-generated daily tests**
- ⏳ **Vocabulary lessons** (3-5 words per lesson)
- ⏳ **Classroom system** (teachers, students, applications)
- ⏳ Classroom-specific tests and lessons
- ⏳ **Classroom rankings and leaderboards**
- ⏳ Full admin dashboard

**Next Priority**: See [PENDING.md](./PENDING.md)

**Status**: 
- Core MVP (Iterations 1-7) ✅ COMPLETE
- Extended MVP (Iterations 8-12) ✅ COMPLETE  
- **⏳ PENDING: 9 iterations remaining** (see [PENDING.md](./PENDING.md))

**Target Users:** Individual learners, classrooms, teachers

**Next Priority**: See [PENDING.md](./PENDING.md)

---

## Version 0.2.0 - Social & Games ⬅️ CURRENT

**Status**: 📝 Planning  
**Plan**: [PLAN-v0.2.0.md](./PLAN-v0.2.0.md)

**Goal:** Make learning social and competitive with real-time classroom games

**Features:**
- 🎮 **Games System** - Extensible game engine with memory cards (first game type)
- 💬 **Real-time Chat** - Classroom chat during games and general use
- 🏷️ **User Tags & Following** - Find users by interests, follow their progress
- 📊 **User Levels** - Level up based on activity (daily tests, games, lessons)
- 🏅 **Badge System Fixes** - Featured badges visible everywhere

**Game Types (Extensible Architecture):**
- Memory Cards (v0.2.0) - Team-based card matching with word challenges
- Quiz Battle (future)
- Kanji Race (future)
- Word Chain (future)

**Technical Changes:**
- Phoenix PubSub for real-time features
- Presence tracking
- Game type plugin system (behaviours)
- WebSocket channels for games and chat

**Target Users:** Competitive learners, classroom students, study groups

---

## Version 0.3.0 - Content Expansion

**Goal:** Expand learning materials and add advanced features

**Features:**
- N4 kanji and vocabulary
- Grammar lessons with explanations
- Listening exercises with audio
- Stroke drawing practice (Canvas API)
- User-created study decks

**Technical Changes:**
- Audio file storage (S3/local)
- Canvas-based drawing component
- Content management admin interface

**Target Users:** Serious learners preparing for JLPT

---

## How to Add New Iterations

### 1. Add to INDEX.md

Update the `.agents/logs/INDEX.md` with new iterations:

```markdown
## Version 0.4.0 (Mobile)

| # | Title | Status | Date |
|---|-------|--------|------|
| 17 | Mobile API | ⏳ PLANNED | - |
| 18 | React Native App | ⏳ PLANNED | - |
```

### 2. Create Iteration Log Template

When starting an iteration, create `.agents/logs/ITERATION-XX-title.md`:

```markdown
# Iteration X: Title

**Status**: IN_PROGRESS  
**Date**: YYYY-MM-DD  
**Reviewed By**: -  
**Approved**: NO

## Goals
- Feature 1
- Feature 2

## Technical Plan
- Schema changes
- API changes
- New dependencies

## Definition of Done
- [ ] All features implemented
- [ ] Tests passing
- [ ] Code reviewed
```

### 3. Update Current State

In `INDEX.md`, update the "Current State" section:

```markdown
## Current State
- **Version**: 0.2.0
- **Phase**: Iteration 8 IN PROGRESS
- **Last completed**: Iteration 7 - Polish & Integration (v0.1.0)
- **Current**: Iteration 8 - Friends System (v0.2.0)
```

---

## Version Release Process

When completing a version (e.g., v0.1.0):

1. Final iteration approved and merged
2. Create git tag: `git tag v0.1.0`
3. Update `mix.exs` version
4. Write release notes in `CHANGELOG.md`
5. Deploy to production
6. Update `INDEX.md` to mark version as released

---

## Changing Plans Mid-Development

To modify the roadmap:

1. **Edit INDEX.md** - Update the iteration table
2. **Create a new iteration log** - If adding a new iteration
3. **Update ROADMAP.md** - Document the change and reasoning
4. **Notify** - Mention the change in your next message to me

Example:
> "Let's add an iteration 7.5 for dark mode between 7 and 8"

---

## Backlog Management

Ideas that aren't ready for planning go in the "Future Ideas" section. To promote an idea:

1. Move from "Future Ideas" to a version's iteration table
2. Assign it the next available iteration number
3. Create its iteration log file
4. Update INDEX.md current state

---

**Last Updated**: 2026-03-06  
**Current Version**: 0.1.0 (in development)
