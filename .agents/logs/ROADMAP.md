# Medoru Development Roadmap

This document outlines the long-term development plan for Medoru.

---

## Version 0.1.0 - MVP (Current)

**Goal:** Core learning platform with content and basic progress tracking

**Features:**
- ✅ Google OAuth authentication
- ✅ Kanji database (N5) with readings
- ✅ Words with kanji/reading links
- ⏳ Lessons system (1-3 kanji per lesson)
- ⏳ User progress tracking
- ⏳ Daily review tests with SRS
- ⏳ Streak tracking

**Target Users:** Individual learners

---

## Version 0.2.0 - Social Features

**Goal:** Make learning social and competitive

**Features:**
- Friends system (add, remove, view profiles)
- Real-time 1v1 duels
- Global and friend leaderboards
- Duel history and statistics
- In-app notifications

**Technical Changes:**
- Phoenix PubSub for real-time features
- Presence tracking
- Background job processing (Oban)
- ELO ranking system

**Target Users:** Competitive learners, study groups

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
