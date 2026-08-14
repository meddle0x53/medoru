# AGENTS.md - Medoru Japanese Learning Platform

> **⚠️ Multi-agent workspace rule for all agents:** This project uses multiple concurrent agents. The working directory is shared state. **Never revert, delete, or overwrite files you did not create or were not explicitly asked to modify.** Uncommitted changes likely belong to another agent. If you are unsure whether a change is yours, check with the user before touching it.

## Current State

**Version**: 0.10.0 ✅ IMPLEMENTED  
**Status**: 0.10.0 adds **Word Books** — user-created vocabulary card books built from word sets or custom words, with a configurable card designer (front/back content: meanings/examples in en/bg/ja, reading, picture, sound, N-level, frequency, optional word text on the back), preset backgrounds/covers (covers and word images usable as card backgrounds), daisyUI themes, square (strict 1:1, content clipped) and rectangle (grows with content) card shapes, a paged book viewer with flip cards (1/2/4/6 per page, uniform card sizes), and PNG download of card faces (with medoru.net branding on every card). Entry points from word sets and the word detail page.  
**Tests**: 1887 passing  
**URL**: https://medoru.net

### Alpha Game Release Plan
User-confirmed plan for the first alpha of **The Hollow Ouroboros** (admin game at `/admin/game`):

1. **JSON-driven foundation** — systems and data already support weapons, enemies, hero, abilities, and charm families via JSON.
2. **Finish the Level 1 map** — make all tile events functional (cascade ✅, memory, shop, rest, events, etc.) and make map visuals configurable from JSON.
3. **Profile reward** — the win condition should give something to the current user profile on the site.
4. **Hero selection / preparation screen** — let the player spend site XP and in-game WIN tokens to start a stronger run.
5. **More enemies / second hero** — nice-to-have, possibly post-alpha.
6. **Public copy + admin copy ✅** — `/the-hollow-ouroboros` is live as the 5th daily challenge (`ouroboros_run`). Daily runs auto-abandon any active saved run, then award site XP = `100 × Ouro Essence earned` on run end and update the streak via `Learning.complete_daily_challenge/4`. The admin `/admin/game` version remains for parallel development.
7. **Alpha ending** — level 1 map finishes in a meaningful way; alpha has only one level, later levels built in the admin version.

Weapon/shield socket charms and slot unlock schedule are considered good enough for alpha. Work on them is paused.

### Game Asset Guidelines (The Hollow Ouroboros)

**Enemy sprite target size:** `512×768` pixels.

- Older sprites were authored at `1024×1536` and caused heavy memory use / poor tablet performance.
- New enemy sprites should be exported/rendered at `512×768` from the start.
- The `scale` in the enemy JSON `layout` block must be doubled relative to the old `1024×1536` sizing (e.g. `0.5` instead of `0.25`) because Phaser multiplies `scale` against source pixels.
- If a higher-resolution original is received, resize it to `512×768` with ImageMagick/Photoshop and keep the full-resolution original in `priv/static/images/game/hires/` as a backup. The game only loads sprites referenced by enemy definitions, so `hires/` copies are not loaded.
- Portraits and icons can stay at their existing smaller sizes.

### Paused for Alpha — Weapon/Shield Socket 1 Family Abilities
The reward-pool family map is JSON-driven (`assets/js/game/data/abilityFamilies.json`). These abilities are **not required for the alpha** and are parked here for later:

1. **Shield Socket 1 families** (no abilities yet): `sturdy`, `warding`, `luck_guard`.
2. **Weapon Socket 1 families** (no abilities yet): `water`, `earth`, `poison`, `dark`, `light`, `luck` (wind is done with `gale_strike`).

For each ability, add a new entry in `assets/js/game/data/abilities/warrior.json` with `requiredCharmFamily` set and the family → ability mapping in `assets/js/game/data/abilityFamilies.json`.

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
- End-to-end encrypted chat, social following, white board, and link previews

**Tech Stack:**
- Elixir 1.17+, Phoenix 1.8+, LiveView 1.0+
- PostgreSQL with JSONB for flexible kanji data
- Google OAuth via Ueberauth
- Tailwind CSS for UI
- ETS caching for grammar validation

## Version History (Summary)

| Version | Focus |
|---------|-------|
| 0.10.0 | Word Books (vocabulary cards): creation from word sets/custom words, card designer, book viewer, PNG export |
| 0.9.4 | Chat media folder fixes (classroom crash, single-audio playback) and ongoing 0.9.x stabilization |
| 0.9.0 | Release stabilization and regression fixes |
| 0.8.x | Link previews, English-learning mode, admin impersonation, game meta-progression, classroom/test polish, kanji fixes |
| 0.7.x | Grammar definitions, learned grammar tracking, game map/events, cascade/memory tiles, socket charms |
| 0.6.0 | Classroom & chat themes, AI word enrichment, writing fill-in steps |
| 0.5.x | Grammar lessons, user white board, kanji data overhaul |
| 0.4.x | Block/following logic, profile privacy, classroom rankings |
| 0.3.x | Social, XP system, level badges, chat polish, daily challenges |
| 0.2.x | Chat, user directory, E2E encryption, word sets |
| 0.1.x | Core MVP: auth, kanji, words, lessons, tests, classrooms |

Detailed iteration logs live in `.agents/logs/`.

## Domain Architecture (Contexts)

### 1. Accounts Context (`lib/medoru/accounts/`)
**Responsibility:** User management, authentication, profiles

**Key Schemas:** `User`, `UserProfile`, `UserStats`

**Key Functions:**
- `register_user_with_oauth/1` - Google OAuth flow
- `get_user_by_email/1`, `get_user!/1`
- `update_profile/2`, `update_settings/2`
- `add_xp/3` - XP awards with audit logging

### 2. Content Context (`lib/medoru/content/`)
**Responsibility:** Kanji, readings, words, lessons, grammar definitions

**Key Schemas:** `Kanji`, `KanjiReading`, `Word`, `WordKanji`, `Lesson`, `GrammarDefinition`, `WordConjugation`

**Critical Design:**
- `kanji_readings` stores each reading separately.
- `word_kanjis` references BOTH the kanji AND the specific reading used.
- `word_conjugations.alternative_forms` handles contracted forms (e.g., 来ない→来な).

### 3. Learning Context (`lib/medoru/learning/`)
**Responsibility:** User progress, lessons, daily reviews, SRS scheduling

**Key Functions:**
- `start_lesson/2`, `complete_lesson/2`
- `generate_daily_review/1`
- `update_streak/1`, `record_review/3`
- `complete_daily_challenge/4`

### 4. Tests Context (`lib/medoru/tests/`)
**Responsibility:** Multi-step test system

**Key Schemas:** `Test`, `TestStep`, `TestSession`, `TestStepAnswer`

### 5. Classroom Context (`lib/medoru/classrooms/`)
**Responsibility:** Classroom management, memberships, tests

**Key Schemas:** `Classroom`, `ClassroomMembership`, `ClassroomTest`, `ClassroomTestAttempt`

### 6. Gamification Context (`lib/medoru/gamification/`)
**Responsibility:** Scores, achievements, leaderboards, badges

### 7. Grammar Context (`lib/medoru/grammar/`)
**Responsibility:** Grammar validation and pattern matching

**Key Modules:** `Grammar.Validator`, `Grammar.ValidatorCache`, `Grammar.Pattern`

### 8. Social Context (`lib/medoru/social/`)
**Responsibility:** User directory, search, blocking, following, tags

### 9. Chat Context (`lib/medoru/chat/`)
**Responsibility:** Conversations, messages, file uploads, reactions, E2E encryption

### 10. White Board Context (`lib/medoru/white_board/`)
**Responsibility:** Posts, comments, reactions, canvas drawings

## Critical Business Rules

### Learning Algorithm
- **New Lesson:** User must complete previous lesson OR placement test
- **Daily Test:** SRS-based review + new words up to the daily goal
- **Mastery Levels:** 0 new → 1-3 learning → 4 mastered
- **Streak:** Breaks if no daily test completed by 23:59 user timezone

### Data Integrity
- **Kanji Uniqueness:** Character field unique, validate Unicode range
- **Word Readings:** Must reference valid `kanji_reading` records
- **Progress Tracking:** Immutable history, no deletion of test records

## Development Workflow

### Database Seeding
```bash
mix run priv/repo/seeds.exs
```

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
├── dashboard_live.ex
├── lesson_live/
├── classroom_live/
├── teacher/
└── admin/
```

### Phoenix v1.8 Guidelines
- **Always** begin LiveView templates with `<Layouts.app flash={@flash} ...>`
- The `MyAppWeb.Layouts` module is aliased in `my_app_web.ex`; use it without re-aliasing
- Fix `current_scope` errors by using the proper `live_session` and passing `current_scope`
- `<.flash_group>` belongs **only** in `layouts.ex`
- Use the `<.icon>` component for icons; never use `Heroicons` modules directly
- **Always** use the imported `<.input>` component from `core_components.ex`
- Forms must be driven by a `to_form/2` assign; never pass a changeset to `<.form>`

### LiveView Streams
- Use streams for all collections
- `stream(socket, :messages, [new_msg])`
- `stream(socket, :messages, items, reset: true)` to filter/refresh
- Streams are not enumerable; track counts/empty states with separate assigns

### LiveView JavaScript Interop
- Use colocated hooks (`:type={Phoenix.LiveView.ColocatedHook}`) for inline scripts; names must start with `.`
- External hooks go in `assets/js/` and are passed to `LiveSocket`
- Use `push_event/3` to send data to the client; always rebind the socket

## JS and CSS Guidelines

- Use Tailwind CSS classes and custom CSS for polished, responsive interfaces.
- Tailwindcss v4 import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Never** use `@apply` when writing raw CSS.
- **Always** write your own Tailwind-based components instead of using daisyUI.
- Only `app.js` and `app.css` bundles are supported. Import vendor deps into them.
- **Never** write inline `<script>` tags in templates.

## UI/UX & Design Guidelines

- Produce world-class UI with focus on usability and modern design
- Implement subtle micro-interactions and smooth transitions
- Ensure clean typography, spacing, and layout balance
- Focus on delightful details: hover effects, loading states, smooth transitions

## Kimi-Specific Instructions

### When Implementing Features:
1. Start with Context: schema + migration + context functions
2. Test context with unit tests
3. Build LiveView
4. Test LiveView with `PhoenixTest`
5. Run the full test suite

### For Japanese Content:
- **NEVER** hardcode kanji in tests (use fixtures)
- Validate Unicode: kanji must be in CJK Unified Ideographs range
- Ensure `word_kanjis` references valid `kanji_reading` records

### For Real-time Features:
- Use `Phoenix.PubSub` for broadcasting state
- Handle disconnects gracefully
- Validate all inputs server-side

### When Adding Migrations:
- Provide `up` AND `down` functions
- Use `execute/1` for complex SQL with safety checks
- Never modify deployed migrations

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

## Boundaries

- ✅ **Always:** Run full test suite before claiming complete
- ✅ **Always:** Use changesets for data validation
- ✅ **Always:** Add indexes on foreign keys and frequently queried fields
- ✅ **Always:** Ensure `word_kanjis` references valid `kanji_reading` records
- ✅ **Always:** Follow the Elixir/BEAM "let it crash" principle — prefer explicit failure and supervision over defensive coding that hides errors
- ⚠️ **Ask first:** New dependencies, OAuth provider changes, schema changes affecting existing data
- 🚫 **Never:** Store OAuth secrets in code, modify user progress history directly, skip transactions for multi-step operations
- 🚫 **Never:** Allow orphaned `kanji_readings` or `word_kanjis`

## QA Testing with Playwright

The project includes an E2E suite in `/qa`.

```bash
bin/qa setup       # Setup QA environment
bin/qa server      # Start QA server (port 4001)
bin/qa test        # Run all tests
bin/qa test:ui     # UI mode for debugging
```

See `qa/README.md` for full documentation.
