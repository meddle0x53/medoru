# Kanji Master — Learner Challenges Design

Date: 2026-10-07
Status: approved for planning (pending spec review)

## Overview

A new **permanent challenges** subsystem ("learner challenges"), alongside the existing daily challenges. The first challenge is **Kanji Master**: an infinite kanji-writing survival game with lives, a per-run coin economy, a shop, stroke upgrades, and a cross-user top-5 leaderboard.

Entry points: dashboard link + `/challenges` page (cards styled after `/daily-challenges`).

## Decisions locked with the user

- Coins are **fresh each run** (roguelike): start = site level, +1 per 5 completed kanji. No persistence between runs.
- A purchased **yellow stroke** is an **auto-hint charge**: on a wrong stroke, one charge is consumed and the correct stroke is drawn for the player as a snapping yellow guide.
- **Orange stroke** wrong penalty: 2 lives, escalating +1 per full ladder cycle (3, 4, …).
- Shop **auto-opens** every 5 completed kanji (overlay); no shopping between marks. Can be closed to resume.
- **No site XP** is awarded for scores.
- The challenges card shows **"your rank: #N"** even when outside the top 5.

## Routes & pages

| Route | Purpose |
|---|---|
| `/challenges` | Learner challenges page; cards like `DailyChallengesLive`. Kanji Master card: title, description, top 5 (linked entries clickable to `/users/:id`), current user's rank/best if any. |
| `/challenges/kanji-master` | The game. Full-viewport, mobile-first, no scrollbars; canvas + HUD centered. |
| `/challenges/kanji-master` (gate) | If the user knows < 50 kanji (or is anonymous): message "learn at least 50 kanji", links to `/kanji`, `/the-hollow-ouroboros`, and `/classrooms/36904ffe-0f2d-4fab-b578-652752cf5c27`. Anonymous visitors see a sign-in prompt. |

The gate replaces the game content on the same route (simpler than a separate page).

## Game rules

### Resources
- **Lives**: 15 at start. HUD: `N ❤` (heart icon).
- **Coins**: start = user's site level (`UserStats.level` via `Accounts.calculate_level/1`), `+1` every 5 completed kanji. HUD: `N 🪙` (medoru icon). Reset each run.
- **Yellow stroke charges**: 5 at start, +1 per purchase. HUD: `N 💛` (yellow heart icon).

### Kanji pool
- Player's learned kanji: `user_progress` rows with `kanji_id` not nil, joined to `kanji` with non-empty `stroke_data["strokes"]`.
- One kanji per ladder step; kanji already drawn this run are not repeated until the pool is exhausted (see cycles).

### Stroke-count ladder
- Level 1: a known kanji with 1–3 strokes.
- Level 2: 4 strokes. Level 3: 5 strokes. Then 6, 7, … up to the maximum stroke count the player has in their pool. Stroke counts with no kanji in the pool are skipped ("if the user doesn't have an N-stroke kanji → N+1").
- After passing the kanji with the most strokes: **restart the ladder from 1–3 strokes**, using only kanji **not yet drawn this run**. This is cycle 2: wrong strokes cost **2 lives** (instead of 1). Each further full cycle adds +1 to the per-error life cost (cycle 3 → 3 lives, etc.).
- When all learned kanji have been drawn: **game over (pool exhausted)** → congratulations message + "learn more kanji for a better score!".

### Scoring
- Every correct stroke: +1 point (upgrades modify this, see below).
- Every wrong stroke: loses life(s) per current cycle cost.
  - With yellow-stroke charges > 0: one charge is consumed, no life lost, and the correct stroke is drawn for the player as a **snapping yellow guide**.
  - Without charges: the wrong stroke flashes red and stays visible raw (no snap) — the player draws it again.
- Lives reach 0: **game over** → score recorded.

### Shop
Auto-opens as an overlay every 5 completed kanji (after awarding the +1 coin); closable to resume. Between marks no shopping is possible.

| Item | Price (coins) | Effect |
|---|---|---|
| +1 life | 5 | +1 life |
| Yellow stroke charge | 1 | +1 auto-hint charge |
| Upgrade pack | random 4–6 | offers 3 random stroke-color upgrades; player picks exactly 1 |
| Kanji skip | 5 | exclude one learned kanji from this run's pool (picker list, mobile-friendly; not typing) |

Prices for the upgrade pack are rolled when the shop opens (or when the pack is first viewed each visit).

### Stroke upgrades
An upgrade = "stroke **N** (random index) becomes **color**".
- Applies to every kanji the player draws that has ≥ N strokes (per-kanji, index-based).
- Re-rolling the same index **overrides** the previous color at that index. Never red or yellow (reserved: red = wrong, yellow = hint/guide).
- Colors:
  - **Blue**: right stroke gives 2 points.
  - **Purple**: right stroke gives 3 points with 50% chance, otherwise 1.
  - **Orange**: right stroke gives 5 points; wrong costs 2 lives + per-cycle escalation (cycle 2 → 2, cycle 3 → 3, …).
  - **Silver**: right stroke gives 1 point and has a 10% chance to grant +1 life.
  - **Black**: right stroke gives 5 points; wrong additionally subtracts 5 coins (plus normal life loss).
- Right strokes snap in their upgraded color; wrong strokes stay raw red, no snap — unless a yellow charge converts them into a snapping yellow guide.

## Leaderboard & identity

New table `kanji_master_scores`:
- `id` binary_id PK, `user_id` binary_id FK (unique index, `on_delete: :delete_all`),
- `score` integer, `display_mode` string (`"linked"` | `"anonymous"`),
- `anonymous_name` string nullable,
- timestamps.
Top-5 query orders by score desc, preloads `user: [:profile]`.

Flow at game over:
- Player is offered to record their score: either **linked** (uses profile display name, links to profile) or **anonymous** (typed name).
- One row per user: beating your own score **overrides** it.
- Each subsequent run can re-record: change score, switch linked↔anonymous, rename.
- The `/challenges` card and the game-over screen show the top 5; the card also shows the current viewer's rank `#N` and best when logged in (even outside top 5). Linked entries are clickable to `/users/:id`; anonymous entries are plain text.

Participation gate: ≥ 50 learned kanji (`user_progress` with kanji_id). Anonymous users see the gate with a sign-in prompt.

## Technical design

### Server-side
- New context `Medoru.Challenges` (`lib/medoru/challenges.ex` + `lib/medoru/challenges/kanji_master_score.ex`):
  - `get_leaderboard/0` (top 5 + entries with user/profile preloaded),
  - `get_rank_and_score/1` (current user's rank + best),
  - `record_score/2` (upsert by user_id; validates display_mode/anonymous_name),
  - `eligible?/1` (≥ 50 learned kanji).
- LiveViews:
  - `MedoruWeb.ChallengesLive` (`/challenges`) — cards grid modeled on `DailyChallengesLive`.
  - `MedoruWeb.KanjiMasterLive` (`/challenges/kanji-master`) — gate or game.
- Migration: `create table(:kanji_master_scores, primary_key: false)` + `add :id, :binary_id, primary_key: true`, FK `references(:users, type: :binary_id, on_delete: :delete_all)`, unique index on `user_id`, index on `score`. Explicit `up`/`down`.
- The server sends the run's kanji pool (characters + `stroke_data` + stroke counts) at mount. All stroke drawing, validation, scoring, lives, coins, shop logic, and upgrades run **client-side** in a new `KanjiMaster` JS hook; the client reports only final results (score, and display identity choice) — the same trust model as existing client-graded games. No XP is awarded.

### Client-side
- **New** `assets/js/hooks/kanji_master.js` — adapted from the existing `kanji_writing.js` (SVG path parsing, geometric stroke validation, snapping, colors) but self-contained. **The existing `KanjiWriting` hook and `WritingComponent` must not be modified** (daily/lesson challenges keep identical behavior).
- KanjiMaster hook responsibilities: canvas drawing, per-stroke validation, upgrade colors/points, yellow-charge hints, lives/coins/step counters, ladder + cycle logic, pool exhaustion, shop overlay + purchases, game-over + score submission (pushEvent).
- Layout: full-viewport, centered, no scrollbars on mobile (overflow hidden, `100dvh`); HUD row: lives `N ❤`, coins `N 🪙`, yellow strokes `N 💛`; progress of current kanji (stroke k of n).

### i18n
All user-facing strings through `gettext`/`ngettext` from the start; bg/ja translations added to the `.po` files (hand-filled, as established this session). Terminology consistent with existing catalogs.

### Testing
- Context tests: eligibility (50-kanji boundary), leaderboard ordering, upsert/override semantics, display_mode validation, anonymous vs linked rendering data.
- LiveView tests: gate for ineligible/anonymous users; `/challenges` card shows top 5 and viewer rank; game-over score submission (linked + anonymous + rename + unlink).
- Hook-level logic is client-side; keep the scoring/ladder rules mirrored in small pure functions where practical for unit testing, but full canvas testing is out of scope (matches existing games).

## Out of scope
- Server-side stroke validation / anti-cheat (trust-based like existing games).
- XP rewards for scores.
- Additional challenges beyond Kanji Master (the page is built to accept more cards later).
- Persistent coin wallets.
