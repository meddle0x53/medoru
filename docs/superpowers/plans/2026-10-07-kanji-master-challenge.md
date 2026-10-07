# Kanji Master Challenge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A permanent "learner challenges" subsystem with its first challenge, Kanji Master — an infinite kanji-writing survival game (15 lives, per-run coin economy, shop, stroke upgrades) with a cross-user top-5 leaderboard.

**Architecture:** Server-side: a `Challenges` context with one `kanji_master_scores` table (one row per user, upsert semantics) plus two LiveViews (`/challenges` card page, `/challenges/kanji-master` game). Client-side: a new self-contained `KanjiMaster` JS hook adapted from the existing `kanji_writing.js` — all stroke validation, scoring, shop, and upgrade logic runs in the browser; only the final score and display identity are pushed to the server.

**Tech Stack:** Phoenix LiveView, Ecto/Postgres, vanilla JS canvas (KanjiVG `stroke_data` paths), Gettext (en/bg/ja), Tailwind CSS.

**Spec:** `docs/superpowers/specs/2026-10-07-kanji-master-challenge-design.md`

## Global Constraints

- The existing `assets/js/hooks/kanji_writing.js` and `MedoruWeb.LessonTestLive.WritingComponent` must NOT be modified (daily/lesson challenges keep identical behavior).
- DB migrations must have explicit `up` AND `down`, UUID PKs (`add :id, :binary_id, primary_key: true`), FK references `type: :binary_id`, indexes on FKs.
- All user-facing strings wrapped in `gettext`/`ngettext` immediately; bg/ja translations hand-filled in `priv/gettext/{bg,ja}/LC_MESSAGES/default.po` (do NOT run `mix gettext.extract`/`merge` — hand-add entries, minimal diff, leave other agents' entries untouched).
- Follow existing context layout: public API in `lib/medoru/challenges.ex`, schemas in `lib/medoru/challenges/`, LiveViews in `lib/medoru_web/live/`.
- Coins are fresh each run (start = site level, +1 per 5 completed kanji); NO XP awarded.
- Eligibility: ≥ 50 learned kanji (`user_progress` rows with `kanji_id` NOT NULL — count includes kanji without stroke_data; the drawable pool filters to `stroke_data["strokes"]` non-empty).
- Game-over score upsert: only override own row when the new score is higher; identity (linked/anonymous/name) may be changed on every record.
- Kanji pool passed to the client: character, `stroke_data`, `stroke_count` only (see `Challenges.kanji_master_pool/1`).
- Existing known-acceptable test failures: `Medoru.AI.WordEnrichmentTest "sends vibe prompt as instructions by default"`; timing-flaky LiveView tests that pass in isolation — re-run before assuming regression.
- No git commits unless the user explicitly asks (repo rule: multi-agent workspace).

## Review Focus

1. **Anonymous (not logged-in) visitor** on `/challenges/kanji-master` → sees the gate with a sign-in prompt, never the game. (Task 3 tests.)
2. **49 vs 50 learned kanji boundary** — 49 shows gate, 50 shows game. (Task 3 tests.)
3. **Lower score re-record** must NOT overwrite a higher stored score. (Task 1 tests.)
4. **Anonymous entry with blank name** must be rejected; anonymous renders plain text, linked renders a clickable `/users/:id` link. (Task 1 + Task 6 tests.)
5. **Kanji without stroke_data** must be excluded from the client pool (client parser would crash). (Task 1 tests.)
6. **Switching linked→anonymous** on re-record keeps one row per user (upsert by user_id, no duplicates). (Task 1 tests.)

---

### Task 1: Migration, schema, and `Challenges` context

**Files:**
- Create: `priv/repo/migrations/<timestamp>_create_kanji_master_scores.exs`
- Create: `lib/medoru/challenges/kanji_master_score.ex`
- Create: `lib/medoru/challenges.ex`
- Test: `test/medoru/challenges_test.exs`

**Interfaces:**
- Produces:
  - `Medoru.Challenges.KanjiMasterScore` schema: fields `user_id` (binary_id FK → users, on_delete: :delete_all), `score` :integer, `display_mode` :string (`"linked"` | `"anonymous"`), `anonymous_name` :string (nilable); unique constraint on `user_id`; validate `display_mode` inclusion and `anonymous_name` required when `display_mode == "anonymous"`.
  - `Challenges.learned_kanji_count/1` (`%User{}` → integer) — count of `user_progress` rows with non-nil `kanji_id` for the user.
  - `Challenges.eligible?/1` — `learned_kanji_count(user) >= 50`.
  - `Challenges.kanji_master_pool/1` (`%User{}` → list of maps `%{character: String.t(), stroke_data: map, stroke_count: integer}`) — learned kanji joined to `kanji`, filtering `not is_nil(k.stroke_data)` and non-empty `stroke_data["strokes"]`.
  - `Challenges.get_leaderboard/0` — top 5 by `score` desc, preloads `user: [:profile]`.
  - `Challenges.get_rank_and_score/1` (`user_id` → `%{rank: pos_integer, score: integer} | nil`) — rank = count of rows with higher score + 1.
  - `Challenges.record_score/2` (`%User{}`, attrs `%{score: int, display_mode: string, anonymous_name: string | nil}`) — upsert on `user_id`: if existing row exists and `existing.score >= new_score`, update only `display_mode`/`anonymous_name` (identity may change, score may not go down); otherwise update score too. Returns `{:ok, score}` / `{:error, changeset}`.

- [ ] **Step 1: Write the failing tests**

Cover: migration runs (implicit via test DB), `record_score` inserts and upserts; lower score does not override (Review Focus 3); identity switch linked→anonymous on re-record keeps one row (Review Focus 6); anonymous with blank `anonymous_name` rejected (Review Focus 4); `get_leaderboard/0` ordering and top-5 cutoff with 6 seeded users; `get_rank_and_score/1` for top, middle, and unranked users; `learned_kanji_count/1` and `eligible?/1` at the 49/50 boundary (Review Focus 2); `kanji_master_pool/1` excludes kanji with nil/empty `stroke_data` and returns character/stroke_data/stroke_count keys (Review Focus 5).

- [ ] **Step 2: Run tests, verify they fail**

Run: `mix test test/medoru/challenges_test.exs`
Expected: FAIL (module/file not found).

- [ ] **Step 3: Implement migration, schema, context**

Migration `create_kanji_master_scores` per Global Constraints, unique index on `:user_id`, index on `:score`. Context functions per Interfaces. For `kanji_master_pool`, query `UserProgress` where `user_id` and not nil `kanji_id`, join `Kanji`, select the map. Reuse fixture patterns from `test/medoru/learning_test.exs` for creating users/kanji/progress rows.

- [ ] **Step 4: Run tests, verify they pass**

Run: `mix test test/medoru/challenges_test.exs`
Expected: PASS.

- [ ] **Step 5: `mix format` the new files.**

---

### Task 2: `/challenges` page

**Files:**
- Create: `lib/medoru_web/live/challenges_live.ex`
- Modify: `lib/medoru_web/router.ex` (add route inside the authenticated app scope, next to `/daily-challenges`)
- Modify: `lib/medoru_web/live/dashboard_live.html.heex` (add "Learner Challenges" link near the daily-challenges link at ~line 48)
- Test: `test/medoru_web/live/challenges_live_test.exs`

**Interfaces:**
- Consumes: `Challenges.get_leaderboard/0`, `Challenges.get_rank_and_score/1` (Task 1).
- Produces: route `live "/challenges", ChallengesLive, :index`; assigns `:leaderboard` (top-5 list), `:my_rank` (`%{rank:, score:}` or nil).

- [ ] **Step 1: Write the failing tests**

Test: page renders heading; Kanji Master card present with title/description; with 6 seeded scores the card lists exactly 5 entries in descending order; a linked entry shows an `<a>` to `/users/<id>`; an anonymous entry shows plain text with no link; logged-in user with a score outside top 5 sees "your rank" `#N` (Review Focus 4, spec: rank display); logged-in user with no score sees no rank line.

- [ ] **Step 2: Run tests, verify they fail**

Run: `mix test test/medoru_web/live/challenges_live_test.exs`
Expected: FAIL (route/module unknown).

- [ ] **Step 3: Implement `ChallengesLive`**

Model the page on `DailyChallengesLive` (card grid, same visual language). i18n: heading, card title, description, "Your rank: #%{rank}" (gettext), "Best: %{score}". Card shows top 5: rank number, linked → `<.link navigate={~p"/users/#{user.id}"}>` with profile display name (fallback user name); anonymous → plain text `anonymous_name`. LiveSession: use the same authenticated scope as `/daily-challenges` (check its `live_session` in router.ex and match it).

- [ ] **Step 4: Run tests, verify they pass**

Run: `mix test test/medoru_web/live/challenges_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Add the dashboard link + i18n, format.**

Add the dashboard link with gettext + hand-fill bg/ja in the .po files (bg formal imperative; ja consistent with existing challenge strings). `mix format`.

---

### Task 3: Gate and game shell — `KanjiMasterLive`

**Files:**
- Create: `lib/medoru_web/live/kanji_master_live.ex`
- Modify: `lib/medoru_web/router.ex` (route `live "/challenges/kanji-master", KanjiMasterLive` in the same scope as `/challenges`)
- Test: `test/medoru_web/live/kanji_master_live_test.exs`

**Interfaces:**
- Consumes: `Challenges.eligible?/1`, `Challenges.learned_kanji_count/1`, `Challenges.kanji_master_pool/1`, `Accounts` level for start coins (`UserStats.level` field on the user's stats — check how dashboard reads it, e.g. `socket.assigns.current_scope` user stats).
- Produces: route `/challenges/kanji-master`; when eligible, renders game container `<div id="kanji-master-game" phx-hook="KanjiMaster" data-pool={Jason.encode!(@pool)} data-start-coins={@start_coins} data-start-lives="15" data-start-hints="5">` with HUD markup (lives ❤ / coins / yellow charges) and a canvas mount point. When not eligible: gate block.

- [ ] **Step 1: Write the failing tests**

Test: anonymous visitor sees gate with sign-in prompt and no game container (Review Focus 1); user with 49 learned kanji sees gate (Review Focus 2); user with 50 sees the game container with `data-start-lives="15"`, `data-start-hints="5"`, `data-start-coins` equal to their site level, and `data-pool` JSON containing their drawable kanji; gate (both cases) links to `/kanji`, `/the-hollow-ouroboros`, and `/classrooms/36904ffe-0f2d-4fab-b578-652752cf5c27`.

- [ ] **Step 2: Run tests, verify they fail**

Run: `mix test test/medoru_web/live/kanji_master_live_test.exs`
Expected: FAIL.

- [ ] **Step 3: Implement `KanjiMasterLive`**

`handle_params`/`mount`: read current user from `socket.assigns.current_scope`; `eligible?`; assign `:gate?`, `:pool` (only when eligible — JSON-encode in template), `:start_coins` (site level), constants. Gate template: heading + message + three `<.link>` buttons + (when anonymous) sign-in link. Game shell template: full-viewport wrapper (`h-[100dvh] overflow-hidden flex flex-col`, centered canvas area, HUD row on top: `15 ❤`, `N 🪙`, `N 💛` with icons via `<.icon>` — heart, a coin/medoru mark, and a yellow-heart variant; use heroicon `hero-heart`, and small colored badges for coins/hints). i18n all strings; fill bg/ja.

- [ ] **Step 4: Run tests, verify they pass**

Run: `mix test test/medoru_web/live/kanji_master_live_test.exs`
Expected: PASS.

- [ ] **Step 5: `mix format`.**

---

### Task 4: `KanjiMaster` JS hook — core survival game

**Files:**
- Create: `assets/js/hooks/kanji_master.js`
- Modify: `assets/js/app.js` (import + register `KanjiMaster` alongside existing hooks)
- Reference (read-only, DO NOT MODIFY): `assets/js/hooks/kanji_writing.js`

**Interfaces:**
- Consumes: DOM contract from Task 3 (`#kanji-master-game` attrs: `data-pool`, `data-start-coins`, `data-start-lives`, `data-start-hints`); HUD element IDs it owns (`#km-lives`, `#km-coins`, `#km-hints`, `#km-progress`, canvas container).
- Produces: a playable game loop — no server communication yet except none. Emits `console`-free UI updates; exposes window-free module. Later tasks extend it (shop, upgrades, game over) — keep the file organized in sections.

- [ ] **Step 1: Implement the hook skeleton + canvas**

Copy the reusable parts of `kanji_writing.js` into `kanji_master.js`: SVG path parser, expected-stroke loading from `stroke_data["strokes"]`, pointer-event canvas drawing (reuse the geometric `validateStroke` heuristics: length ratio 0.3–3.0, start ≤12, end ≤18, center ≤25, direction class). Render completed correct strokes green, wrong stroke flashes red and stays raw (no snap). Canvas sized to its container, devicePixelRatio-aware.

- [ ] **Step 2: Game state machine**

State: `lives`, `coins`, `hints` (yellow charges), `score`, `stepCount` (completed kanji), `usedCharacters` (this run), `cycle` (1-based), `currentKanji`, `strokeIndex`. Ladder: pick next kanji by ascending stroke-count ladder [1..3] then 4,5,…max available, skipping counts not in pool; within a rung pick a random unused kanji of that count; after max-stroke rung, `cycle += 1` and restart ladder with unused-only kanji. Wrong-stroke life cost = `cycle` lives. When no unused kanji remain → game over (pool exhausted). Lives ≤ 0 → game over. Update HUD DOM after every event. Per-stroke scoring: +1 correct.

- [ ] **Step 3: Verify build**

Run: `cd assets && npx esbuild js/app.js --bundle --outfile=/dev/null` (or the project's `mix assets.build`).
Expected: builds clean; `KanjiMaster` registered in app.js.

- [ ] **Step 4: Manual smoke note.**

No browser automation exists for canvas; note in the task summary that interactive verification (draw strokes, lose lives, ladder advance) is manual, consistent with the existing `kanji_writing.js` which also has no JS tests.

---

### Task 5: Shop, upgrades, and yellow-stroke charges

**Files:**
- Modify: `assets/js/hooks/kanji_master.js`
- Modify: `lib/medoru_web/live/kanji_master_live.ex` (only if template needs the shop overlay container — prefer rendering the overlay entirely from the hook into a dedicated `#km-shop` div to avoid server round-trips)

**Interfaces:**
- Consumes: game state from Task 4.
- Produces: shop overlay opened automatically after every 5th completed kanji (award +1 coin first); purchasable items per spec prices (life 5, hint charge 1, upgrade pack random 4–6, kanji skip 5); upgrades state `upgrades: Map<strokeIndex1Based, color>`; yellow-charge consumption on wrong stroke (draw snapping yellow guide, no life loss); upgraded-stroke scoring (blue 2, purple 50/50 → 3 or 1, orange 5 + wrong penalty `cycle + 1` lives, silver 1 + 10% +1 life, black 5 + wrong −5 coins); override semantics (same index re-rolled replaces color); kanji skip removes a character from the pool via a picker list (render learned characters as a scrollable list inside the overlay; mobile-friendly, no typing).

- [ ] **Step 1: Implement shop overlay**

Overlay markup rendered into `#km-shop` (hidden by default): item cards with price buttons; coin balance display; close button resumes the game. Disable unaffordable items. Upgrade pack: on purchase, roll price 4–6 at shop open, generate 3 random `{index, color}` offers (index within 1..min(12, max strokes in pool); colors from the 5; exclude an offer identical to an already-owned index+color), player picks one → `upgrades[index] = color`.

- [ ] **Step 2: Implement upgrade effects in stroke handling**

On correct stroke: if `upgrades[i]` exists apply its scoring/life rule and draw the stroke in its color (still snapping). On wrong stroke: orange → lose `cycle + 1` lives; black → also −5 coins (floor 0); if `hints > 0` → consume hint, draw snapping yellow guide for the expected stroke, no life loss (applies regardless of upgrade); else raw red, life loss.

- [ ] **Step 3: Verify build**

Run: `mix assets.build`
Expected: clean build.

---

### Task 6: Game over, score recording, leaderboard on the page

**Files:**
- Modify: `assets/js/hooks/kanji_master.js` (game-over overlay → `pushEvent("record_score", {...})` only after the player's identity choice; also `pushEvent("game_over", %{score: ...})` for stats-free display)
- Modify: `lib/medoru_web/live/kanji_master_live.ex` (`handle_event("record_score", ...)` → `Challenges.record_score/2`; game-over assigns for the template)
- Modify: `lib/medoru_web/live/kanji_master_live.ex` template (game-over panel showing score + top 5 + identity form: "Link my profile" / anonymous name input + submit)
- Test: `test/medoru_web/live/kanji_master_live_test.exs` (extend)

**Interfaces:**
- Consumes: `Challenges.record_score/2`, `Challenges.get_leaderboard/0` (Task 1).
- Produces: `handle_event("record_score", %{"score" => int, "display_mode" => "linked" | "anonymous", "anonymous_name" => string | nil})`.

- [ ] **Step 1: Write the failing tests**

Test: eligible user can push `record_score` with linked mode → row created, flash success; anonymous with name → row with `display_mode "anonymous"`; anonymous with blank name → error feedback (changeset error rendered); game-over template section shows the score and the top-5 list; the page is re-usable (re-push updates the same row).

- [ ] **Step 2: Run tests, verify they fail**

Run: `mix test test/medoru_web/live/kanji_master_live_test.exs`
Expected: FAIL (event unknown).

- [ ] **Step 3: Implement server handler + game-over UI**

`handle_event("record_score", ...)`: lookup current user, call `record_score`, on success put_flash + (optionally) update leaderboard assign; on error render changeset errors. Template: game-over panel (initially hidden server-side; the hook fills score and reveals it) containing the identity form and a top-5 list seeded from `@leaderboard` (updated via the flash/navigation or a re-render — simplest: after successful record, re-fetch leaderboard assign and re-render the panel). i18n everything, fill bg/ja.

- [ ] **Step 4: Wire the hook**

On game over: reveal overlay with final score; on identity submit → `pushEvent("record_score", ...)`. Pool-exhausted ending shows the congratulations variant message (distinct from lives-out). Both from the hook with gettext-free client strings rendered by the server? Client-side strings can't use Gettext — render BOTH game-over message variants in the template (hidden) and let the hook toggle visibility by game-over reason.

- [ ] **Step 5: Run tests, verify they pass; `mix format`.**

---

### Task 7: Integration pass — assets, i18n sweep, full suite

**Files:**
- Modify: `priv/static/service-worker.js` (bump `CACHE_NAME`, currently `medoru-v508` → `medoru-v509`)
- Reference: all files above.

- [ ] **Step 1: i18n sweep**

Scripted check (as done previously in this repo): every `gettext`/`ngettext` msgid in the new files exists and is non-empty in `priv/gettext/{bg,ja}/LC_MESSAGES/default.po`; hand-fill any gaps.

- [ ] **Step 2: Build + digest + cache bump**

Run: `mix assets.build && mix phx.digest`
Expected: clean; `KanjiMaster` present in the digested bundle.

- [ ] **Step 3: Full test suite**

Run: `mix test`
Expected: all green except known-acceptable failures (see Global Constraints).

- [ ] **Step 4: Manual mobile check note**

Verify in a browser (user-side): no scrollbars during play on a phone-sized viewport, HUD counters update, shop opens every 5 kanji.
