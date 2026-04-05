# AGENTS.md - Medoru Japanese Learning Platform

## Current State

**Version**: 0.1.5 ✅ COMPLETE  
**Status**: Word Sets feature implemented and ready for testing  
**Tests**: 630 passing (some flaky due to async DB locks)  
**URL**: https://medoru.net

### What's Complete (v0.1.5)
- Word Sets: User-created collections of up to 100 words
- Word Set management: Create, edit, delete, paginated list with search/sort
- Word selection: Autocomplete input for adding words
- Practice Tests: Configurable test generation per word set
- Routes: `/words/sets/*` with full CRUD

### What's Complete (v0.1.4)
- Grammar lesson system with pattern builder
- Sentence validation against grammar patterns
- Alternative forms for contracted Japanese (ない→な)
- ETS caching for 50x validation performance
- Admin progress reset feature

### What's Complete (v0.1.2)
- Daily test step type preferences
- Fix for unlearned words appearing in daily tests
- Public kanji/words access for anonymous users
- Anonymous language switching
- Word picture uploads (admin)

### What's Complete (v0.1.5) - Word Sets
**Status**: ✅ COMPLETE  
**Plan**: [.kimi/plans/zatanna-stature-rocket.md](/.kimi/plans/zatanna-stature-rocket.md)

**Features:**
- Word Sets: User-created collections of up to 100 words
- Word Set management: Create, edit, delete, paginated list with search/sort
- Word selection: Autocomplete input (reuse CustomLesson component)
- Word Set view: Display words with N1-N5 levels (reuse /words view)
- Practice Tests: Configurable test generation per word set
  - Select step types (word_to_meaning, word_to_reading, reading_text, image_to_meaning, kanji_writing)
  - Configure max steps per word (1-5, random per word)
  - Take practice tests (no points awarded)
  - Delete and recreate tests at any time

**Routes:** `/words/sets/*`

**Key Technical Changes:**
- Migration: `word_sets` and `word_set_words` tables
- Schemas: `WordSet`, `WordSetWord`
- Context: `Learning.WordSets` for CRUD and word management
- Generator: `Tests.WordSetTestGenerator` for practice test creation
- LiveViews: Index, Form, EditWords, Show, TestConfig

---

### What's Next (v0.2.0)
See [PLAN-v0.2.0.md](.agents/logs/PLAN-v0.2.0.md) for detailed planning.

**Epics:**
1. Real-time infrastructure (PubSub, Presence, Channels)
2. Game engine architecture (plugin-based)
3. Memory Cards game (first game type)
4. Real-time classroom chat
5. User tags & following system
6. User level system with XP
7. Badge system fixes

---

## Project Overview

**Medoru** is a social Japanese learning platform built with Phoenix LiveView.

**Core Features:**
- OAuth authentication (Google)
- Kanji database (N1-N5) with stroke data
- Word database cross-referenced to kanji and specific readings
- Lesson system (vocabulary + grammar)
- Multiple test types (multichoice, fill-in, kanji writing, text input)
- Daily review tests with SRS scheduling
- Classroom system (teachers, students, tests)
- Real-time learning games
- Rankings and leaderboards

**Tech Stack:**
- Elixir 1.17+, Phoenix 1.8+, LiveView 1.0+
- PostgreSQL with JSONB for flexible kanji data
- Google OAuth via Ueberauth
- Tailwind CSS for UI
- ETS caching for grammar validation

---

## Version History

### v0.1.5 - Word Sets (2026-04-05)
**Status**: ✅ COMPLETE

**Features:**
- Word Sets: User-created collections of up to 100 words for focused study
- Word Set CRUD: Create, edit, delete with pagination, search, and sorting
- Word management: Add/remove words via autocomplete, reorder with up/down buttons
- Word Set view: Display words with N1-N5 proficiency levels
- Practice Tests: Configurable tests per word set
  - Selectable question types (word_to_meaning, word_to_reading, reading_text, image_to_meaning, kanji_writing)
  - Random 1-5 questions per word from selected types
  - No points awarded - pure practice
  - Hard-delete and recreate at any time

**Routes:** `/words/sets/*`

**Key Technical Changes:**
- Migration: `word_sets` and `word_set_words` tables
- Schemas: `WordSet`, `WordSetWord` with validations
- Context: `Learning.WordSets` for CRUD, word management, and test generation
- Generator: `Tests.WordSetTestGenerator` for configurable practice test creation
- LiveViews: Index, Form, EditWords, Show, TestConfig
- Router: Added `/words/sets` nested routes
- Navigation: Added "My Word Sets" link from `/words`

---

### v0.1.4 - Grammar Lessons (2026-03-31)
**Status**: ✅ COMPLETE

**Features:**
- Grammar lesson creation by teachers with pattern builder
- Sentence validation against grammar patterns
- Alternative forms support for contracted Japanese (e.g., 来ない→来な)
- Admin progress reset ("Danger Zone" in user edit)
- ETS caching for 50x validation performance improvement

**Key Technical Changes:**
- Migration: Added `alternative_forms` array to `word_conjugations` with GIN index
- Schema: Updated `WordConjugation` with `alternative_forms` field
- Cache: `ValidatorCache` preloads alternatives as lookup keys
- Validator: `Grammar.Validator` checks main and alternative forms
- Conjugations: 66,396 verb conjugations updated with alternative forms

**Log**: [ITERATION-GRAMMAR-STUDENT-TAKING.md](.agents/logs/ITERATION-GRAMMAR-STUDENT-TAKING.md)

### v0.1.2 - Small Improvements (2026-03-20)
**Status**: ✅ COMPLETE

**Features:**
- Daily test step type preferences (user-configurable)
- Fix for unlearned words appearing in daily tests
- Public kanji/words access for anonymous users
- Anonymous language switching (header selector)
- Word picture uploads (1-3 images per word)

**Log**: [PLAN-v0.1.2.md](.agents/logs/PLAN-v0.1.2.md)

### v0.1.0 - MVP (2026-03-18)
**Status**: ✅ RELEASED  
**Live**: https://medoru.net

**Iterations 1-7 (Core MVP):**
- OAuth & Accounts
- Kanji & Readings (N5-N1)
- Words with Reading Links
- Lessons (300 topic-based)
- Learning Core (progress, streaks)
- Daily Reviews & SRS
- Polish & Integration

**Iterations 8-21 (Extended MVP):**
- User types (student/teacher/admin)
- Enhanced Profiles
- Badge System
- Logging Infrastructure
- Multi-Step Test System
- Auto-Generated Daily Tests
- Vocabulary Lesson System
- Kanji Writing Tests
- Reading Text Input
- Classroom Core
- Classroom Membership
- Classroom Tests & Rankings
- Teacher Test Creation
- Admin Dashboard
- i18n (Bulgarian/Japanese)
- UI Polish & Mobile
- Deployment & Production

---

## Recent Changes

### 2026-03-31 - Grammar v0.1.4 Complete
- Grammar lesson system with pattern validation
- Alternative forms for contracted Japanese (ない→な)
- 66,396 verb conjugations updated
- Admin progress reset feature
- 50x performance improvement with ETS caching

### 2026-03-26 - Grammar Validator Performance Optimization
- Implemented ETS-based caching for Grammar Validator
- Reduced validation time from 2500ms+ to ~50ms per sentence
- Cache key structure: `{:conjugation, text, word_type, allowed_forms, field_type}`
- Lazy loading per word type

### 2026-03-20 - v0.1.2 Complete
- Daily test preferences
- Public access fixes
- Word picture uploads

---

## Domain Architecture (Contexts)

### 1. Accounts Context (`lib/medoru/accounts/`)
**Responsibility:** User management, authentication, profiles

**Key Schemas:**
- `User` - OAuth data, profile, settings
- `UserProfile` - Display name, avatar, preferences
- `UserStats` - Aggregate stats (total learned, streak, etc.)

**Key Functions:**
- `register_user_with_oauth/1` - Google OAuth flow
- `get_user_by_email/1`, `get_user!/1`
- `update_profile/2`, `update_settings/2`

### 2. Content Context (`lib/medoru/content/`)
**Responsibility:** Kanji, readings, words, lessons - the learning material

**Key Schemas:**
- `Kanji` - Character, meanings, stroke count, JLPT level, stroke order data
- `KanjiReading` - Individual reading (on/kun) with type, romaji, and usage notes
- `Word` - Word text, meaning, difficulty, associated kanji
- `WordKanji` - Join table linking words to specific kanji AND specific readings
- `Lesson` - Title, description, ordered kanji list, difficulty
- `GrammarLesson` - Grammar patterns for validation
- `GrammarPattern` - Individual grammar patterns
- `WordConjugation` - Verb conjugations with alternative forms

**Key Functions:**
- `list_kanji_by_level/1` - Filter by N1-N5
- `get_word_with_readings/1` - Load word with kanji and their specific readings used
- `create_lesson/1`, `list_lessons/0`, `get_lesson!/1`

**Data Relationships:**
```
Kanji (id, character, meanings[], stroke_count, jlpt_level, stroke_data)
  ↓ (has many)
KanjiReading (id, kanji_id, reading_type, reading, romaji, usage_notes)
  ↓ (referenced by)
WordKanji (word_id, kanji_id, kanji_reading_id, position)
  ↓ (belongs to)
Word (id, text, meaning, difficulty, usage_frequency)
```

**Critical Design:**
- `kanji_readings` table stores each reading separately (e.g., "日" has 4 readings: ニチ, ジツ, ひ, か)
- `word_kanjis` table references BOTH the kanji AND the specific reading used
- This allows words to correctly link to which reading they use (e.g., "日本" uses ニチ not ジツ)
- `word_conjugations.alternative_forms` handles contracted forms (e.g., 来ない→来な)

### 3. Learning Context (`lib/medoru/learning/`)
**Responsibility:** User progress, lessons, daily reviews, SRS scheduling

**Key Schemas:**
- `UserProgress` - Which kanji/words user has learned, mastery level
- `LessonProgress` - Started/completed lessons, completion date
- `DailyStreak` - Streak tracking, last study date
- `ReviewSchedule` - SRS data (next review, interval, ease factor)

**Key Functions:**
- `start_lesson/2` - Begin lesson for user
- `complete_lesson/2` - Finish lesson, update progress
- `generate_daily_review/1` - Get due reviews + new words for daily study
- `update_streak/1` - Update streak logic
- `record_review/3` - Record SRS review with SM-2 algorithm

### 4. Tests Context (`lib/medoru/tests/`)
**Responsibility:** Multi-step test system for assessments and daily reviews

**Key Schemas:**
- `Test` - Test definition (daily, lesson, teacher, practice types)
- `TestStep` - Individual questions within a test
- `TestSession` - User's attempt at a test (tracks progress step-by-step)
- `TestStepAnswer` - User's answer to a specific step

**Test Types:**
- `:daily` - Auto-generated daily review test
- `:lesson` - Test at the end of a lesson
- `:teacher` - Custom test created by teachers
- `:practice` - Self-practice test

**Step Types:**
- `:reading`, `:writing`, `:listening`, `:grammar`, `:speaking`, `:vocabulary`

**Question Types:**
- `:multichoice` - Multiple choice (1 point)
- `:fill` - Fill in the blank (2 points)
- `:match` - Matching pairs (2 points)
- `:order` - Put in correct order (2 points)
- `:reading_text` - Text input (2 points)
- `:writing` - Kanji drawing (5 points)

**Key Functions:**
- `create_test/1`, `publish_test/1` - Test management
- `create_test_step/2`, `create_test_steps/2` - Add questions
- `start_test_session/2` - Begin taking a test
- `record_step_answer/3` - Submit answer with auto-scoring
- `complete_session/4` - Finish test and calculate score
- `get_user_test_stats/1`, `get_test_stats/1` - Analytics

**Scoring & Penalties:**
- Base points based on question type
- -25% per extra attempt beyond first
- -10% per hint used
- Minimum 10% of base points if correct

### 5. Classroom Context (`lib/medoru/classrooms/`)
**Responsibility:** Classroom management, memberships, tests

**Key Schemas:**
- `Classroom` - Name, slug, invite code, teacher
- `ClassroomMembership` - Student applications, status workflow
- `ClassroomTest` - Tests published to classrooms
- `ClassroomTestAttempt` - Student test attempts with points

**Key Functions:**
- `create_classroom/1` - Create with auto-generated slug and invite code
- `join_classroom/2` - Student application workflow
- `approve_membership/2`, `reject_membership/2` - Teacher moderation
- `publish_test_to_classroom/2` - Make test available to students
- `record_test_attempt/3` - Track completion and points

### 6. Gamification Context (`lib/medoru/gamification/`)
**Responsibility:** Scores, achievements, leaderboards

**Key Schemas:**
- `Score` - XP, level, category breakdown
- `Achievement` - Unlockable achievements
- `UserAchievement` - Join table with unlock date
- `LeaderboardEntry` - Cached rankings

### 7. Grammar Context (`lib/medoru/grammar/`)
**Responsibility:** Grammar validation and pattern matching

**Key Modules:**
- `Grammar.Validator` - Validates sentences against patterns
- `Grammar.ValidatorCache` - ETS cache for O(1) lookups
- `Grammar.Pattern` - Pattern component representation

**Key Features:**
- Pattern validation with word type matching
- Alternative forms support (contracted Japanese)
- ETS caching for performance (50x improvement)

---

## Critical Business Rules

### Learning Algorithm
- **New Lesson:** User must complete previous lesson OR placement test
- **Daily Test:** SRS-based review (words due for review) + 5 new words if available
- **Mastery Levels:** 
  - 0: New
  - 1-3: Learning (review intervals: 1d, 3d, 7d)
  - 4: Mastered (review interval: 30d)
- **Streak:** Break if no daily test completed by 23:59 user timezone

### Duel Fairness
- **Question Pool:** Intersection of both users' learned words
- **Minimum Pool:** If intersection < 10, use learned words of less advanced user
- **Difficulty:** Match average difficulty of both players
- **Ranking:** ELO system, K-factor 32, starting rating 1000

### Data Integrity
- **Kanji Uniqueness:** Character field unique, validate Unicode range
- **Word Readings:** Must reference valid kanji_reading records
- **Progress Tracking:** Immutable history, no deletion of test records

---

## Phoenix Conventions (Strict)

### Context Pattern
```
lib/medoru/accounts.ex          # Public API
lib/medoru/accounts/
  ├── user.ex                   # Schema + changesets
  ├── user_profile.ex
  └── user_stats.ex
```

### LiveView Structure
```
lib/medoru_web/live/
├── dashboard_live.ex           # Main learning dashboard
├── lesson_live/
│   ├── index.ex               # Lesson list
│   ├── show.ex                # Individual lesson
│   └── test.ex                # Lesson test mode
├── classroom_live/
│   ├── index.ex               # Student classrooms
│   ├── show.ex                # Classroom detail
│   └── test.ex                # Taking tests
├── teacher/
│   ├── classroom_live/        # Teacher management
│   └── test_live/             # Test creation
└── admin/
    ├── user_live.ex           # User management
    ├── kanji_live.ex          # Kanji management
    ├── word_live.ex           # Word management
    └── lesson_live.ex         # Lesson management
```

### Testing Requirements
- **Unit:** Context functions with sandbox
- **Integration:** LiveView tests with `PhoenixTest`
- **Factories:** ExMachina for User, Kanji, Word generation
- **Coverage:** 80%+ for contexts, 60%+ for LiveView

---

## Japanese Data Handling

### Kanji Storage
```elixir
%Kanji{
  character: "日",
  meanings: ["sun", "day", "Japan"],
  stroke_count: 4,
  jlpt_level: 5,
  stroke_data: %{svg: "...", paths: [...]}, # JSONB
  radicals: ["日"],
  frequency: 1
}
```

### KanjiReading Storage
```elixir
%KanjiReading{
  kanji_id: 1,
  reading_type: :on,  # :on or :kun
  reading: "ニチ",    # Katakana for on, hiragana for kun
  romaji: "nichi",
  usage_notes: "Used in compound words, formal readings"
}
```

### Word Storage with Reading Links
```elixir
%Word{
  text: "日本",
  meaning: "Japan",
  difficulty: 5,
  word_kanjis: [
    %WordKanji{
      position: 0,
      kanji: %Kanji{character: "日"},
      kanji_reading: %KanjiReading{reading: "ニチ", reading_type: :on}
    },
    %WordKanji{
      position: 1,
      kanji: %Kanji{character: "本"},
      kanji_reading: %KanjiReading{reading: "ホン", reading_type: :on}
    }
  ]
}
```

### Word Conjugations with Alternative Forms
```elixir
%WordConjugation{
  word_id: 1,
  grammar_form_id: 1,
  conjugated_form: "来ない",      # Full nai-form
  alternative_forms: ["来な"],     # Contracted form for combining
  reading: "こない"
}
```

### Word Reading Logic
Words store full reading in hiragana, but derive from specific kanji_reading records:
- "日本" -> reading "にほん" (from 日=ニチ + 本=ホン)
- System validates that word references valid kanji_reading IDs
- This ensures the reading shown matches the actual kanji readings used

---

## Development Workflow

### Database Seeding
```bash
mix run priv/repo/seeds.exs
```
Loads N5-N4 kanji, their readings, and ~500 common words with proper reading references from JSON files.

### Daily Operations
```bash
mix phx.server                    # Dev server
mix test                          # Full test suite
mix test.watch                    # Auto-run on changes
iex -S mix phx.server             # Interactive dev
```

### Code Quality Gates (Pre-Commit)
```bash
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

---

## Kimi-Specific Instructions

### When Implementing Features:
1. **Start with Context:** Write schema + migration + context functions first
2. **Test Context:** Write unit tests for all public functions
3. **Build LiveView:** Create LiveView with mount/render/handle_event
4. **Test LiveView:** Use `PhoenixTest` for user flows
5. **Verify:** Run full test suite, fix any failures

### For Japanese Content:
- **NEVER** hardcode kanji in tests (use fixtures)
- **ALWAYS** validate Unicode: kanji must be in CJK Unified Ideographs range
- **CONSIDER** font rendering: test with common Japanese fonts
- **ENSURE** kanji_readings are properly linked in word_kanjis

### For Duels (Real-time):
- Use `Phoenix.PubSub` for broadcasting duel state
- Handle disconnects gracefully (pause/resume)
- Validate all inputs server-side (prevent cheating)

### When Adding Migrations:
- Provide `up` AND `down` functions
- Use `execute/1` for complex SQL with safety checks
- Never modify existing migrations that are deployed

---

## File Locations Quick Reference

| Type | Path |
|------|------|
| Contexts | `lib/medoru/{context}.ex` + `lib/medoru/{context}/` |
| LiveViews | `lib/medoru_web/live/*_live.ex` |
| Components | `lib/medoru_web/components/` |
| Tests | `test/medoru/{context}_test.exs`, `test/medoru_web/live/*_test.exs` |
| Seeds | `priv/repo/seeds/` |
| Static assets | `priv/static/` |
| Config | `config/runtime.exs` (env vars) |
| Logs | `.agents/logs/` |
| Skills | `.agents/skills/` |

---

## Project Guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 Guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your custom classes must fully style the input

### JS and CSS Guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

### UI/UX & Design Guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions

---

## Boundaries

- ✅ **Always:** Run full test suite before claiming complete
- ✅ **Always:** Use changesets for data validation
- ✅ **Always:** Add indexes on foreign keys and frequently queried fields
- ✅ **Always:** Ensure word_kanjis references valid kanji_reading records
- ⚠️ **Ask first:** New dependencies, OAuth provider changes, database schema changes affecting existing data
- 🚫 **Never:** Store OAuth secrets in code, modify user progress history directly, skip database transactions for multi-step operations
- 🚫 **Never:** Allow orphaned kanji_readings or word_kanjis without proper references

---

## Additional Resources

### QA Testing with Playwright
The project includes a comprehensive E2E testing suite in the `/qa` directory using Playwright.

```bash
bin/qa setup       # Setup QA environment
bin/qa server      # Start QA server (port 4001)
bin/qa test        # Run all tests
bin/qa test:ui     # UI mode for debugging
```

See `qa/README.md` for full documentation.

### Logs and Planning
- **Current State**: See top of this file
- **v0.2.0 Plan**: [.agents/logs/PLAN-v0.2.0.md](.agents/logs/PLAN-v0.2.0.md)
- **Iteration Logs**: [.agents/logs/ITERATION-*.md](.agents/logs/)
- **Skills**: [.agents/skills/](.agents/skills/)

---

<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->


<!-- phoenix:elixir-start -->
## phoenix:elixir usage
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages


<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it

<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## phoenix:ecto usage
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programmatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied

<!-- phoenix:ecto-end -->

<!-- phoenix:html-start -->
## phoenix:html usage
[phoenix:html usage rules](deps/phoenix/usage-rules/html.md)
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## phoenix:liveview usage
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView.
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`)
when writing scripts inside the template**:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the
LiveSocket constructor:

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle.
**Always** return or rebind the socket on `push_event/3` when pushing events:

    # re-bind socket so we maintain event state to be pushed
    socket = push_event(socket, "my_event", %{...})

    # or return the modified socket directly:
    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`:

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

Where the server handled it via:

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset

<!-- phoenix:liveview-end -->

## QA Testing with Playwright

The project includes a comprehensive E2E testing suite in the `/qa` directory using Playwright.

### Quick Start

```bash
# Setup everything (one-time)
bin/qa setup

# Start QA server (runs on port 4001, separate from dev on 4000)
bin/qa server

# In another terminal, run tests
bin/qa test

# Or use UI mode for debugging
bin/qa test:ui
```

### QA Environment

- **Port**: 4001 (dev runs on 4000 simultaneously)
- **Database**: `medoru_qa` (isolated from dev/test/prod)
- **Config**: `config/qa.exs`
- **Auth**: OAuth bypass for test users (via `/qa/bypass`)

### Test Users (Pre-seeded)

| Email | Type | Description |
|-------|------|-------------|
| `admin@qa.test` | admin | Full admin access |
| `teacher@qa.test` | teacher | Teacher with classrooms |
| `student@qa.test` | student | Regular student |
| `studentadvanced@qa.test` | student | Advanced (50 lessons, 15-day streak) |
| `studentnew@qa.test` | student | New student (3 lessons) |

See `qa/fixtures/users.ts` for all 18 test users.

### Writing QA Scenarios

1. Create a file in `qa/scenarios/`:
```typescript
import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

test('description', async ({ page }) => {
  const auth = createAuthHelper(page);
  await auth.login(TEST_USERS.student);
  await navigateTo(page, 'dashboard');
  await expect(page.locator('h1')).toContainText('Dashboard');
});
```

2. Run the test:
```bash
npx playwright test scenarios/my-test.spec.ts --headed
```

### QA Commands

```bash
bin/qa setup       # Setup QA environment
bin/qa server      # Start QA server
bin/qa test        # Run all tests
bin/qa test:ui     # UI mode for debugging
bin/qa seed        # Reseed test data
bin/qa reset       # Reset DB and reseed
```

### Mix Aliases

```bash
mix qa.setup       # Setup DB and seed
mix qa.seed        # Just seed data
mix ecto.qa        # Create/migrate QA DB
mix ecto.reset.qa  # Reset QA DB
```

See `qa/README.md` for full documentation.

<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps/usage_rules/usage-rules/elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
