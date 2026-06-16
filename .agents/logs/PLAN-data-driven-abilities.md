# Plan: Data-Driven Abilities with Admin UI

**Status:** Draft — not scheduled for immediate implementation.  
**Context:** The rogue-like map work takes priority; this plan is for a future iteration.

## Goal
Move ability definitions out of `assets/js/game/data/actions.js` and into the database so admins can:

- View, create, edit, and delete abilities.
- Change names, descriptions, stats, challenge type, and lifecycle hooks.
- Upload/assign sprite assets per ability lifecycle phase.
- Scope abilities by hero class (warrior now; mage / archer / etc. later).

The game must remain offline-capable: ability definitions and asset URLs are loaded once and cached in the browser.

## High-Level Architecture

```
DB ──► Admin LiveView CRUD ──► JSON API / window.gameData ──► Browser cache
                                      │
                                      ▼
                             Phaser BootScene preloads dynamic assets
                                      │
                                      ▼
                         BattleScene/TurnManager call lifecycle hooks
                         from a version-controlled behavior registry
```

Engine behavior code stays in JavaScript (version-controlled). The DB only points to behavior names and supplies config values. This avoids executing admin-written code in the browser.

## 1. Database Schema

### `game_abilities`

| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | PK |
| `slug` | string | Unique engine identifier, e.g. `focus`, `heavy_slash` |
| `class_slug` | string | `warrior`, `mage`, `archer`, etc. |
| `name` / `name_ja` | string | Display names |
| `description` | text | |
| `type` | string | `attack`, `defence`, `buff`, `debuff`, `heal`, `attack_defence`, `parry`, `item` |
| `rarity` | string | `normal`, `rare`, `epic`, … |
| `kanji` | string | Single character shown on buttons / challenges |
| `stamina_cost` | int | |
| `base_power` | int | For attacks |
| `scaling_stat` | string | `strength`, `skill`, `mana`, … |
| `scaling_multiplier` | float | |
| `base_block` | int | For defence |
| `heal_amount` | int | For heals |
| `buff_type` | string | Engine behavior key, e.g. `max_readiness`, `sword_damage_bonus` |
| `challenge_type` | string | `kanji`, `typing`, `none` |
| `challenge_kanji` | string | Character for kanji drawing challenge |
| `hooks` | jsonb | Map of lifecycle phase → behavior function name |
| `config` | jsonb | Extra numeric/enum params for the behavior |
| `is_default` | boolean | Included in starter loadouts |
| `order_index` | int | Admin sort order |
| timestamps | | |

### `game_ability_assets`

| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | PK |
| `ability_id` | bigint | FK |
| `lifecycle_key` | string | e.g. `idle`, `onPlayerAct`, `onEnemyAttack`, `onHit` |
| `file_path` | string | Relative URL like `/uploads/abilities/warrior-focus-onPlayerAct.png` |
| `order_index` | int | |
| timestamps | | |

**Indexes:**
- `game_abilities(class_slug, order_index)`
- `game_ability_assets(ability_id, lifecycle_key)`

## 2. Backend: Admin UI

New LiveView routes under the admin scope:

- `GET /admin/game/abilities` — list/filter by class.
- `GET /admin/game/abilities/new` — creation form.
- `GET /admin/game/abilities/:id/edit` — edit form.
- `POST/PUT /admin/game/abilities/:id` — persistence.

Form fields:
- Basic info (name, class, type, rarity, kanji, description).
- Combat stats (stamina, base power/block/heal, scaling).
- Buff type dropdown populated from the engine registry.
- Challenge type + challenge kanji.
- Lifecycle hooks multi-select with behavior names.
- Asset upload dropzones per lifecycle phase.

Validation rules:
- `slug` must be unique per class.
- `buff_type` / hook names must exist in the engine registry.
- Challenge kanji required when `challenge_type = kanji`.
- Asset uploads limited to PNG/WebP, max 1 MB.

## 3. Asset Storage

- Uploaded files stored in `priv/static/uploads/abilities/` with a path like `{class_slug}/{ability_slug}-{lifecycle_key}-{timestamp}.png`.
- Existing static game sprites remain in `priv/static/images/game/` and can be referenced manually.
- Service worker updated to cache `/uploads/abilities/*` and `/images/game/*` for offline play.

## 4. Frontend: Engine Changes

### 4.1. Ability loader
Replace the static `ALL_ACTIONS` import with a runtime list injected via `window.gameData.abilities` (or fetched + cached).

```js
const abilities = window.gameData?.abilities || []
```

### 4.2. Behavior registry
Move hardcoded per-skill logic from `BattleScene` / `TurnManager` into a registry:

```js
const ABILITY_BEHAVIORS = {
  dealDamage: (ability, ctx) => { ... },
  addBlock: (ability, ctx) => { ... },
  setMaxReadiness: (ability, ctx) => { ctx.performer.setReadiness(1) },
  setupParry: (ability, ctx) => { ... },
  attemptParry: (ability, ctx, attack) => { ... },
  applySwordBuff: (ability, ctx) => { ... },
}
```

`TurnManager.useSkill()` branches on `ability.type` and calls the behavior(s) named in `ability.hooks`.

### 4.3. Lifecycle hook points
Identify engine moments where hooks fire:

- `onSelect` — skill button pressed.
- `onPlayerAct` — player confirms / completes challenge.
- `onEnemyTurnStart` — before enemy chooses actions.
- `onEnemyAttack` — enemy is about to hit player.
- `onPlayerHit` — player took damage.
- `onTurnEnd` — end of performer’s turn.

Not every ability needs every hook.

### 4.4. Dynamic asset preloading
`BootScene.preload()` iterates over all ability assets and calls:

```js
for (const ability of abilities) {
  for (const [phase, url] of Object.entries(ability.assets || {})) {
    this.load.image(`ability-${ability.slug}-${phase}`, url)
  }
}
```

### 4.5. Sprite switching
`BattleScene.executeSkill()` switches the hero sprite to the asset defined for `onPlayerAct` (or fallback pose) before applying the effect. Enemy-turn hooks use the same key pattern.

### 4.6. Class support
- `Player` receives a `classSlug` from loadout / user data.
- Starter abilities seeded per class.
- Reward pools filtered by `class_slug`.
- UI shows class-appropriate ability names/hints.

## 5. Migration / Seeding Strategy

1. Create DB tables and migrations.
2. Write a one-off seeder that reads the current `ALL_ACTIONS` array and inserts rows for the warrior class.
3. Seed default asset references using existing `player_*.png` sprites.
4. Deploy.
5. In a later release, remove the static `ALL_ACTIONS` fallback once the DB data is verified.

## 6. Suggested Phases

### Phase 1 — DB + read-only frontend (1 day)
- Schema, migrations, seed from `ALL_ACTIONS`.
- Serve abilities in `window.gameData`.
- Frontend uses DB abilities instead of static import, but still hardcodes behavior branches.

### Phase 2 — Behavior registry (1 day)
- Extract per-skill logic into `ABILITY_BEHAVIORS`.
- `TurnManager` / `BattleScene` call hooks by name.
- Add validation that DB hook names exist.

### Phase 3 — Admin CRUD + assets (1–2 days)
- Admin list/new/edit forms.
- File uploads and asset lifecycle mapping.
- Dynamic preload in `BootScene`.

### Phase 4 — Class scoping + rewards (0.5–1 day)
- `class_slug` column and filtering.
- Per-class starter sets and reward pools.

**Total rough estimate:** 3.5–5 days of focused work.

## 7. Open Questions

- Should abilities be localized in the DB, or keep i18n keys and translate in the frontend?
- Do we want an ability preview/test button in the admin UI?
- Should asset uploads support animated spritesheets, or only single PNGs per phase?
- How do we handle abilities that have no visual asset for a phase — fall back to a default pose or hide the sprite change?
