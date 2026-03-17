# ⏳ Pending Iterations - Phase 1 (v0.1.0 MVP)

**Last Updated**: 2026-03-16  
**Completed**: 26 iterations  
**Remaining**: 2 iterations for v0.1.0 (1 in progress, 1 pending)
**Backlogged**: 1 iteration (13 - Admin Badge Management)

---

## 🔴 HIGH PRIORITY (Core Learning Loop)

### Iteration 14: Multi-Step Test System Architecture
**Status**: ✅ COMPLETED | **Completed**: 2026-03-08  
**Log**: [ITERATION-14-multi-step-test.md](./ITERATION-14-multi-step-test.md)  
**Files Created**:
- ✅ `lib/medoru/tests/test.ex` - Test schema with types (daily/lesson/teacher/practice)
- ✅ `lib/medoru/tests/test_step.ex` - Step schema with question types (multichoice/fill/match/order)
- ✅ `lib/medoru/tests/test_session.ex` - Session tracking (started/in_progress/completed/abandoned/timed_out)
- ✅ `lib/medoru/tests/test_step_answer.ex` - Answer recording with penalty calculation
- ✅ `lib/medoru/tests.ex` - Context with full CRUD and statistics
- ✅ `priv/repo/migrations/*_create_tests.exs`
- ✅ `priv/repo/migrations/*_create_test_steps.exs`
- ✅ `priv/repo/migrations/*_create_test_sessions.exs`
- ✅ `priv/repo/migrations/*_create_test_step_answers.exs`
- ✅ `test/medoru/tests_test.exs` - 38 passing tests

**Key Features Implemented**:
- Test schema with step types: reading, writing, listening, grammar, speaking, vocabulary
- Question sub-types: multichoice (1pt), fill (2pt), match (2pt), order (2pt)
- TestSession tracks progress step-by-step with time tracking
- Step answers with penalty system (25% per extra attempt, 10% per hint)
- Comprehensive statistics for users and tests
- Full CRUD operations for tests, steps, sessions, and answers

---

### Iteration 16: Auto-Generated Daily Tests ✅ COMPLETED
**Status**: ✅ COMPLETED | **Completed**: 2026-03-09  
**Log**: [ITERATION-16-auto-generated-daily-tests.md](./ITERATION-16-auto-generated-daily-tests.md)

**Files Created**:
- ✅ `lib/medoru/learning/daily_test_generator.ex` - Service module
- ✅ `lib/medoru_web/live/daily_test_live.ex` - Main LiveView
- ✅ `lib/medoru_web/live/daily_test_live/daily_test_live.html.heex` - Template
- ✅ `lib/medoru_web/live/daily_test_live/complete.ex` - Completion screen
- ✅ `test/medoru/learning/daily_test_generator_test.exs` - Tests

**Features Implemented**:
- ✅ SRS-based review items + new words (up to 5)
- ✅ Multiple choice questions (2 per word)
- ✅ One daily test per user per day
- ✅ Completing updates streak
- ✅ `/daily-test` and `/daily-test/complete` routes

---

## 🟡 MEDIUM PRIORITY (Content Expansion)

### Iteration 13: Admin Badge Management
**Status**: ⏳ BACKLOGGED (Post v0.1.0) | **Estimated**: 1-2 days  
**Note**: Moved to future version backlog - not required for v0.1.0 MVP

**Files to Create**:
- `lib/medoru_web/live/admin/badge_live/index.ex`
- `lib/medoru_web/live/admin/badge_live/edit.ex`
- Update `lib/medoru/gamification.ex` - Add admin functions

**Key Features**:
- CRUD for badges in admin panel
- Manual badge award to users
- Badge statistics view

---

### Iteration 17: Vocabulary Lesson System ✅ COMPLETED | **APPROVED**
**Status**: ✅ COMPLETED | **Completed**: 2026-03-09 | **Approved**: 2026-03-09  
**Log**: [ITERATION-17-vocabulary-lessons.md](./ITERATION-17-vocabulary-lessons.md)  
**Files Created**:
- ✅ `lib/mix/tasks/medoru.generate_lessons_v7.ex` - v7 Topic-based lesson generation
- ✅ `priv/repo/parse_anki_export.exs` - Parse Core 6000 data
- ✅ `priv/repo/enrich_word_pool.exs` - Enrich word pool with DB IDs
- ✅ `docs/v7_lesson_design.md` - Lesson design document
- ✅ `docs/v7_lesson_summary.md` - Generation summary
- ✅ `docs/v7_lesson_improvements.md` - Topic alignment improvements
- ✅ `LESSON_GENERATION.md` - Documentation
- ✅ `lib/medoru/tests/lesson_test_generator.ex` - Auto-generates tests from lesson words
- ✅ `lib/medoru/tests/lesson_test_session.ex` - Adaptive test sessions with retry logic
- ✅ `lib/medoru_web/live/lesson_test_live/show.ex` - Test taking interface
- ✅ `lib/medoru_web/live/lesson_test_live/complete.ex` - Test completion screen
- ✅ `priv/repo/migrations/*_add_test_id_to_lessons.exs` - Lesson-test association

**Completed**:
- ✅ **v7: 300 topic-based lessons (100 N5 + 100 N4 + 100 N3)**
- ✅ **v7: 4,421 word-lesson links (~15 words per lesson)**
- ✅ **v7: Core 6000 data with example sentences**
- ✅ **v7: Topic names aligned with Core 6000 word distribution**
- ✅ **v7: N5 topics renamed to match actual content (numbers→time→verbs→adjectives→places)**
- ✅ System lessons auto-generated from existing words
- ✅ Lesson tests auto-generated from words
- ✅ 3-4 multichoice steps per word (reading, meaning, reverse)
- ✅ Adaptive retry: wrong answers go to end of queue
- ✅ Test UI with progress tracking, hints, skip option
- ✅ Lesson completion tracking via tests

**Approved By**: User  
**Notes**: N5 topic names now accurately reflect Core 6000 natural progression. N4/N3 topics still generic - to be improved in future iteration.

**Usage**:
```bash
# v7 Lesson Generation (current)
mix run priv/repo/parse_anki_export.exs data/anki2.txt
mix run priv/repo/enrich_word_pool.exs
mix medoru.generate_lessons_v7  # 300 topic-based lessons

# Legacy (replaced by v7)
# mix medoru.generate_lessons
```

---

### Iteration 22: Kanji Writing Test Step ✅ COMPLETED
**Status**: ✅ COMPLETED | **Completed**: 2026-03-08  
**Log**: [2026-03-08_iteration_22.md](./2026-03-08_iteration_22.md)  
**Depends On**: Iteration 14, 17

**Files Created**:
- ✅ `lib/medoru/tests/writing_validator.ex` - Stroke validation against KanjiVG
- ✅ `lib/medoru_web/live/lesson_test_live/writing_component.ex` - Canvas drawing component
- ✅ `assets/js/hooks/kanji_writing.js` - Client-side drawing hook

**Files Modified**:
- ✅ `lib/medoru/tests/lesson_test_generator.ex` - Added writing step generation
- ✅ `lib/medoru/tests/lesson_test_session.ex` - Added `submit_writing_answer/4`
- ✅ `lib/medoru_web/live/lesson_test_live/show.ex` - Writing question UI
- ✅ `assets/js/app.js` - Added KanjiWriting hook

**Key Features**:
- ✅ Canvas-based kanji drawing (mouse, pen, touch)
- ✅ Stroke validation against KanjiVG reference data
- ✅ 70% accuracy threshold to pass
- ✅ Writing steps worth 5 points (highest value)
- ✅ Wrong answers show stroke animation preview
- ✅ Grid background for proportion guidance
- ✅ Undo last stroke, Clear canvas controls
- ✅ Adaptive retry: wrong writing steps go to end of queue

---

### Iteration 23: Reading Comprehension Text Input Test Step
**Status**: ✅ COMPLETED | **Completed**: 2026-03-10  
**Log**: [ITERATION-23-reading-text-input.md](./ITERATION-23-reading-text-input.md)  
**Depends On**: Iteration 14 (Multi-Step Test System), Iteration 17 (Vocabulary Lessons)

**Files Created**:
- ✅ `lib/medoru/tests/reading_answer_validator.ex` - Validates meaning and kana reading answers
- ✅ `lib/medoru_web/live/lesson_test_live/reading_text_component.ex` - Text input component for reading questions
- ✅ `test/medoru/tests/reading_answer_validator_test.exs` - Validation tests

**Files Modified**:
- ✅ `lib/medoru/tests/test_step.ex` - Added `:reading_text` question type (2 points)
- ✅ `lib/medoru/tests/lesson_test_generator.ex` - Added reading text step generation
- ✅ `lib/medoru/tests/lesson_test_session.ex` - Added `submit_reading_text_answer/5`
- ✅ `lib/medoru_web/live/lesson_test_live/show.ex` - Reading text question UI with event handlers

**Key Features Implemented**:
- ✅ New test step type: `:reading_text` (distinct from `:multichoice`)
- ✅ Displays Japanese word with meaning + reading input fields
- ✅ **Meaning validation**: Fuzzy match (case insensitive, partial match, prefix stripping)
- ✅ **Reading validation**: Exact match with kana variations (おう/おお, えい/ええ)
- ✅ Visual feedback: Green/red highlighting on input fields
- ✅ Hint system reveals first letter/kana (-10% penalty)
- ✅ Shows correct answers after incorrect attempt
- ✅ Adaptive retry: wrong answers go to end of queue
- ✅ 2 points base scoring with penalty system

---

### Iteration 24A: UI Internationalization (i18n)
**Status**: ✅ APPROVED | **Completed**: 2026-03-15  
**Log**: [ITERATION-24A-ui-i18n.md](./ITERATION-24A-ui-i18n.md)

**Overview**: Translate entire interface to Bulgarian and Japanese using Gettext. Language selector in header and settings.

**Languages**: English (default), Bulgarian, Japanese

**Key Features**:
- ✅ Gettext-based translations (priv/gettext/) - 707 strings
- ✅ Language selector in header (dropdown with flags) + settings page
- ✅ Locale persistence: URL param → cookie → browser → default
- ✅ All UI text wrapped in `gettext()` calls
- ✅ Bulgarian and Japanese translations approved

**Files Created**: SetLocale plug, language settings LiveView, BG/JA .po files

---

### Iteration 24B: Content Translation (Kanji, Words, Lessons) 🚧 IN PROGRESS
**Status**: 🚧 IN PROGRESS | **Started**: 2026-03-16  
**Log**: [ITERATION-24B-content-i18n.md](./ITERATION-24B-content-i18n.md)  
**Depends On**: 24A ✅ COMPLETED

**Overview**: Translate all learning content meanings to Bulgarian. JSONB storage for extensibility.

**Progress**:
| Level | Status | Translated |
|-------|--------|------------|
| N5 | ✅ Complete | 3,168 words |
| N4 | ✅ Complete | 6,808 words |
| **N3** | **🚧 IN PROGRESS** | **0 / 135,847 words** |
| Kanji | ✅ Complete | 2,212 kanji |
| Lessons | ✅ Complete | 101 lessons |

**Storage**: `translations` JSONB column on kanji, words, lessons tables:
```elixir
%{
  "bg" => %{"meanings" => [...], "meaning" => "..."}
}
```

**Completed Translations**:
| Level | Words | Status |
|-------|-------|--------|
| **N5** | 3,168 | ✅ 100% Bulgarian |
| **N4** | 6,808 | ✅ 100% Bulgarian |
| **Kanji** | 2,212 | ✅ 100% Bulgarian |
| **Lessons** | 101 | ✅ 100% Bulgarian |
| **N3** | 135,847 | ⏳ Ready to start |

**Total**: 10,089 words + 2,212 kanji + 101 lessons translated

**Behavior**:
- Bulgarian user sees all meanings in Bulgarian
- Test questions validate against Bulgarian meanings
- Daily tests use localized meanings
- Fallback to English if translation missing

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

## 🔴 HIGH PRIORITY (Classroom System)

### Iteration 18: Classroom Core ✅ COMPLETED
**Status**: ✅ COMPLETED | **Completed**: 2026-03-11  
**Log**: [ITERATION-18-classroom-core.md](./ITERATION-18-classroom-core.md)  
**Depends On**: User types (✅ done)

**Files Created**:
- ✅ `lib/medoru/classrooms/classroom.ex` - Schema with auto slug/code generation
- ✅ `lib/medoru/classrooms/classroom_membership.ex` - Schema with status workflow
- ✅ `lib/medoru/classrooms.ex` - Full context with CRUD and membership functions
- ✅ `lib/medoru_web/live/teacher/classroom_live/index.ex` - Classroom listing
- ✅ `lib/medoru_web/live/teacher/classroom_live/show.ex` - Management interface with tabs
- ✅ `lib/medoru_web/live/teacher/classroom_live/new.ex` - Create classroom form
- ✅ `priv/repo/migrations/20260311085827_create_classrooms.exs`
- ✅ `priv/repo/migrations/20260311085840_create_classroom_memberships.exs`
- ✅ `test/medoru/classrooms_test.exs` - 31 passing tests

**Key Features Implemented**:
- ✅ Create classrooms (name, slug, invite code) with auto-generation
- ✅ Teacher management interface at `/teacher/classrooms`
- ✅ Tabs: Overview, Students, Lessons, Tests, Settings
- ✅ Membership workflow: apply → approve/reject
- ✅ Student management: view, remove, points tracking
- ✅ Invite code regeneration
- ✅ Classroom stats (members, pending apps, total points)
- ✅ Archive and close classroom actions

---

### Iteration 19: Classroom Membership & Applications ✅ COMPLETED
**Status**: ✅ COMPLETED | **Completed**: 2026-03-11  
**Log**: [ITERATION-19-classroom-membership.md](./ITERATION-19-classroom-membership.md)  
**Depends On**: Iteration 18, Notifications (✅ done)

**Files Created**:
- ✅ `lib/medoru_web/live/classroom_live/join.ex` - Student join page with live validation
- ✅ `lib/medoru_web/live/classroom_live/index.ex` - Student's classrooms list
- ✅ `lib/medoru_web/live/classroom_live/show.ex` - Student classroom detail
- ✅ `lib/medoru_web/components/helpers.ex` - Shared helper functions
- ✅ `lib/medoru/notifications.ex` - 4 new notification functions

**Key Features Implemented**:
- ✅ Join by invite code with real-time validation
- ✅ Application workflow (pending → approved/rejected)
- ✅ Teacher notifications for new applications
- ✅ Student notifications for approve/reject/remove
- ✅ Student can leave classroom
- ✅ Rankings and points tracking

---

### Iteration 20: Classroom Tests, Lessons & Rankings
**Status**: ✅ COMPLETED | **Completed**: 2026-03-11 | **Log**: [ITERATION-20-classroom-tests-rankings.md](./ITERATION-20-classroom-tests-rankings.md)  
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

### Iteration 15: Teacher Test Creation - Part A: Test Management Core
**Status**: ✅ COMPLETED | **Completed**: 2026-03-11 | **Log**: [ITERATION-15A-test-management-core.md](./ITERATION-15A-test-management-core.md)  
**Depends On**: Iteration 14, User types (✅ done)
**Files to Create**:
- `lib/medoru_web/live/teacher/test_live/index.ex` - List teacher's tests
- `lib/medoru_web/live/teacher/test_live/new.ex` - Create test with settings
- `lib/medoru_web/live/teacher/test_live/show.ex` - Test overview
- Update `lib/medoru/tests/test.ex` - Add state field and owner

**Key Features**:
- Test lifecycle: `in_progress` → `ready` → `published` → `archived`
- Test settings: name, description, time limit, max attempts
- Draft auto-save (in_progress state)
- Archive/unarchive functionality
- Tests owned by teacher, only visible to them

---

### Iteration 25: Teacher Test Creation - Part B: Step Builder Framework
**Status**: ✅ COMPLETED | **Completed**: 2026-03-12 | **Approved**: 2026-03-12  
**Log**: [ITERATION-25-step-builder-framework.md](./ITERATION-25-step-builder-framework.md)
**Depends On**: Iteration 15A
**Files Created**:
- ✅ `lib/medoru_web/components/step_builder_components.ex` - Step builder UI components
- ✅ `lib/medoru_web/live/teacher/test_live/edit.ex` - Step builder LiveView
- ✅ `assets/js/hooks/step_sorter.js` - Drag-drop JavaScript hook
- ✅ `lib/medoru/content.ex` - Added `search_words/2`
- ✅ `test/medoru_web/live/teacher/test_live/edit_test.exs` - Test suite

**Key Features Implemented**:
- ✅ Drag-drop step reordering
- ✅ Step type selector (multichoice, reading, writing)
- ✅ Step form modal with all fields
- ✅ Word search/link to vocabulary
- ✅ Delete steps with confirmation
- ✅ Mark test as ready
- ✅ Step count and points tracking

---

### Iteration 25B: Step Builder Enhancements
**Status**: ✅ COMPLETED | **Completed**: 2026-03-12 | **Approved**: 2026-03-12  
**Log**: [ITERATION-25B-step-builder-enhancements.md](./ITERATION-25B-step-builder-enhancements.md)
**Depends On**: Iteration 25

**Files Created**:
- ✅ `priv/repo/migrations/20260312114903_add_kanji_id_to_test_steps.exs` - Kanji association

**Files Modified**:
- ✅ `lib/medoru/content.ex` - Added `search_kanji/2` with readings preload, improved `search_words/2` ranking
- ✅ `lib/medoru/tests/test_step.ex` - Added `kanji_id` field and association
- ✅ `lib/medoru_web/live/teacher/test_live/edit.ex` - Kanji search UI, smart question generation, hints fix

**Key Features Implemented**:
- ✅ **Kanji Writing Step**: Separate kanji search dropdown for writing steps
  - Search by character, meaning, or reading
  - Auto-generates: "Draw the kanji for [meaning]"
  - Correct answer is the kanji character
  - Shows on/kun readings as explanation
- ✅ **Smart Question Generation**: Detects search type
  - Hiragana/Katakana search → "How do you read...?"
  - English search → "What is the meaning of...?"
- ✅ **Smarter Word Search Ranking**:
  - Priority 1: Exact match on meaning
  - Priority 2: Starts with query
  - Priority 3: Contains query
  - Sorted by usage_frequency
- ✅ **Hints Field Fix**: Convert string input to array for schema compatibility

**Approved By**: User

---

### Iteration 26: Multi-Choice Step Builder Enhancements ✅ COMPLETED
**Status**: ✅ COMPLETED | **Completed**: 2026-03-13 | **Approved**: 2026-03-13  
**Depends On**: Iteration 25, 25B

**Files Modified**:
- ✅ `lib/medoru_web/live/teacher/test_live/edit.ex` - Tag-based options UI, validation fixes
- ✅ `lib/medoru/tests/test_step.ex` - 4-8 options validation, correct answer mandatory
- ✅ `lib/medoru/content.ex` - Word search ranking (exact match priority)
- ✅ `lib/medoru_web/components/step_builder_components.ex`
- ✅ `assets/js/hooks/option_input.js` - Enter key support

**Key Features Implemented**:
- ✅ **Validation**: Minimum 4 options, maximum 8, correct answer mandatory
- ✅ **Tag-style options UI**: Correct answer (green, not removable), wrong answers (removable)
- ✅ **Word search ranking**: Exact match appears before phrases (e.g., "blue" before "navy blue")
- ✅ **Enter key support**: Adds option without submitting form
- ✅ **Input clearing**: Field clears after adding option
- ✅ **Flash auto-dismiss**: Messages disappear after 5 seconds
- ✅ **Correct answer debounce**: 3-second delay before updating options
- ✅ **No validation on open**: Form starts clean

**Approved By**: User

---

### Iteration 27: Teacher Test Creation - Part D: Typing Step Builder
**Status**: ⏳ NOT STARTED | **Priority**: 🔴 HIGH | **Estimated**: 1-2 days  
**Depends On**: Iteration 15B
**Files to Create**:
- `lib/medoru_web/live/teacher/test_live/steps/typing.ex`

**Key Features**:
- Word selection
- Toggle: default meaning vs custom meaning
- Custom meaning input (exact match override)
- Hint text configuration

---

### Iteration 28: Kanji Writing Step Builder & Student Test Taking ✅ COMPLETED & APPROVED
**Status**: ✅ COMPLETED & APPROVED | **Completed**: 2026-03-13 | **Approved**: 2026-03-13 | **Depends On**: Iteration 25B

**Files Created/Modified**:
- ✅ `lib/medoru_web/live/teacher/test_live/edit.ex` - Enhanced kanji selection with preview
- ✅ `lib/medoru_web/live/classroom_live/writing_component.ex` - Student writing component
- ✅ `lib/medoru_web/live/classroom_live/test.ex` - Integrated writing component
- ✅ `lib/medoru/tests.ex` - Preload kanji in list_test_steps

**Key Features Implemented**:
- ✅ **Kanji search/selection** - Teachers search by character, meaning, or reading
- ✅ **Stroke count validation** - Shows warning if kanji has no stroke data
- ✅ **Stroke animation preview** - Live preview of stroke order when selecting kanji
- ✅ **Stroke data storage** - Saves stroke data in question_data for validation
- ✅ **Student writing experience** - Full kanji writing canvas in classroom tests
- ✅ **Real-time validation** - WritingValidator integration with feedback
- ✅ **Stroke preview on wrong answers** - Shows correct strokes when student makes mistakes

---

### Iteration 29: Teacher Test Creation - Part F: Classroom Publishing
**Status**: ✅ COMPLETED & APPROVED | **Completed**: 2026-03-12 | **Approved**: 2026-03-12  
**Log**: [ITERATION-29-classroom-publishing.md](./ITERATION-29-classroom-publishing.md)
**Approved By**: User

---

### Iteration 30: Complete Classroom Test Taking Experience
**Status**: ✅ COMPLETED & APPROVED | **Completed**: 2026-03-15 | **Approved**: 2026-03-15 | **Log**: [ITERATION-30-test-taking-complete.md](./ITERATION-30-test-taking-complete.md)
**Depends On**: Iteration 29

**Issues to Fix**:
- ⏱️ Timer not counting down (display only)
- ⏹️ No auto-submit when time runs out
- 📊 No results/review screen after test
- 📝 Time not recorded accurately
- 💾 Progress not saved after each answer
- 🔄 Resume functionality needs testing

**Key Features**:
- Working timer with 1-second countdown
- Auto-submit on timeout
- Results page with score breakdown
- Correct/incorrect answer review
- Progress persistence

**Files to Create/Modify**:
- New: `ClassroomLive.TestResults`, `test_timer.js` hook
- Modify: `ClassroomLive.Test`, `Classrooms` context  
**Log**: [ITERATION-29-classroom-publishing.md](./ITERATION-29-classroom-publishing.md)
**Depends On**: Iteration 15A, 25, 25B

**Files Created**:
- ✅ `lib/medoru/classrooms/classroom_test.ex` - Schema for test-classroom links
- ✅ `priv/repo/migrations/20260312134138_create_classroom_tests.exs` - Migration
- ✅ `lib/medoru_web/live/teacher/test_live/publish.ex` - Publish UI
- ✅ `lib/medoru_web/live/classroom_live/test.ex` - Student test taking

**Files Modified**:
- ✅ `lib/medoru/classrooms.ex` - Added publishing context functions
- ✅ `lib/medoru_web/live/teacher/test_live/show.ex` - Link to publish page
- ✅ `lib/medoru_web/live/classroom_live/show.ex` - Display published tests
- ✅ `lib/medoru_web/router.ex` - Added publish and test routes

**Key Features Implemented**:
- ✅ **Publish to Classroom flow**: Teachers select classrooms from their list
- ✅ **Publishing options**: Due dates and max attempts per classroom
- ✅ **Published tests appear in classroom's "Tests" tab**: Students can see available tests
- ✅ **Unpublish/Republish functionality**: Soft unpublish with ability to republish
- ✅ **Track which classrooms have the test**: Displayed in test show page
- ✅ **Student test taking**: Students can start and complete tests from classroom

**Approved By**: User

---

### Iteration 21: Admin Dashboard & System Management ✅ COMPLETED
**Status**: ✅ COMPLETED | **Completed**: 2026-03-16 | **Approved**: 2026-03-16  
**Log**: [ITERATION-21-admin-dashboard.md](./ITERATION-21-admin-dashboard.md)

**Completed Features**:
- ✅ Admin Dashboard with system stats (users, content, classrooms)
- ✅ Kanji Management (list, create, edit, delete, translations)
- ✅ Kanji Readings Management (add, edit, delete on/kun readings)
- ✅ Word Management (list, create, edit, delete, translations)
- ✅ Lesson Management (list, create, edit, delete, translations)
- ✅ Admin navigation in header and user dropdown

---

## 📊 Summary

**Completed**: 26 iterations  
**Remaining for v0.1.0**: 2 iterations  
**Backlogged**: 1 iteration (13 - Admin Badge Management)

| Priority | Iterations | Status |
|----------|------------|--------|
| 🔴 High | 14 ✅, 15A ✅, 16 ✅, 18 ✅, 19 ✅, 20 ✅, 21 ✅, 23 ✅, 25 ✅, 25B ✅, 26 ✅, 27 ✅, 28 ✅, 29 ✅, 30 ✅, 31 ✅ | 16 COMPLETE |
| 🔴 High | 32, 33 | 2 PENDING |
| 🟡 Medium | 17 ✅, 24A ✅, 24B 🚧 | 2 COMPLETE, 1 IN PROGRESS |
| 🟡 Medium | 13 | 1 BACKLOGGED (Post v0.1.0) |
| **Total v0.1.0** | **3** | **7-10 days est.** |

---

## 🎯 Recommended Order

### Completed ✅
1. **Iteration 14** ✅ (Multi-Step Test) - Foundation for tests
2. **Iteration 16** ✅ (Auto-Generated Daily Tests) - SRS-based daily reviews
3. **Iteration 17** ✅ (Vocabulary Lessons) - Expand content
4. **Iteration 18** ✅ (Classroom Core) - Classroom foundation
5. **Iteration 19** ✅ (Classroom Membership) - Student joining
6. **Iteration 20** ✅ (Classroom Tests/Rankings) - Full classroom
7. **Iteration 22** ✅ (Kanji Writing) - Writing validation
8. **Iteration 23** ✅ (Reading Text Input) - Text-based reading comprehension
9. **Iteration 15A** ✅ (Test Management Core) - Teacher test CRUD
10. **Iteration 25** ✅ (Step Builder Framework) - Base step management
11. **Iteration 25B** ✅ (Step Builder Enhancements) - Kanji writing, smart search
12. **Iteration 26** ✅ (Multi-Choice Step Builder) - Enhanced options UI
13. **Iteration 29** ✅ (Classroom Publishing) - Connect tests to classrooms
14. **Iteration 27** ✅ (Typing Step Builder) - Fill in blank questions
15. **Iteration 30** ✅ (Complete Test Taking) - Timer, results, auto-submit, resume

### In Progress 🚧
1. **Iteration 24B** (Content i18n) 🚧 - Translate N3 words to Bulgarian (0 / 135,847 words)

### Up Next 🟡
1. **Iteration 32** (UI Polish & Mobile) - Pre-production cleanup
2. **Iteration 33** (Deployment) - Production setup

### Completed ✅
1. **Iteration 24A** (UI i18n) ✅ - Translate interface to Bulgarian and Japanese
2. **Iteration 21** (Admin Dashboard) ✅ - Full admin content management
3. All other previous iterations (14, 15A, 16, 17, 18, 19, 20, 22, 23, 25, 25B, 26, 27, 28, 29, 30, 31)

---

## 🗂️ Backlog (Post v0.1.0)

### Iteration 13: Admin Badge Management
**Status**: ⏳ BACKLOGGED  
**Priority**: 🟡 MEDIUM  
**Planned For**: v0.2.0 or later

**Reason**: Admin can already manage content (kanji, words, lessons) via the dashboard. Badge management is a nice-to-have but not critical for MVP launch.

---

### Iteration 31: Teacher Custom Lessons
**Status**: ✅ COMPLETED | **Completed**: 2026-03-15 | **Log**: [ITERATION-31-teacher-custom-lessons.md](./ITERATION-31-teacher-custom-lessons.md)  
**Depends On**: Iteration 29 (Classroom Publishing)

**Key Features**:
- Teachers create custom reading lessons
- Pick words via autocomplete (reuse test builder search)
- 1-50 words per lesson
- Edit meanings and add examples per word
- Publish to classrooms
- Students study without test (mark as complete)
- Points awarded on completion

---

## 🔴 HIGH PRIORITY (UI & Deployment)

### Iteration 32: UI Polish & Mobile Responsiveness
**Status**: ⏳ NOT STARTED | **Estimated**: 2-3 days  
**Log**: [ITERATION-32-ui-polish-mobile.md](./ITERATION-32-ui-polish-mobile.md)  
**Priority**: 🔴 HIGH

**Key Features**:
- Mobile-responsive design audit and fixes
- Touch-friendly UI elements
- Responsive navigation (hamburger menu on mobile)
- Optimized layouts for small screens
- Dark mode refinements
- Accessibility improvements

---

### Iteration 33: Deployment & Production Setup
**Status**: ⏳ PLANNED | **Estimated**: 3-4 days  
**Log**: [ITERATION-33-deployment.md](./ITERATION-33-deployment.md)  
**Priority**: 🔴 HIGH  
**Domain**: medoru.net

**Infrastructure**:
- **Server**: VPS (to be provisioned)
- **Domain**: medoru.net (to be purchased)
- **SSL**: Certbot (Let's Encrypt)
- **Reverse Proxy**: Nginx
- **App**: Phoenix as systemd service
- **Database**: PostgreSQL

**Deployment Method**: Ansible playbook

**Data Migration**:
- ✅ Migrate: Kanji, readings, words, lessons, badges (system content)
- ❌ Skip: Users, classrooms, custom tests, custom lessons (user data)

**Secrets from Local Env**:
- Real Google OAuth credentials
- Database credentials
- Phoenix secret key

**Key Features**:
- Automated deployment via Ansible
- Nginx reverse proxy with SSL
- Systemd service for Phoenix app
- Database seeding from local dump
- Production environment variables

---

## 📁 Quick Links

- Full Plan: [ITERATION-PLAN-v0.1.0.md](./ITERATION-PLAN-v0.1.0.md)
- Roadmap: [ROADMAP.md](./ROADMAP.md)
- Main Index: [INDEX.md](./INDEX.md)
- Project Skills: [../skills/medoru/SKILL.md](../skills/medoru/SKILL.md)
