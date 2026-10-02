# Implementation Plan — Roguelike Upgrade System

Working plan to replace in-run stat-point allocation with the 3-card Upgrade
system, plus the **Rolls** meta-progression (scales-bought consumables that set
the rarity floor of the next reward screen).

Design references: `docs/PLAN-roguelike-upgrades.md` (code-aligned design),
`docs/game_stats_scaling_charms_reference.md` (current mechanics).

Strategy: **direct cutover on a dedicated branch.** The whole rework lands on a
game-only branch (`game/roguelike-upgrade-rework`, user-managed); breaking the
old stat-point/charge logic is acceptable there. No save-compat shims, no
no-op wrappers: charges are deleted outright, stale saves are invalidated via
`MAP_VERSION` bump. Phases below are still ordered engine → generator → UI →
economy → content → cleanup, but each phase deletes/replaces old logic
immediately instead of layering beside it.

---

## Phase 0 — Decisions (resolved)

| # | Decision | Call |
|---|---|---|
| D1 | Gamble challenge vs reroll | Gamble multiplies gold/essence only (no longer multiplies stat points). The kanji/word reroll handles upgrade cards. |
| D2 | Legacy `statAllocations` in old saves | **Cutover:** statAllocations/statPoints are deleted; MAP_VERSION bump invalidates old saves. No migration. |
| D3 | `permanentStatPointBonus` / scales-shop stat point | **Replaced by Rolls** (below). The `stat_point` shop item becomes 4 roll items. |
| D4 | Reward frequency | Normal battle: 60% chance of upgrade reward; mini-boss/boss: always. Tune later. |
| D5 | Capacity upgrades | Affect active slots only. Battle-pool/overall caps unchanged. |
| D6 | Stats tab in LoadoutScene | Replaced by "Run Upgrades" list + derived readouts (HP / Energy / Slots / Crit%). Raw stats not shown as allocatable. |
| D7 | Wasted-roll protection | A battle with no reward screen does NOT consume the active roll; it stays until a reward generates. |
| D8 | Active roll switching | One active roll at a time; activating another **replaces** it (the old one returns to inventory). |
| D9 | Reroll interaction | The kanji-challenge reroll regenerates the set at the **same tier** as the consumed roll. |
| D10 | Ability charges | **Removed.** Abilities unlocked by cards are yours for the run; stamina is the only use limiter. Strong former single-use abilities get stamina-cost rebalance (Phase 5). |
| D11 | Kanji tiers | Ability pools have tiered kanji: green (default) → blue → purple → silver, each a stronger challenge-result multiplier (×1.0 / ×1.15 / ×1.3 / ×1.5). Upgraded one random pool kanji per card. |

---

## The Rolls system (meta progression)

**Economy:** ouro scales (site XP conversion + battle/victory income, unchanged)
buy rolls in the home scales shop. Rolls sit in a persistent inventory across
runs and death; one can be **activated** before a battle to set the floor of
the next upgrade reward screen, and is consumed when that screen generates.

| Roll | Price (scales) | Effect |
|---|---|---|
| Common | 5 | next reward screen: 3 cards, normal rarity table |
| Uncommon | 10 | 3 cards, at least one uncommon+ |
| Rare | 18 | 3 cards, at least one rare+ |
| Epic | 25 | 3 cards, at least one epic |

**Data model** (`loadout`):
- `rollInventory: { common, uncommon, rare, epic }` — counts; **meta**, survives
  `resetToFreshHero` (add to its preserve list)
- `activeRoll: 'common' | 'uncommon' | 'rare' | 'epic' | null` — **run-scoped**,
  wiped by `resetToFreshHero`; consumed by the next reward generation (D7)

**Player helpers** (`entities/Player.js`): `buyRoll(tier)` (spends the calling
site's currency, increments inventory), `setActiveRoll(tier | null)`
(swap/return per D8), `consumeActiveRoll()` → returns tier or 'common',
clears the key.

## Kanji tier system (D11)

Every ability's `kanjiPool` (5 chars) carries per-kanji tiers for the run:

- storage: `loadout.kanjiTiers = { abilityId: { char: 'blue' | 'purple' | 'silver' } }`
  (absent char = green); run-scoped, wiped by `resetToFreshHero`
- tier multipliers: green ×1.0 · blue ×1.15 · purple ×1.3 · silver ×1.5,
  applied on top of the existing challenge quality multiplier
- plumbing (same pattern as today's `activeKanjiBonus`): the challenge
  resolver (`WeaponKanjiChallengeSystem.resolve`, plus the setup_defence /
  parry paths) looks up the drawn kanji's tier and sets
  `player.activeKanjiTierMult` before `executeSkill`; `TurnManager` multiplies
  it into the attack and the field is cleared per action
- card: `kanji_tier_up` effect — pick a random char from the ability's pool,
  raise one tier (max silver); family `ability`
- UI: tint the drawn kanji / hint in the challenge overlay by tier

## Sites & economy — end state

| Site | Currency | Sells (after cutover) |
|---|---|---|
| Home scales shop (`HomeShopScene`) | scales (+ source) | **Rolls** 5/10/18/25, permanent weapon upgrade (5 scales + 1 source — ouro source keeps this current sink; permanent shield track + legendary roll noted as future options), chest, memory/cascade games |
| Rest camp (`RestScene`) | free + gold | Heal 40%, weapon/shield upgrade (gold), **rolls** 50/100/180/250 gold |
| Gold shop (`ShopScene`) | gold | Weapon/shield upgrades (gold), socket charms, potions, items |
| Essence shop (`OuroEssenceShopScene`) | essence | Unchanged (charms, starting gold/potion, ouro source/scale) |
| Reward screen | — | 3 upgrade cards at active-roll tier + kanji reroll |

Identity: **scales buy run-RNG control + permanent equipment · gold buys
run goods + rolls · essence buys the meta charm collection · cards build
the run.**

---

## Phase 1 — Engine core (data + run state + resolver)

**Goal:** upgrades exist as data, can be applied to run state, and the ability
resolver flows through combat math. No UI yet.

1. **`data/upgrades.json`** — initial 12-card pool (covers every effect type):
   - stat: `might` (+1 str), `life` (+1 vit), `insight` (+1 luck)
   - flat: `stamina_1` (+1 Energy), `capacity_1` (+1 slot)
   - conversion: `sharp_weapon`, `heavy_weapon` (exclude each other)
   - unlock: `quick_stab_unlock`
   - ability modifier: `sharpened_slash` (+10% forward_slash dmg, max 3),
     `deep_cut` (quick_stab applies bleed 2)
2. **`systems/UpgradeEngine.js`** — load JSON, `apply(player, upgradeId)`:
   - `stat` → `player.baseStats[stat]++` + recalc
   - `flat_stamina` → `loadout.staminaFlatBonus++` + `recalcMaxStamina()`
   - `flat_active_slot` → `loadout.activeSlotBonus++` + `refreshActions()`
   - `weapon_profile` → `loadout.weaponProfileOverride = profile`
   - `unlock_ability` → existing `addAbilityCharges(id, 1)` (adds to known +
     auto-equips; stays valid after D10 since charges become no-ops — it is
     simply the "learn ability" path)
   - `ability_modifier` → push to `loadout.runUpgrades`
   - enforces stack limits; returns `{ok, reason}`
3. **`entities/Player.js`**
   - fresh-loadout defaults + `resetToFreshHero` handling:
     run-scoped: `runUpgrades: []`, `staminaFlatBonus: 0`,
     `activeSlotBonus: 0`, `weaponProfileOverride: null`, `activeRoll: null`,
     `kanjiTiers: {}` (+ wipe of `statAllocations`/`statPoints` — cutover)
     meta (preserve): `rollInventory: {common:0, uncommon:0, rare:0, epic:0}`
   - `getKanjiTier(abilityId, char)` helper (D11)
   - `getBaseScaling()`: when `loadout.weaponProfileOverride` set, use the
     scaling block from the matching `data/socketCharms/primary_weapon.json`
     entry
   - `recalcMaxStamina()`: `+ (this.loadout.staminaFlatBonus || 0)`
   - `refreshActions()`: `maxActiveSlots = getMaxActiveActions(...) + (activeSlotBonus || 0)`
   - **`getEffectiveAbility(action)`** — merges ability modifiers into
     `{ ...action, staminaCost (min 1), damageMultiplier, critChanceBonus,
     critDamageBonus, onHitEffects, executeBonus, doubleHit }`
   - `skillUnavailableReason()`: effective stamina cost; Quick Stab /
     Guard Break gates become `socketCharmIds[0] === X || hasRunUnlock(X)`
   - roll helpers (buy/setActive/consume, see Rolls system)
   - **charges deleted (cutover):** drop `singleUseCharges` from loadout,
     remove `consumeAbilityCharge`/`addAbilityCharges`/`getAbilityCharges`;
     `learnAbility` grants the ability permanently (run-scoped); `singleUse`
     flag ignored in `canUseSkill`
4. **`systems/TurnManager.js`** — attack branch consumes the effective ability:
   - `total *= eff.damageMultiplier` after the challenge multiplier
   - crit: `floor(total * (1.5 + eff.critDamageBonus))`
   - execute: `target.hp / target.maxHp < 0.25` → `total *= 1 + eff.executeBonus`
   - double-hit: two hits at 60% (second hit no re-crit)
   - on-hit effects via the existing `StatusEffectSystem`/`EffectRegistry` path
   - **kanji tiers (D11):** `total *= (player.activeKanjiTierMult || 1)` with
     the field set by the challenge resolvers (`WeaponKanjiChallengeSystem`
     plus the setup_defence / parry paths via `getKanjiTier`) and cleared per
     action
5. **Verification (headless node harness):**
   - `might` ×3 → strength +3; `stamina_1` ×2 → maxStamina exactly +2
   - `sharp_weapon` → effective scaling matches sharp charm rules
   - `sharpened_slash` ×3 → damageMultiplier 1.3
   - `deep_cut` → quick_stab has onHitEffects bleed 2
   - rolls: buy → inventory++; setActive replaces per D8; consume → tier returned,
     key cleared; `resetToFreshHero` wipes activeRoll but keeps rollInventory
   - kanji tiers (D11): apply `kanji_tier_up` → random pool char raised one
     tier; `getKanjiTier` returns it; silver is the cap
   - `resetToFreshHero` clears all other run keys

---

## Phase 2 — Generator

**Goal:** `generateChoices(player, tier = 'common')` returns 3 valid, weighted,
unique cards honoring the roll floor.

1. **`systems/UpgradeGenerator.js`**
   - floor: `tier !== 'common'` → reserve slot 1 and roll it at the tier's
     rarity band (uncommon+ / rare+ / epic), weighted within the band by the
     normal relative weights; slots 2–3 roll on the normal table
   - filter: owned uniques/conversions excluded; exclusions of owned cards;
     prerequisites present in `loadout.runUpgrades`
   - weighting: `1 + tagMatches × 0.5` (owned upgrade tags + weapon profile
     family + dominant stats)
   - rarity roll: common 55 / uncommon 30 / rare 12 / epic 3 (constants at top)
   - card quality rule: if all 3 share one family and none are ability
     modifiers, reroll the lowest-weighted one (max 2 attempts)
2. **Tests (headless):** 500 generations at each tier — floor never violated,
   no excluded pairs, no duplicate uniques; distribution sanity.

---

## Phase 3 — Player-visible: reward screen, reroll, roll activation

**Goal:** after eligible wins → 3 cards at the active roll's tier → optional
kanji/word reroll (same tier) → pick one.

1. **`scenes/UpgradeScene.js`** (new, ~250 lines, modeled on EventScene):
   - on create: `tier = player.consumeActiveRoll()`; cards from
     `UpgradeGenerator.generateChoices(player, tier)` (D7: if this screen
     wasn't reached, the roll was never consumed)
   - 3 cards + `[REROLL — KANJI] (n)` using the existing WinChallengeSystem
     pass/fail flow; success → regenerate at the **same tier**; failure →
     cards stay, reroll consumed
   - choose → `UpgradeEngine.apply()` → `scene.start(returnScene, {player})`
   - destroy challenge systems in `shutdown()` (copy BattleScene's pattern)
2. **`scenes/WinScene.js`**:
   - D1: gamble multiplies gold/essence only
   - after existing rewards: `scene.start('UpgradeScene', ...)` gated by D4
     frequency; skipped when the generator pool is empty
3. **`scenes/LoadoutScene.js`** — active-roll selector (the "trigger before
   battle" UI): one row showing `activeRoll` + inventory counts
   (`Common ×2 · Uncommon ×1 …`); tap a tier to activate/replace per D8, tap
   the active one to deactivate (returns to inventory). Visible in both
   'map' and battle-prep modes.
4. **`systems/WinChallengeSystem.js`** — extract `runPassFail(onPass, onFail)`
   (no multiplier) for the reroll.
5. **Manual check (tablet):** win → cards → reroll pass/fail → choose → map;
   roll activation/replacement in LoadoutScene; roll survives a no-reward
   battle (D7); roll gone after a reward screen.

---

## Phase 4 — Sites & economy cutover

1. **`scenes/HomeShopScene.js`** (scales shop):
   - remove the `stat_point` item **and** `weapon_upgrade_run` (run-scoped
     weapon power belongs to upgrade cards)
   - add 4 roll items at 5 / 10 / 18 / 25 scales (existing `buyItem`/`spend`
     pattern → `player.buyRoll(tier)`); show inventory counts per row
   - kept: permanent weapon upgrade, chest, memory/cascade games
2. **`scenes/RestScene.js`**:
   - add roll purchase alongside Rest / equipment upgrades: 4 tiers at
     **50 / 100 / 180 / 250 gold** (10× the scales price — one ratio);
     same `player.buyRoll(tier)` into the shared inventory
   - the existing one-action-per-visit rule applies to roll purchases too
3. **`scenes/ShopScene.js`** (gold shop) — decision 2a:
   - ability stock **removed entirely** (D10 — no charges to recharge);
     weapon/shield upgrade buttons, socket charms, potions, items unchanged
4. **`entities/Player.js`** — delete the stat-point system outright:
   remove `permanentStatPointBonus` from `totalStatPoints`, delete the
   charges system (already gone in Phase 1), treat all abilities as multi-use.
   Stat allocation UI goes in Phase 5.
5. The stats tab in LoadoutScene is **not removed yet** (Phase 5) — points
   simply stop flowing in.

---

## Phase 5 — Loadout UI + full content pool

1. **`scenes/LoadoutScene.js`** — replace the stats tab:
   - top: derived readouts (Max HP, Energy/turn, Active slots, Battle-pool,
     Crit%, Phys/Elem def) — existing getters
   - below: "Run Upgrades" list from `loadout.runUpgrades` (name, rarity,
     stacks); the roll selector row from Phase 3 moves here permanently
   - remove `+` buttons / `statAllocations` UI (construction-time application
     of legacy allocations stays, D2)
2. **`data/upgrades.json`** — full pool per design §44 (~45 cards): all stat
   cards, Stamina I–V chain, Capacity I–IV, Heavy/Sharp/Fire/Wind routes,
   weapon/shield conversions, defensive set, knowledge set, ability pools
   for forward_slash, quick_stab, setup_defence, flame_arc, gale_strike,
   guard_break, seismic_slam — each ability pool including its
   **kanji attunement cards** (D11, random pool kanji +1 tier).
3. Knowledge effects: `rerollsLeft` per screen = 1 + Curiosity; Memory /
   Recall / Perfect Recall / Enlightenment as generator/scene params.
4. **Balance pass:** rarity weights, D4 frequency, roll prices
   (5/10/18/25 scales · 50/100/180/250 gold), scales/gold income pacing,
   **stamina-cost rebalance for former single-use abilities** (D10),
   **kanji tier multipliers** (D11).

---

## Phase 6 — Final cleanup

1. Remove remaining stat-point grant path (`WinScene.baseAttributePoints`,
   gamble point multiplier, `statPoints` HUD counter) and the charges
   remnants (`singleUseCharges` save key, `consumeAbilityCharge`/
   `addAbilityCharges`, WinScene "+1 use" collect path).
2. Dead effect cleanup: wire `staminaRegen` charms to a turn-start regen proc
   (`SocketProcSystem` pattern) or convert them to `staminaFlatBonus`.
3. Bump `MAP_VERSION` (stale localStorage saves get a fresh run).
4. Cache bump + bundle + deploy.

---

## Out of scope (explicitly)

- Enemy/NG+ balance beyond rarity weights; new elements for
  earth/poison/dark/light until their mechanics exist
- Hybrid weapon profiles, cooldown systems
- Any server/Elixir changes (all state lives in the existing loadout save)
- **"Smart charms" (future):** hero charms stay as background stat-ups for
  now. When desired, new `getCharmEffects()` keys can modulate the upgrade
  system with no schema change — e.g. `cardTierBoost` (generator rolls
  matching-tag cards one rarity band higher), `upgradeValueBoost` (scales a
  specific card's numbers), `familyWeightBoost` (generator tag weighting).
  All are read-side consumers in `UpgradeGenerator`/`UpgradeEngine`.

## Rollback

The rework lives on a dedicated branch; rollback = don't merge. Individual
phases are ordered so the branch is playable from Phase 3 onward, but no phase
is required to keep the old stat-point/charge system alive beside the new one.
