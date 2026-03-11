# ⏳ Pending Iterations - Phase 1 (v0.1.0 MVP)

**Last Updated**: 2026-03-11  
**Completed**: 16 iterations  
**Remaining**: 8 iterations for v0.1.0

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

### Iteration 24: Internationalization (i18n) - Multi-Language Support
**Status**: ⏳ NOT STARTED | **Estimated**: 2-3 days  
**Depends On**: None (can be done in parallel)

**Overview**:  
Add full internationalization support to make the platform accessible in English, Bulgarian, and Japanese. Use AI-powered translation for all UI labels, with fallback to English.

**Files to Create**:
- `priv/gettext/en/LC_MESSAGES/default.po` - English source translations
- `priv/gettext/bg/LC_MESSAGES/default.po` - Bulgarian translations
- `priv/gettext/ja/LC_MESSAGES/default.po` - Japanese translations
- `lib/medoru_web/live/settings_live/language_selector.ex` - Language selection component
- `lib/medoru/i18n/translation_manager.ex` - Translation management utilities

**Files Modified**:
- `config/config.exs` - Add i18n configuration, default locale
- `lib/medoru_web.ex` - Import Gettext macros, set locale plug
- `lib/medoru_web/router.ex` - Add locale scope or parameter
- `lib/medoru_web/components/core_components.ex` - Wrap all text in `gettext()` calls
- All LiveView modules - Replace hardcoded strings with `gettext()` calls
- All templates (.heex files) - Replace text with `{gettext("...")}`
- `lib/medoru_web/plugs/set_locale.ex` - Set locale from session/cookie/params

**Key Features**:
- **Language Selector Dropdown**: Available in header/settings
  - 🇬🇧 English (default)
  - 🇧🇬 Bulgarian
  - 🇯🇵 Japanese
- **AI-Powered Translation**: Use AI to generate initial translations for all labels
- **Gettext Integration**: Standard Elixir i18n via `Gettext` module
- **Locale Persistence**: Store selection in session + cookie
- **Fallback Chain**: ja → en, bg → en (if translation missing)
- **Translation Coverage**:
  - All UI labels and buttons
  - Flash messages and notifications
  - Error messages and validations
  - Lesson titles and descriptions (keep Japanese content, translate UI)
  - Navigation and menus
  - Forms and placeholders

**Translation Process**:
1. Extract all strings using `mix gettext.extract`
2. AI translate missing strings for bg/ja
3. Review and refine translations
4. Compile with `mix gettext.merge`

**UI Example**:
```elixir
# Before
<.button>Start Lesson</.button>

# After
<.button>{gettext("Start Lesson")}</.button>
```

**Database Considerations**:
- User preference: `users.settings["locale"]` (default: "en")
- Guest users: cookie-based locale preference

**Technical Notes**:
- Use `ex_cldr` for number/date/currency formatting if needed
- Japanese: Consider kanji vs hiragana for different user levels
- Bulgarian: Cyrillic support, pluralization rules
- Keep content language (vocabulary words) in Japanese, only translate UI

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
**Status**: ⏳ NOT STARTED | **Priority**: 🔴 HIGH | **Estimated**: 2 days  
**Depends On**: Iteration 15A
**Files to Create**:
- `lib/medoru_web/live/teacher/test_live/edit.ex` - Test editor
- `lib/medoru_web/live/teacher/test_live/step_builder.ex` - Step management
- `lib/medoru_web/components/step_builder_components.ex`

**Key Features**:
- Add/remove/reorder steps (drag-drop)
- Step type selector: multichoice, typing, writing
- Step list with preview
- Empty step placeholders

---

### Iteration 26: Teacher Test Creation - Part C: Multi-Choice Step Builder
**Status**: ⏳ NOT STARTED | **Priority**: 🔴 HIGH | **Estimated**: 2 days  
**Depends On**: Iteration 15B
**Files to Create**:
- `lib/medoru_web/live/teacher/test_live/steps/multichoice.ex`

**Key Features**:
- Word search/typeahead selection
- Distractor word selection (alternative choices)
- Number of choices setting (4-8)
- Step preview mode
- Validation: 1 correct + N distractors

---

### Iteration 27: Teacher Test Creation - Part D: Typing Step Builder
**Status**: ⏳ NOT STARTED | **Priority**: 🟡 MEDIUM | **Estimated**: 1-2 days  
**Depends On**: Iteration 15B
**Files to Create**:
- `lib/medoru_web/live/teacher/test_live/steps/typing.ex`

**Key Features**:
- Word selection
- Toggle: default meaning vs custom meaning
- Custom meaning input (exact match override)
- Hint text configuration

---

### Iteration 28: Teacher Test Creation - Part E: Kanji Writing Step Builder
**Status**: ⏳ NOT STARTED | **Priority**: 🟡 MEDIUM | **Estimated**: 1 day  
**Depends On**: Iteration 15B
**Files to Create**:
- `lib/medoru_web/live/teacher/test_live/steps/writing.ex`

**Key Features**:
- Kanji search/selection
- Stroke count validation
- Preview with stroke animation

---

### Iteration 29: Teacher Test Creation - Part F: Classroom Publishing
**Status**: ⏳ NOT STARTED | **Priority**: 🔴 HIGH | **Estimated**: 1-2 days  
**Depends On**: Iteration 15A, 15C-E
**Files to Create**:
- `lib/medoru/classrooms/classroom_test.ex` - Schema
- `priv/repo/migrations/*_create_classroom_tests.exs`
- Update `lib/medoru_web/live/teacher/test_live/publish.ex`

**Key Features**:
- "Publish to Classroom" flow
- Select target classrooms from teacher's list
- Published tests appear in classroom's "Tests" tab
- Unpublish/remake functionality
- Track which classrooms have the test
- Students can see and take published tests

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

**Completed**: 20/29 iterations (69%)

| Priority | Iterations | Status |
|----------|------------|--------|
| 🔴 High | 14 ✅, 16 ✅, 18 ✅, 19 ✅, 20 ✅, 23 ✅ | 6 COMPLETE |
| 🔴 High | 15, 25-26, 29 | 5 PENDING |
| 🟡 Medium | 13, 17 ✅, 22 ✅, 24, 27-28 | 5 PENDING |
| 🟢 Lower | 21 | 1 PENDING |
| **Total** | **11** | **14-21 days est.** |

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

### Up Next 🔴
10. **Iteration 15B** (Step Builder Framework) - Base step management
11. **Iteration 15C** (Multi-Choice Steps) - First step type
12. **Iteration 29** (Classroom Publishing) - Connect tests to classrooms

### Future 🟡
13. **Iteration 27-28** (Typing/Writing Steps) - Additional step types
14. **Iteration 13** (Admin Badge Management) - Admin features
15. **Iteration 24** (i18n Multi-Language) - Platform internationalization
16. **Iteration 21** (Admin Dashboard) - Admin polish

---

## 📁 Quick Links

- Full Plan: [ITERATION-PLAN-v0.1.0.md](./ITERATION-PLAN-v0.1.0.md)
- Roadmap: [ROADMAP.md](./ROADMAP.md)
- Main Index: [INDEX.md](./INDEX.md)
- Project Skills: [../skills/medoru/SKILL.md](../skills/medoru/SKILL.md)
