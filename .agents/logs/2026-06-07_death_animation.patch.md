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

---

# Patch: Wire Status Effects into Combat

## Changed Files
- `assets/js/game/entities/Character.js`
- `assets/js/game/entities/Enemy.js`
- `assets/js/game/systems/TurnManager.js`
- `assets/js/game/systems/StatusEffectSystem.js` (new)
- `assets/js/game/scenes/BattleScene.js`
- `assets/js/game/data/enemies/kasa_obake.json`
- `assets/js/game/data/enemies/kasa_obake_elite.json`
- `assets/js/game/data/enemies/kasa_obake_tyrant.json`
- `assets/js/game/data/abilities/warrior.json`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### Character.js
- Added structured `activeEffects` runtime with `applyEffect`, `removeEffect`, stack rules (`replace`/`refresh`), durations, and snapshots.
- Added `tickEffectsAtTurnStart()` for DoT damage and `decrementEffectDurations()` for cleanup.
- Added `getOutgoingDamageMultiplier()`, `getIncomingDamageMultiplier()`, and `getStaminaMultiplier()`.
- `resetForTurn()` now respects stamina multipliers (e.g. `frost`).

### TurnManager.js
- Added turn-boundary effect lifecycle:
  - Expire effects for the side whose turn just ended.
  - Tick DoT effects for the side whose turn is starting.
  - Reset stamina after ticks (with multiplier applied).
- Applied `outgoingDamageMultiplier` to player attacks and `incomingDamageMultiplier` before damage.
- Added elemental guard resolution via `resolveElementVsDefence()`: blocks attacks, removes guards, and cures effects like burn.
- Called `applyAbilityEffects()` after skills resolve.
- Added optional `onCombatLog` callback for internal logging.

### Enemy.js
- Imported `resolveElementVsDefence` and `applyAbilityEffects`.
- Enemy attacks now apply outgoing/incoming multipliers and elemental guard resolution.
- Buffs and attacks trigger ability effects and log them.

### StatusEffectSystem.js (new)
- Helper `applyAbilityEffects(ability, performer, target, ctx, log)` rolls effect chances, snapshots initial damage for DoTs, and applies effects to the correct recipient.

### BattleScene.js
- Added status effect icon rows above enemies and near the player bars.
- Icons are colored by category: red debuff, green buff, orange one-off.
- Defeated enemies hide their status containers.

### Data
- Enemy `claw_strike` now has `"element": "physical"` in all three Kasa definitions.
- Added `ember_breath` fire attack to base `kasa_obake.json` that applies `burn` to the player and `weak` to itself.
- Player `heavy_slash` has a 30% chance to grant self `power_up` for 1–2 turns.

### Version Bumps
- Game bundle: `game.js?v=172` → `game.js?v=173`
- Service worker cache: `medoru-v71` → `medoru-v72`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.
- All modified JSON files parse correctly.

## Notes
- `bleed`, `blunt`, `madness`, `ember`, and `element_infuse` are still defined in `EffectRegistry.js` but not yet wired into combat; they can be added once the core lifecycle is verified.
- Elemental consecutive-hit progressive chances use the base value for this first pass.

---

# Patch: Consecutive-Hit Progressive Effect Chances

## Changed Files
- `assets/js/game/entities/Character.js`
- `assets/js/game/systems/StatusEffectSystem.js`
- `assets/js/game/systems/TurnManager.js`
- `assets/js/game/entities/Enemy.js`
- `assets/js/game/scenes/BattleScene.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### Character.js
- Added `elementStreaks` tracking per element.
- `getElementStreak(element)` — current consecutive hit count.
- `incrementElementStreak(element)` — resets other elements, increments the hit element, returns new count.
- `resetElementStreak(element)` — clears the streak.

### StatusEffectSystem.js
- `applyAbilityEffects()` now accepts a `consecutiveHits` parameter.
- Rolls effect chance with `rollChance(config, consecutiveHits)`, so `step` and `cap` are now used.

### TurnManager.js
- Player `attack` and `attack_defence` abilities now:
  1. Increment the target's element streak on a successful hit.
  2. Apply ability effects using the streak count.
  3. Reset the streak if any effect actually triggers.

### Enemy.js
- Enemy attacks follow the same streak increment → apply effects → reset-on-trigger flow.

### BattleScene.js
- Enemy attacks that are blocked by an elemental guard now show "BLOCKED!" floating text and a combat log line.

### Version Bumps
- Game bundle: `game.js?v=173` → `game.js?v=174`
- Service worker cache: `medoru-v72` → `medoru-v73`

## Example

For `ember_breath` with:

```json
"chance": { "base": 0.10, "step": 0.05, "cap": 0.35 }
```

- 1st fire hit: 10% burn chance
- 2nd fire hit in a row: 15%
- 3rd: 20%
- caps at 35%

Once burn triggers, the streak resets.

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Refill Enemy Stamina Before Intention Plan

## Changed Files
- `assets/js/game/systems/TurnManager.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### TurnManager.js
- When the turn switches to the player, all alive enemies now have `resetForTurn()` called immediately.
- This refills their stamina before `BattleScene` computes and displays the intention icons, so the plan reflects full stamina instead of leftover stamina from the previous enemy turn.

### Version Bumps
- Game bundle: `game.js?v=174` → `game.js?v=175`
- Service worker cache: `medoru-v73` → `medoru-v74`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Hero Starts Battle at Full Stamina

## Changed Files
- `assets/js/game/scenes/BattleScene.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### BattleScene.js
- At the start of `create()`, after clearing lingering buffs, the player now calls `resetForTurn()`.
- This refills stamina and clears per-turn flags (parry, temp defence) so the hero always begins a fresh battle at full stamina.
- Active status effects are intentionally left alone so future between-battle sickness/persistent effects can still work.

### Version Bumps
- Game bundle: `game.js?v=175` → `game.js?v=176`
- Service worker cache: `medoru-v74` → `medoru-v75`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Fix Overlapping Enemy Name Tags

## Changed Files
- `assets/js/game/scenes/BattleScene.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### BattleScene.js
- `createEnemyDisplay()` now scales the name tag based on how many enemies are in the encounter:
  - 1 enemy: 180 px wide, 14 px font
  - 2 enemies: 150 px wide, 14 px font
  - 3 enemies: 130 px wide, 12 px font
- `drawNameBg()` accepts an optional width parameter.

This prevents the 180 px name tags from overlapping in 3-enemy fights.

### Version Bumps
- Game bundle: `game.js?v=176` → `game.js?v=177`
- Service worker cache: `medoru-v75` → `medoru-v76`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Implement `bleed` Effect

## Changed Files
- `assets/js/game/entities/Character.js`
- `assets/js/game/scenes/BattleScene.js`
- `assets/js/game/data/enemies/kasa_obake.json`
- `assets/js/game/data/abilities/warrior.json`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### Character.js
- Added `onCombatLog` callback hook on characters.
- Added `log()` helper.
- Added `onIncomingDamage(rawAttack)`:
  - If the character has `bleed` and the incoming damage is > 0, it removes `bleed`.
  - Deals bonus damage equal to 10% of max HP directly to HP (ignores block/armor).
  - Logs the trigger.
- `takeDamage()` now calls `onIncomingDamage()` and returns total damage including the bleed bonus.

### BattleScene.js
- Sets `onCombatLog` on the player and every enemy so bleed trigger messages appear in the combat log.

### Data
- Added enemy wind ability `gale_claw` to `kasa_obake.json` with a ramping `bleed` chance.
- Added `bleed` effect to player `quick_stab` in `warrior.json`.

### Version Bumps
- Game bundle: `game.js?v=177` → `game.js?v=178`
- Service worker cache: `medoru-v76` → `medoru-v77`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.
- JSON files parse correctly.

## Notes
- Bleed triggers on the next damage instance that reaches `takeDamage()`, including attacks, counter-attacks, and DoT ticks.
- The bonus damage ignores block and armor.

---

# Patch: Implement `blunt` Effect

## Changed Files
- `assets/js/game/entities/Character.js`
- `assets/js/game/data/enemies/kasa_obake.json`
- `assets/js/game/data/abilities/warrior.json`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### Character.js
- `getIncomingDamageMultiplier()` now skips one-off effects; they are handled and consumed inside `takeDamage()` instead.
- `onIncomingDamage()` returns both `bleedBonus` and `bluntMultiplier`.
- `takeDamage()` applies the blunt multiplier to normal damage and then adds bleed bonus.
- `decrementEffectDurations()` no longer expires one-off effects passively; they last until triggered.

### Data
- Added enemy earth ability `stone_smash` to `kasa_obake.json` with a ramping `blunt` chance.
- Added `blunt` effect to player `heavy_slash` in `warrior.json`.

### Version Bumps
- Game bundle: `game.js?v=178` → `game.js?v=179`
- Service worker cache: `medoru-v77` → `medoru-v78`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.
- JSON files parse correctly.

## Notes
- If both `blunt` and `bleed` are present, blunt doubles the normal damage and bleed adds its bonus on top.
- Blunt is consumed immediately on the next damage instance that reaches `takeDamage()`.

---

# Patch: Add Bleed Chance to Forward Slash

## Changed Files
- `assets/js/game/data/abilities/warrior.json`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### warrior.json
- Added a `bleed` effect to `forward_slash`:
  - 10% base chance, +3% per consecutive physical hit, capped at 20%.

### Version Bumps
- Game bundle: `game.js?v=179` → `game.js?v=180`
- Service worker cache: `medoru-v78` → `medoru-v79`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Widen Enemy Word Challenge Pool

## Changed Files
- `assets/js/game/systems/EnemyChallengePicker.js`
- `assets/js/game/data/enemies/kasa_obake.json`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### EnemyChallengePicker.js
- Added a `MIN_FILTERED_WORD_POOL` threshold (20).
- If the filtered candidate pool is smaller than 20 words, the picker falls back to the player's full known-word list.
- This prevents the same small subset of words from repeating when filters are restrictive.

### kasa_obake.json
- Widened `claw_strike` word challenge filters:
  - JLPT levels: `N5`, `N4`, `N3`
  - Max frequency: `2000`

### Version Bumps
- Game bundle: `game.js?v=180` → `game.js?v=181`
- Service worker cache: `medoru-v79` → `medoru-v80`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

---

# Patch: Fix Word Challenge Pool Size and Filtering

## Changed Files
- `assets/js/game/systems/EnemyChallengePicker.js`
- `lib/medoru_web/live/admin/game_live.ex`
- `lib/medoru_web/controllers/game_api_controller.ex`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### EnemyChallengePicker.js
- `matchesWordFilters()` now:
  - Skips the JLPT filter when the word has no `jlpt_level` field (words in this app do not have JLPT data).
  - Falls back to `word.core_rank` when `word.frequency` is missing.

### Backend
- `Admin.GameLive` and `GameApiController` now load up to **1000** learned words instead of 30.
- The serialized word list now includes `core_rank`, `usage_frequency`, and `difficulty` so filters can use them.

### Version Bumps
- Game bundle: `game.js?v=181` → `game.js?v=182`
- Service worker cache: `medoru-v80` → `medoru-v81`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

## Notes
- The original ~10-word feeling came from two issues:
  1. The backend only sent 30 learned words.
  2. Words have no `jlpt_level`, so the N5 filter excluded every word, forcing a fallback to the small pool.
- With these fixes, challenges now pull from the full learned-word list and respect the frequency/core_rank filter.

---

# Patch: Support Hiragana/Kana Input in Reading Challenges

## Changed Files
- `assets/js/game/systems/EnemyAbilityChallengeSystem.js`
- `assets/js/game/systems/WordChallengeSystem.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

Both challenge systems now listen to the hidden `<input>` element's native `input` event and sync `this.input` from the element's real value.

This lets IME-composed characters (hiragana, katakana, etc.) appear correctly, instead of relying only on `keydown` events which don't always capture composed input.

### EnemyAbilityChallengeSystem.js
- Added `input` event handler in `createHiddenInput()`.
- Removed handler in `removeHandlers()`.

### WordChallengeSystem.js
- Same change in `createHiddenInput()` and `removeInputHandlers()`.

### Version Bumps
- Game bundle: `game.js?v=182` → `game.js?v=183`
- Service worker cache: `medoru-v81` → `medoru-v82`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.

## Notes
- Existing `keydown` handling for Enter, Backspace, and direct Latin keys remains in place.
- The `input` event overwrites `this.input` with the browser's composed value, so normal typing and IME typing converge on the same result.
