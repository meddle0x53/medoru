---
description: Medoru Japanese learning platform - Elixir/Phoenix conventions, kanji schema design, and development workflow
---

# AGENTS.md - Medoru Japanese Learning Platform

## Project Overview
**Medoru** is a social Japanese learning platform built with Phoenix LiveView.

**Core Features (V1):**
- OAuth authentication (Google)
- Kanji database (N1-N5) with stroke data
- Word database cross-referenced to kanji and specific readings
- Lesson system (1-3 kanji per lesson)
- Multiple-choice testing (meaning/reading/kanji)
- Daily review tests with streak tracking
- Real-time learning duels between users
- Rankings and duel history

**Tech Stack:**
- Elixir 1.17+, Phoenix 1.8+, LiveView 1.0+
- PostgreSQL with JSONB for flexible kanji data
- Google OAuth via Ueberauth
- Tailwind CSS for UI
- Canvas API for future stroke drawing

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

### 3. Learning Context (`lib/medoru/learning/`)
**Responsibility:** User progress, lessons, tests, daily reviews

**Key Schemas:**
- `UserProgress` - Which kanji/words user has learned, mastery level
- `LessonProgress` - Started/completed lessons, completion date
- `TestSession` - Individual test attempt (score, duration, answers)
- `TestAnswer` - Specific answer to a question
- `DailyStreak` - Streak tracking, last study date
- `ReviewSchedule` - SRS data (next review, interval, ease factor)

**Key Functions:**
- `start_lesson/2` - Begin lesson for user
- `complete_lesson/2` - Finish lesson, update progress
- `generate_daily_test/1` - Create review test based on SRS
- `submit_test_answer/3` - Record answer, update mastery
- `calculate_streak/1` - Update streak logic

**Test Configuration:**
- Options count: 4-8 (configurable per user)
- Question types: 
  - `meaning_to_kanji` (show meaning, pick kanji)
  - `reading_to_kanji` (show reading, pick kanji)
  - `kanji_to_meaning` (show kanji, pick meaning)
  - `kanji_to_reading` (show kanji, pick reading)

### 4. Duels Context (`lib/medoru/duels/`)
**Responsibility:** Real-time duels, matchmaking, rankings

**Key Schemas:**
- `Duel` - Challenger, opponent, status, start/end time, duration
- `DuelQuestion` - Questions generated for this duel
- `DuelAnswer` - Each player's answer with timing
- `DuelResult` - Final scores, winner, XP gained
- `Ranking` - ELO or point-based ranking system

**Key Functions:**
- `create_duel_invite/2` - Send duel request
- `accept_duel/2` - Start duel, generate questions
- `submit_duel_answer/3` - Real-time answer submission
- `finish_duel/1` - Calculate winner, update rankings
- `get_rankings/1` - Leaderboard

**Duel Logic:**
1. Find common learned words between both users
2. If none, use lowest level words from less advanced user
3. Generate N questions (configurable, default 20)
4. Both players see same questions simultaneously
5. 5-minute timer (configurable)
6. Scoring: +10 correct, -5 wrong, +5 speed bonus (if < 5s)
7. Winner: highest score, tie-breaker: fastest average time

### 5. Gamification Context (`lib/medoru/gamification/`)
**Responsibility:** Scores, achievements, leaderboards

**Key Schemas:**
- `Score` - XP, level, category breakdown
- `Achievement` - Unlockable achievements
- `UserAchievement` - Join table with unlock date
- `LeaderboardEntry` - Cached rankings

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

## Database Schema Priorities

### Phase 1 (MVP)
1. Users + OAuth
2. Kanji + KanjiReadings (seed with N5-N4)
3. Words + WordKanjis (cross-referenced to specific readings)
4. Lessons (static, predefined)
5. UserProgress + TestSession
6. DailyStreak

### Phase 2 (Social)
7. Duels + Real-time answers
8. Rankings
9. User invites/friends

### Phase 3 (Advanced)
10. Stroke drawing data
11. Grammar content
12. Listening content

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
├── duel_live/
│   ├── lobby.ex               # Find opponents
│   ├── match.ex               # Active duel
│   └── results.ex             # Post-duel screen
└── user_live/
    ├── profile.ex
    └── settings.ex
```

### Testing Requirements
- **Unit:** Context functions with sandbox
- **Integration:** LiveView tests with `PhoenixTest`
- **Factories:** ExMachina for User, Kanji, Word generation
- **Coverage:** 80%+ for contexts, 60%+ for LiveView

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

### Word Reading Logic
Words store full reading in hiragana, but derive from specific kanji_reading records:
- "日本" -> reading "にほん" (from 日=ニチ + 本=ホン)
- System validates that word references valid kanji_reading IDs
- This ensures the reading shown matches the actual kanji readings used

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

## Additional Projects Context

This AGENTS.md covers the main Medoru platform. For related tools:

### Python Spider (Data Collection)
- Separate project, but follow same data schema
- Output JSON matching Kanji/KanjiReading/Word structure
- Store raw scraped data in `data/raw/` before processing

### Rust/Python Document Parser
- Input: PDFs, text files with Japanese content
- Output: Structured exercises in JSON
- Must validate against Medoru content schema

When working on these tools, reference this AGENTS.md for data structure requirements.

## Boundaries

- ✅ **Always:** Run full test suite before claiming complete
- ✅ **Always:** Use changesets for data validation
- ✅ **Always:** Add indexes on foreign keys and frequently queried fields
- ✅ **Always:** Ensure word_kanjis references valid kanji_reading records
- ⚠️ **Ask first:** New dependencies, OAuth provider changes, database schema changes affecting existing data
- 🚫 **Never:** Store OAuth secrets in code, modify user progress history directly, skip database transactions for multi-step operations
- 🚫 **Never:** Allow orphaned kanji_readings or word_kanjis without proper references



## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

### JS and CSS guidelines

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

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


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
