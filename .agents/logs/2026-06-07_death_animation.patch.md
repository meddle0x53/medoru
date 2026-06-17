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

# Patch: Full Target Zone and Enemy Y Offset

## Changed Files
- `assets/js/game/scenes/BattleScene.js`
- `lib/medoru_web/live/admin/game_live/game.html.heex`
- `priv/static/service-worker.js`

## What Changed

### BattleScene.js
- Replaced the circle-only target hit area with a full-enemy rectangle (`120×(displayHeight+70)`) that covers the sprite, block text, HP/stamina bars, and the visible ring. Tapping anywhere inside that area now selects the enemy.
- Kept the red pulsing ring as a purely visual indicator centered on the enemy.
- Restored the upward offset for smaller enemies: `y = 570 - (0.30 - scale) * 280`, so 2- and 3-enemy encounters are raised instead of looking sunken.

### Version Bumps
- Game bundle: `game.js?v=164` → `game.js?v=165`
- Service worker cache: `medoru-v63` → `medoru-v64`

## Testing
- `mix compile` passes.
- `mix assets.build` passes.
- Note: the exact per-count y offsets were restored from the pre-existing formula. If you had different values, paste them and I'll swap them in.
