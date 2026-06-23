# Plan: Weapon/Shield Socket Charms & Build System

> Status: **Design ready — implementation deferred to next session.**

## 1. Goals

- Turn weapon/shield upgrades into the foundation of character builds.
- Add **4 socket slots** per weapon/shield that are unlocked by upgrade level.
- Introduce **socket-specific charm classes** that override or extend scaling and unlock ability families.
- Allow abilities to have **equipment charm requirements** (e.g. bleeding abilities need the Sharp gem).
- Support **once-per-battle and cooldown abilities** for socket-4 ultimates.
- Keep first-socket charms as **persistent unlocks** that can be earned in-run or bought in a future pre-run shop.

## 2. Socket Unlock Schedule

| Upgrade Level | Socket Unlocked |
|---------------|-----------------|
| +1            | Socket 1 (build-defining charm) |
| +3            | Socket 2 (passive proc charm)   |
| +6            | Socket 3 (scaling/ability charm)|
| +7            | Socket 4 (ultimate/passive)     |

Weapons/shields can reach **+10**.

## 3. Base Scaling Rules

### Long Sword
- **+0**: STR C, SKL D
- **+3**: STR B, SKL D
- **+5**: STR B, SKL C
- **+9**: STR A, SKL C
- Between milestones scaling improves gradually each upgrade.

### Wooden Shield
- **+0**: STR D
- **+5**: STR C
- **+9**: STR B

## 4. Socket 1 — Build-Defining Charms (Sword)

These override the weapon's base scaling while the charm is equipped.

| Charm | STR Scaling | SKL Scaling | New Scaling | Notes |
|-------|-------------|-------------|-------------|-------|
| **Sharp Charm** | D (fixed) | C (+1) → B (+5) → A (+9) | — | Enables bleed/edge abilities. |
| **Heavy Charm** | B (+1) → A (+6) → S (+10) | unchanged | — | Strength-focused, slower/heavier attacks. |
| **Fire/Water(Ice)/Poison/Wind/Earth(Wooden)/Dark/Light Charm** | D (fixed) | D (fixed) | ARC D (+1) → C (+4) → B (+8) → A (+10) | Elemental gem. Unlocks passive elemental procs and element-specific abilities. |
| **Lucky Charm** | none | none | LUCK C (+1) → B (+5) → A (+9) → S (+10) | Enables RNG/luck-based abilities (e.g. critical strike). |

### Shield Socket 1 Charms
To be designed later, but should mirror the sword pattern:
- A **Sturdy/Heavy** path for defense/STR.
- An **Elemental** path that adds ARC scaling and elemental guard effects.
- A **Lucky** path for dodge/miss procs.
- A **Spiked/Sharp** path for counter/thorn effects.

## 5. Socket 2 — Passive Proc Charms

Examples (details TBD):
- Chance to heal 1–X HP on hit.
- Chance for the used ability to cost -1 stamina.
- Chance to inflict a minor status on hit.
- Small gold/xp find chance.

These are small, luck/RNG driven effects.

## 6. Socket 3 — Scaling / Hybrid Charms

- Improve an existing scaling grade or add a secondary scaling stat.
- Unlock abilities that require **both** the socket-1 charm family AND the socket-3 charm.
- Example: Sharp (socket 1) + a "Finesse" socket-3 charm unlocks advanced bleed combos.

## 7. Socket 4 — Ultimate / Powerful Passive

Two broad categories:

1. **Active Ultimate** — a very powerful ability that is:
   - usable once per battle, OR
   - has a long cooldown (3–5 turns).
2. **Powerful Passive** — always-on effects such as:
   - Auto-heal each turn.
   - Auto-damage/retaliation.
   - Stamina regeneration.

## 8. Ability System Extensions Needed

- **Ability requirements**: an ability can list required `weaponCharmId` / `charmFamily` / `socketCombination`.
- **Passive abilities**: register effects that apply automatically at battle start.
- **Cooldown tracking**: per-ability cooldown counter in `Character`/`Player`.
- **Once-per-battle flag**: abilities that can only be used once per combat.
- **Luck-scaling abilities**: read `player.luck` and the LUCK scaling grade.

## 9. Hero Charms

Hero charms will also receive more interesting effects beyond simple stat bumps, but this is out of scope for this plan. Keep current stat charms; add build-oriented hero charms later.

## 10. Persistence & Unlock Economy

- **First-socket charms** are persistent unlocks.
- Player can earn them during a run (drops, events) or buy them in a future pre-run preparation scene.
- Between runs the player chooses which first-socket charm to start with (when hero selection/pre-run shop exists).
- Socket 2/3/4 charms can be found/bought in-run or unlocked permanently; TBD.

## 11. Files to Touch (later)

- `assets/js/game/entities/Player.js`
  - Expand weapon/shield object to hold `socketCharmIds: [null, null, null, null]`.
  - Update `getWeaponCharmSlots()` to new schedule (+1, +3, +6, +7).
  - Add scaling resolution that considers base level + socket 1 charm overrides.
- `assets/js/game/data/charms.js`
  - Add socket-charm entries with `type: 'weapon_socket_1'`, `scalingOverrides`, `unlockedAbilityFamilies`, etc.
- `assets/js/game/data/abilities/index.js` and action definitions
  - Add `requirements` field (charm/family/level).
  - Add cooldown / once-per-battle fields.
- `assets/js/game/scenes/LoadoutScene.js`
  - Show 4 socket slots and which charm families are equipped.
  - Gray out abilities the player cannot use yet.
- `assets/js/game/scenes/ShopScene.js` / `RestScene.js`
  - Add socket-charm purchase/selection when appropriate.
- `assets/js/game/systems/TurnManager.js` / `BattleScene.js`
  - Handle passive procs, cooldowns, once-per-battle abilities.

## 12. Immediate Preparation Steps (safe to do now if desired)

1. Change `getWeaponCharmSlots()` / `getShieldCharmSlots()` to the new 4-slot schedule.
2. Add `socketCharmIds` arrays to weapon/shield loadout defaults.
3. Add a helper `getEffectiveScaling(weapon)` that returns base scaling or charm-overridden scaling.

## 13. Open Questions

- Exact per-level scaling increments between milestones?
- Shield first-socket charm names and ability families?
- Cost and rarity of socket charms in shop?
- Do socket 2/3/4 charms persist across runs or are they per-run only?
- How do elemental passive procs scale with ARC / mana?
