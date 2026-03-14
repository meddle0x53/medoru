# ⏳ Pending Iterations - Phase 1 (v0.1.0 MVP)

**Last Updated**: 2026-03-14  
**Completed**: 23 iterations  
**Remaining**: 8 iterations (5 HIGH, 2 MEDIUM, 1 LOWER priority)

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
**Status**: ⏳ NOT STARTED | **Priority**: 🔴 HIGH | **Estimated**: 2-3 days  
**Log**: [ITERATION-30-test-taking-complete.md](./ITERATION-30-test-taking-complete.md)
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

### Iteration 21: Admin Dashboard & System Management
**Status**: ⏳ NOT STARTED | **Estimated**: 3-4 days  
**Depends On**: All above
**Files to Create**:
- `lib/medoru_web/live/admin/dashboard_live.ex` - Main admin dashboard
- `lib/medoru_web/live/admin/content_live/kanji.ex` - Kanji management
- `lib/medoru_web/live/admin/content_live/kanji_form.ex` - Add/edit kanji
- `lib/medoru_web/live/admin/content_live/words.ex` - Word management
- `lib/medoru_web/live/admin/content_live/word_form.ex` - Add/edit words
- `lib/medoru_web/live/admin/content_live/lessons.ex`
- `lib/medoru_web/live/admin/classrooms_live.ex`
- `lib/medoru_web/live/admin/settings_live.ex`

**Key Features**:
- System stats (users, content, activity)
- **Vocabulary Management**:
  - List all words with search/filter
  - Add new word with kanji linkage
  - Edit word text, meaning, reading
  - Delete word with confirmation
  - Bulk import from CSV
- **Kanji Management**:
  - List all kanji (N1-N5 filter)
  - Add new kanji with meanings, readings, stroke count
  - Edit kanji details and readings
  - Delete kanji
  - Upload stroke data (SVG)
- Content CRUD for lessons
- Badge management
- Classroom oversight
- System settings

---

## 📊 Summary

**Completed**: 24/30 iterations (80%)

| Priority | Iterations | Status |
|----------|------------|--------|
| 🔴 High | 14 ✅, 15A ✅, 16 ✅, 18 ✅, 19 ✅, 20 ✅, 23 ✅, 25 ✅, 25B ✅, 26 ✅, 27 ✅, 28 ✅, 29 ✅ | 13 COMPLETE |
| 🔴 High | 30, 31 | 2 PENDING |
| 🟡 Medium | 13, 24 | 2 PENDING |
| 🟢 Lower | 21 | 1 PENDING |
| **Total** | **7** | **7-9 days est.** |

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

### Up Next 🔴
1. **Iteration 30** (Complete Test Taking) - Timer, results, auto-submit
2. **Iteration 31** (Teacher Custom Lessons) - Custom reading lessons for classrooms

Then MEDIUM priority items:
3. **Iteration 13** (Admin Badge Management)
4. **Iteration 24** (i18n Multi-Language)

Then MEDIUM priority items:
3. **Iteration 13** (Admin Badge Management)
4. **Iteration 24** (i18n Multi-Language)

### Future 🟡
14. **Iteration 13** (Admin Badge Management) - Admin features
15. **Iteration 24** (i18n Multi-Language) - Platform internationalization
16. **Iteration 21** (Admin Dashboard) - Admin polish

---

### Iteration 31: Teacher Custom Lessons
**Status**: ⏳ NOT STARTED | **Priority**: 🔴 HIGH | **Estimated**: 3-4 days  
**Log**: [ITERATION-31-teacher-custom-lessons.md](./ITERATION-31-teacher-custom-lessons.md)  
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

## 📁 Quick Links

- Full Plan: [ITERATION-PLAN-v0.1.0.md](./ITERATION-PLAN-v0.1.0.md)
- Roadmap: [ROADMAP.md](./ROADMAP.md)
- Main Index: [INDEX.md](./INDEX.md)
- Project Skills: [../skills/medoru/SKILL.md](../skills/medoru/SKILL.md)
