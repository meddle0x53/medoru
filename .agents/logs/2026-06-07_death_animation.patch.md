# Patch: Enemy Death Animation and Removal

## Changed Files
- `assets/js/game/scenes/BattleScene.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### BattleScene.js
- Added a new helper `handleEnemyDeath(enemy, display)` that is called from `updateEnemyDisplay()` whenever an enemy's HP drops to 0.
- Death sequence:
  1. Plays the enemy's base attack animation in reverse via `display.sprite.anims.playReverse('enemy-attack')`. This creates a staggered "ghost rising" visual instead of a jarring pop-out.
  2. Tints the sprite dark grey (`0x333333`).
  3. Fades out the sprite alpha from `1` to `0` over 750 ms using the scene tween.
  4. After the fade completes, destroys the display container and removes the enemy from `this.enemyDisplays`.
  5. Hides the enemy's nameplate, HP/stamina bars, block text, and intention icons immediately so dead enemies no longer show UI.
- Marked enemies as already processed with `enemy._deathHandled` to prevent repeated triggers.
- Updated `runEnemyTurn()` so that dead enemies are skipped (`this.currentAttackingEnemy.isAlive()` check) and the round-robin loop breaks early if all remaining enemies are dead, preventing extra empty cycles.
- Updated `onPlayerActionComplete()` to cancel enemy-targeted target mode if the selected enemy dies during a multi-target action.

### Version Bumps
- Game bundle: `game.js?v=161` → `game.js?v=162`
- Service worker cache: `medoru-v60` → `medoru-v61`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.
- Verified that defeating any enemy in a multi-enemy encounter fades/removes the sprite, bars, name, block, and intentions, while the remaining enemies continue their turn order.

---

# Patch: Target Zone Clickability and 3-Enemy Vertical Alignment

## Changed Files
- `assets/js/game/scenes/BattleScene.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### BattleScene.js
- Replaced the large, scale-tweened target circle with two separate objects:
  - A static invisible hit area (`depth 99`) that is slightly larger than the visible ring, so every tap inside (or just outside) the red circle registers.
  - A smaller, centered visible ring (`depth 100`) that only pulses alpha, keeping the clickable area stable.
- Target ring is now centered on the enemy sprite at `sprite.y - displayHeight * 0.45` with a radius that scales with the enemy but is clamped between 48–70 px.
- The enemy sprite remains interactive, so taps on the body outside the ring still select the target.
- Aligned all enemy baselines to `y = 570`, so 1/2/3-enemy encounters share the same ground line and no longer look vertically offset.

### Version Bumps
- Game bundle: `game.js?v=162` → `game.js?v=163`
- Service worker cache: `medoru-v61` → `medoru-v62`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Win Battle Button on Boss Tiles

## Changed Files
- `assets/js/game/scenes/BattleScene.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### BattleScene.js
- Removed the boss-tile check that hid the temporary "Win Battle" button, so it now appears on normal, mini-boss, and boss battles.

### Version Bumps
- Game bundle: `game.js?v=163` → `game.js?v=164`
- Service worker cache: `medoru-v62` → `medoru-v63`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Data-Driven Enemy Refactor (Phase 1)

## Changed Files
- New: `assets/js/game/data/enemies/kasa_obake.json`
- New: `assets/js/game/data/enemies/kasa_obake_elite.json`
- New: `assets/js/game/data/enemies/kasa_obake_tyrant.json`
- New: `assets/js/game/data/enemies/index.js`
- New: `assets/js/game/data/defaultKanjiPool.js`
- New: `assets/js/game/systems/EnemyChallengePicker.js`
- New: `assets/js/game/systems/EnemyAbilityChallengeSystem.js`
- Modified: `assets/js/game/entities/Enemy.js`
- Modified: `assets/js/game/scenes/BattleScene.js`
- Modified: `assets/js/game/scenes/BootScene.js`
- Modified: `assets/js/game/scenes/WinScene.js`
- Modified: `assets/js/game/systems/ChallengeSystem.js`
- Modified: `assets/js/game/data/skills.js`
- Deleted: `assets/js/game/data/enemies.js`
- Deleted: `assets/js/game/data/monsters.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### Enemy JSON definitions
- Each enemy now lives in its own JSON file under `assets/js/game/data/enemies/`.
- Schema includes: id, name, nameJa, description, level, baseGold, roles, mapIds, maxColumn, sprites, portrait/icon, layout per 1/2/3 enemies, stat min/max ranges, abilities, deathAbility, and class-keyed drops with rarity.
- Migrated the existing Kasa-obake family into three entries:
  - `kasa_obake` (regular battle)
  - `kasa_obake_elite` (mini-boss)
  - `kasa_obake_tyrant` (boss)

### Loader (`assets/js/game/data/enemies/index.js`)
- Exports `ENEMY_DEFINITIONS`, `getEnemyDefinition(id)`, `pickEnemyForTile(tile, mapIndex)`, and `rollEnemyDrops(enemy, playerClass)`.
- `pickEnemyForTile` filters by tile role, map ID, and max column, with a role fallback.

### `Enemy.js`
- Constructor now takes an enemy definition object (or ID string) and rolls stats from min/max ranges.
- Tracks per-turn ability uses (`usesThisTurn`).
- New AI selection: buff phase first, then attack, then other; within a phase abilities are sorted by `aiWeight`.
- `shouldContinueTurn` cap raised from 3 to 5 actions.
- `performAction` accepts an optional `context.damageMultiplier` for challenge weakening.

### Per-ability challenges
- Added `EnemyChallengePicker.js` to pick a word or kanji challenge from the player's known lists based on JSON filters.
- Added `EnemyAbilityChallengeSystem.js`, a self-contained overlay for word-meaning/reading and kanji-reading challenges during enemy turns.
- In `BattleScene.runEnemyTurn`, each ability with a `challenge` block has a chance to trigger the challenge before resolving.
  - `onSuccess: 'cancel'` skips the ability entirely.
  - `onSuccess: 'weaken'` multiplies attack damage by `weakenMultiplier`.

### Rendering
- `BattleScene.createEnemyDisplay` reads `enemy.definition.layout[count][index]` for x/y/scale and uses `enemy.definition.sprites.default`.
- Added `getEnemySpriteKey(enemy, pose)` helper; all hardcoded `enemy_kasa_obake_*` texture switches now use the enemy's own sprite map.
- Death handling and battle-end victory sprite switches use the configured death sprite.

### BootScene
- Dynamically loads every sprite/portrait/icon referenced by the enemy definitions instead of hardcoding Kasa-obake textures.

### WinScene
- Rewards and drops now come directly from `enemy.definition` / `rollEnemyDrops`.
- Removed dependency on `data/monsters.js`.

### Cleanup
- Deleted `data/enemies.js` and `data/monsters.js`.
- Removed `ENEMY_SKILLS` from `data/skills.js`.
- Moved `DEFAULT_KANJI_POOL` to `data/defaultKanjiPool.js` and updated `ChallengeSystem` import.

### Version Bumps
- Game bundle: `game.js?v=164` → `game.js?v=166`
- Service worker cache: `medoru-v63` → `medoru-v65`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.
- Verified that battle starts, enemy turns, buff→attack ordering, death, and win rewards still work with the new JSON-driven data.

---

# Patch: Ability Challenge Chance Fix

## Changed Files
- `assets/js/game/scenes/BattleScene.js`
- `assets/js/game/systems/EnemyChallengePicker.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### BattleScene.js
- Added the missing random roll against `action.challenge.chance` before building/running a per-ability challenge, so challenges no longer trigger on every ability use.

### EnemyChallengePicker.js
- Challenge objects now carry through `onSuccess`, `onFail`, and `weakenMultiplier` from the JSON config.
- Word reading challenges no longer show the reading as a hint.
- Kanji challenges accept romaji input in addition to exact readings.

### Version Bumps
- Game bundle: `game.js?v=166` → `game.js?v=167`
- Service worker cache: `medoru-v65` → `medoru-v66`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Map Test Fight Button

## Changed Files
- `assets/js/game/scenes/MapScene.js`
- `assets/js/game/scenes/BattleScene.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### MapScene.js
- Added a new `DEV: TEST FIGHT` button above the map (next to the existing `DEV: RESET RUN` button).
- Clicking it opens a dialog where you can cycle through enemy definitions and choose a count of 1–3.
- Pressing **START** launches `BattleScene` directly with the chosen enemy and count, bypassing the map and loadout.

### BattleScene.js
- `createEnemiesForTile()` now respects `tile.enemyId` (for exact enemy selection) and `tile.testFightCount` (for exact count).

### Version Bumps
- Game bundle: `game.js?v=167` → `game.js?v=168`
- Service worker cache: `medoru-v66` → `medoru-v67`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Multiple Challenges Per Ability

## Changed Files
- `assets/js/game/scenes/BattleScene.js`
- `assets/js/game/data/enemies/kasa_obake.json`
- `assets/js/game/data/enemies/kasa_obake_elite.json`
- `assets/js/game/data/enemies/kasa_obake_tyrant.json`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### BattleScene.js
- `runEnemyTurn()` now supports both a single `challenge` object and a `challenges` array on an ability.
- If any challenge in the array succeeds with `cancel`, the ability is cancelled.
- If any succeeds with `weaken`, the weakest (smallest) `weakenMultiplier` is applied to attack damage.
- Challenges are rolled independently in array order.

### Enemy JSON data
- Converted all Kasa-obake enemy definitions from a single `challenge` object per ability to a `challenges` array with one entry each.
- The code still accepts a plain `challenge` object for backwards compatibility.

### Version Bumps
- Game bundle: `game.js?v=169` → `game.js?v=170`
- Service worker cache: `medoru-v68` → `medoru-v69`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.
- Verified all three enemy JSON files parse correctly.

---

# Patch: Persistent Enemy Buff Indicator

## Changed Files
- `assets/js/game/entities/Enemy.js`
- `assets/js/game/scenes/BattleScene.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### Enemy.js
- `performAction()` now calls `this.consumeBuff('next_attack_bonus')` when executing an attack, so the buff list stays accurate instead of leaking stale entries.

### BattleScene.js
- Added a persistent `⬆` buff indicator above each enemy's head in `createEnemyDisplay()`.
- Added `updateBuffIndicator(display)` to show/hide the indicator based on whether the enemy has an active `next_attack_bonus` buff.
- `updateBars()` now refreshes the buff indicator for every enemy display.
- `onEnemyDefeated()` hides the buff indicator along with the rest of the enemy UI.

This makes it obvious when an enemy has queued a buff, even after the brief buff pose animation finishes.

### Version Bumps
- Game bundle: `game.js?v=170` → `game.js?v=171`
- Service worker cache: `medoru-v69` → `medoru-v70`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Enemy Ability Challenge Clarity

## Changed Files
- `assets/js/game/scenes/BattleScene.js`
- `assets/js/game/systems/EnemyAbilityChallengeSystem.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### BattleScene.js
- When an enemy ability challenge triggers, the combat log now says:
  - `"Kasa-obake's Intimidate triggers a kanji challenge!"`
  - `"Kasa-obake's Claw Strike triggers a word challenge!"`
- The challenge object is tagged with the ability name so the UI can show it.

### EnemyAbilityChallengeSystem.js
- The challenge overlay title now uses the ability name, e.g. `"Intimidate Challenge"` instead of the generic `"Enemy Ability Challenge"`.

### Version Bumps
- Game bundle: `game.js?v=171` → `game.js?v=172`
- Service worker cache: `medoru-v70` → `medoru-v71`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

## Note
The Kasa-obake `intimidate` ability is correctly configured with a `kanji` challenge in `kasa_obake.json`. If you were seeing a word challenge after the buff icon, it was likely the *attack's* word challenge (or a reaction challenge) on the following action. The new title and combat log should make that clear.
