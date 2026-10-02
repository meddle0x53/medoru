# Roguelike Upgrade System — Code-Aligned Revision

> Companion to `The Hollow Ouroboros — Production Upgrade System` design doc.
> This revision maps every concept to the actual codebase: what already exists
> and can be reused, what needs new engine support (with file/function
> anchors), real ability/effect ids, and a migration plan keyed to real files.
> Nothing here is implemented yet.

---

## 1. Concept → code mapping (what the plan gets for free)

| Plan concept | Existing code | Notes |
|---|---|---|
| Weapon "profile conversion" (Heavy/Sharp/Fire/Water/Wind/Lucky Weapon, Lucky Edge) | **Already exists** as the socket-charm scaling rewrite: `getEffectiveScaling()` (`entities/Player.js`) applies `fixed` / `milestones` / `null` rules from `data/socketCharms/primary_weapon.json` | The upgrade version applies the same JSON to a run-scoped `weaponProfileOverride` instead of a socketed charm. Zero new scaling math needed. |
| Ability-family unlocks (Gutting Slash, Seismic Slam, Flame Arc, Gale Strike) | **Already exists**: `data/abilityFamilies.json` + `getSocketCharmFamily()` + family injection in `data/abilityRewards.js` | Upgrades write to `loadout.unlockedAbilityIds` via the existing `learnAbility()` / `addAbilityCharges()` path instead of the charm-family path. |
| Quick Stab / Guard Break gates | `Player.skillUnavailableReason()` currently requires `sharp_charm_sword` / `heavy_charm_sword` in socket 0 | Under the new system these become upgrade-unlocked run flags; the charm-socket gate becomes an OR condition. |
| Kanji/word challenge for rerolls | **Already exists**: `systems/WinChallengeSystem.js` (kanji draw → word challenge), `KanjiDrawingSystem`, `WordChallengeSystem`, `freeKanjiPools.js` | The reroll reuses this whole pipeline; only the reward-screen wiring is new. |
| Status effects (Bleed, Burn, Poison, Weak…) | **Already exists**: `systems/EffectRegistry.js` (`bleed`, `burn`, `poison`, `weak`, `blunt`, `frost`, `madness`, `stamina_crash`, `slow`, `electrified`, `void_touched`, `blaze`, `magma`, …) | "Deep Cut: apply Bleed 2" = `inflict_status` with a snapshot value — same shape as `venom_edge_charm_sword`. |
| Single-use / charges model | `loadout.singleUseCharges`, `consumeAbilityCharge()`, `addAbilityCharges()` | Plan's "Eternal Guard / +charges" modifiers hook directly into this. |
| Stat-derived combat formulas | All existing (see `docs/game_stats_scaling_charms_reference.md`) | +1 STR/VIT/… upgrades literally reuse today's `baseStats` increment path (what the `+` button in LoadoutScene does today). |
| Reward screen | `scenes/WinScene.js` (post-battle rewards, gamble challenge) | Upgrade cards replace the `+N attribute points` grant; the gamble challenge may be superseded or coexist with the reroll challenge. |
| Save / run-scoped state | `player.loadout` persists everything; `resetToFreshHero()` wipes run state on death/daily | Run upgrades live in loadout (like `beingLearnedWords`); death clears them automatically. |
| NG+ economy | `getNgPlusMultiplier()` = 1.5^n already multiplies rewards | Can also shift upgrade rarity weights per NG+ level. |

---

## 2. Real ids and names (use these, not the plan's paraphrases)

**Abilities** (`data/abilities/warrior.json`, 29 total):

- Starters: `forward_slash`, `setup_defence`, `shield_parry`, `use_item`
- The plan's "Guard" = **`setup_defence`** (defence) and/or **`shield_parry`** (parry) and **`raise_shield`** (single-use defence)
- "Quick Stab" = `quick_stab` (single-use, charm-gated)
- "Guard Break" = `guard_break` (single-use, requires `heavy_charm_sword` in socket 0 today)
- "Seismic Slam" = `seismic_slam` (heavy family)
- "Flame Arc" = `flame_arc` (fire family)
- "Gale Strike" = `gale_strike` (wind family)
- "Gutting Slash" = `gutting_slash` (bleed family, multi-use)
- Also existing and relevant: `heavy_slash` (single-use heavy finisher), `two_hand_heavy`, `shield_bash`, `dash`, `taunt`, `zen`, `focus`, `berserk`, `sword_buff`, `sheathe_blade`, `infuse_fire/water/wind/earth/void/frost/bleed/poison`

**Effects** (`systems/EffectRegistry.js`): `bleed`, `burn`, `poison`, `weak`, `blunt`, `frost`, `madness`, `stamina_crash`, `slow`, `electrified`, `void_touched`, `blaze`, `magma` (+ more)

**Resources**: the plan's "Energy" = **stamina** in code (`player.stamina`, `maxStamina`).

**Reward stat points today**: `WinScene.baseAttributePoints = enemy.level + luckProc`, multiplied by gamble challenge × NG+ — this is the grant the upgrade cards replace.

---

## 3. Engine changes required (new code, with anchors)

### 3.1 Run-scoped upgrade storage — NEW

```js
// loadout (persisted, wiped by resetToFreshHero):
loadout.runUpgrades = [
  { id: 'might', stacks: 2 },
  { id: 'stamina_1' },
  { id: 'sharp_weapon' },                       // conversion
  { id: 'quick_stab_bleed', abilityId: 'quick_stab' },
]
loadout.weaponProfileOverride = 'sharp_charm_sword' | null   // reuses existing scaling JSON
loadout.rerollsLeft = 1                                       // per reward screen, reset by generator
```

`resetToFreshHero()` already clears run-scoped keys — add these to the `meta`
preserve/reset lists (`entities/Player.js` ~1517).

### 3.2 Ability modifier resolver — NEW (core engine)

**Never mutate ability objects from `ALL_ACTIONS`** — they are shared module
singletons; mutating them would leak modifiers across runs and saves. Instead:

```js
// entities/Player.js
getEffectiveAbility(action) {
  const mods = this.collectAbilityModifiers(action.id)  // from runUpgrades
  return {
    ...action,
    staminaCost: Math.max(1, action.staminaCost - mods.costReduction + mods.costIncrease),
    damageMultiplier: 1 + mods.damagePct,             // e.g. Sharpened Slash ×3 stacks
    critChanceBonus: mods.critChance || 0,
    onHitEffects: mods.onHitEffects || [],            // [{effectId:'bleed', value:2}, ...]
    executeBonus: mods.executeBonus || 0,             // vs <25% HP
    critDamageBonus: mods.critDamageBonus || 0,
    doubleHit: mods.doubleHit || false,
  }
}
```

Consumers to update (currently read raw `action` fields):
- `Player.skillUnavailableReason()` — stamina cost check → effective cost
- `TurnManager.useSkill()` — damage multiplier & on-hit effects applied in the
  attack branch (~line 280), crit multiplier currently hardcoded ×1.5 (~line 294)
  → `1.5 + critDamageBonus`; execute bonus & double-hit also hook here
- `Character.getCritChance()` — add `+ critChanceBonus` for that ability path
  (thread the effective ability through, or read from a per-attack field set by
  TurnManager)
- `BattleScene` UI labels (`getSkillButtonLabel`, tooltips) — effective cost/damage
- `Enemy.js` is untouched (modifiers are player-side)

### 3.3 Flat "+1 Energy" stamina bonus — SMALL CHANGE

`Player.recalcMaxStamina()` is `8 + floor(getStatValue('stamina')/3)`. Add the
run flat bonus so stamina upgrades are exactly +1 energy and never depend on
thresholds:

```js
this.maxStamina = 8 + Math.floor(this.getStatValue('stamina') / 3)
                + (this.loadout.staminaFlatBonus || 0)
```

Stamina upgrade cards increment `loadout.staminaFlatBonus` (cap 5 per plan) and
call `recalcMaxStamina()`. The internal stat can still drift via +STA-flavored
cards, but the player never sees the formula.

### 3.4 Flat "+1 active slot" capacity bonus — SMALL CHANGE

`getMaxActiveActions(capacity)` is threshold-based (3/4/5/6 @ 15/35/60). Add a
run bonus on top of the threshold result in `Player.refreshActions()` (~573):

```js
const thresholdSlots = getMaxActiveActions(this.getEffectiveCapacity())
this.maxActiveSlots = thresholdSlots + (this.loadout.activeSlotBonus || 0)  // cap +4 per plan
```

Also apply to battle-pool/overall caps if capacity upgrades should affect them
(decision needed — plan says active slots only).

### 3.5 Weapon profile override — SMALL CHANGE

`getBaseScaling(equipment)` (~115) currently reads `equipment.scalingSchedule`.
When `loadout.weaponProfileOverride` is set, swap in the scaling block from the
matching `data/socketCharms/primary_weapon.json` charm entry (they already
carry `fixed`/`milestones`/`null` rules). Mutual exclusions (§26 of the plan)
are enforced by the generator, not here.

### 3.6 Upgrade reward screen — NEW SCENE

`scenes/UpgradeScene.js` (or a WinScene section):
- 3 cards (id, name, rarity, family, description) — reuse `createButton` patterns
- `[REROLL — KANJI]` button → runs the existing `WinChallengeSystem`-style
  challenge; success → regenerate 3 cards; failure → keep original, consume reroll
- On choose: apply via `UpgradeEngine.apply(upgrade)` → then continue to map
- Wired from `WinScene` (replaces the `+attributePoints` grant; gold/essence/ability
  rewards can stay as-is or be folded into the card pool — decision needed)

### 3.7 Upgrade generator — NEW MODULE

`systems/UpgradeGenerator.js` + `data/upgrades.json` (schema mirrors the
socket-charms/abilities JSON conventions):

```json
{
  "id": "sharpened_slash",
  "name": "Sharpened Slash",
  "rarity": "common",
  "family": "power",
  "tags": ["ability", "slash", "damage"],
  "abilityId": "forward_slash",
  "stacking": "stackable",
  "maxStacks": 3,
  "excludes": [],
  "effect": { "type": "ability_modifier", "damagePct": 0.10 }
}
```

Pipeline exactly as plan §28: filter unavailable → prerequisites → exclusions →
tag-weighted (current run state) → rarity weights → 3 unique. Weight source:
count tags of already-held upgrades + current weapon profile + dominant stats.

### 3.8 Reroll challenge wiring — REUSE

`WinChallengeSystem.run()` already does kanji-draw → word-challenge with a
success/fail callback and a multiplier — clone/split it so the reward screen
can call the same two challenges with a pass/fail outcome (no multiplier).
Free-kanji-mode pools apply automatically (`getEffectiveKanjiPool`).

---

## 4. Design deltas & decisions the plan needs to make (code realities)

1. **The LoadoutScene stats tab must go or change.** Today it shows the raw
   7-stat allocation UI (`Base X + Alloc Y = Z`). Under the new system there
   is nothing to allocate — replace with an "Upgrades this run" list
   (`loadout.runUpgrades` rendered as cards/chips) + derived readouts
   (HP, Energy, slots, crit%) which players still need to see.
2. **`statAllocations` legacy saves.** Either (a) keep applying them at
   construction (harmless, they're just pre-run bonuses) or (b) migrate:
   convert existing `statAllocations` into equivalent upgrade entries once.
   Recommend (a) initially — zero migration risk.
3. **`permanentStatPointBonus`** (meta) currently feeds battle rewards.
   With stat points gone, repurpose it (e.g. +1 upgrade choice at every Nth
   reward) or retire it. Decision needed.
4. **Crit damage** is hardcoded ×1.5 in `TurnManager` — plan's "Critical Form"
   and "Killing Point" need the `critDamageBonus` hook (§3.2).
5. **Execute (<25% HP)** has no existing hook — add in the TurnManager attack
   branch, reading `target.hp / target.maxHp`.
6. **"Guard" ambiguity**: `setup_defence` is multi-use already; the single-use
   defence is `raise_shield`. "Eternal Guard" should target `raise_shield`
   (make it non-consumed), not `setup_defence`.
7. **Quick Stab / Guard Break charm gates** become
   `charm-in-socket OR upgrade-unlocked` in `skillUnavailableReason()`.
8. **Gamble challenge vs reroll**: WinScene's gamble multiplies the whole
   reward. With upgrade cards, decide: (a) gamble removed, reroll replaces it;
   (b) gamble multiplies gold/essence only, reroll handles cards. Recommend (b).
9. **Reward frequency**: WinScene currently rewards after every non-boss win
   (points) + abilities sometimes. Plan says "not every battle". Bosses/mini-bosss
   guarantee cards; normal battles roll a chance (map column can modulate).
10. **Death already works**: `resetToFreshHero()` on death/daily wipes run
    keys — add the new keys to its reset list and §42 of the plan is satisfied
    with no new persistence code.
11. **Dead `staminaRegen` effect** (Kitsune Tail, Charm of Water) — plan §34
    already flags it; the natural fix under this system is a flat
    `staminaFlatBonus`-style regen hook at turn start (Wind Spirit proc point,
    `SocketProcSystem` shows the pattern).
12. **Enemy side**: unchanged. `NG_PLUS_ABILITY_NUMERIC_KEYS` scaling stays;
    NG+ can raise upgrade rarity weights instead of raw enemy growth later.

---

## 5. Migration plan (phases → real files)

**Phase 1 — Upgrade engine**
- `data/upgrades.json` (initial pool per plan §44)
- `systems/UpgradeEngine.js` — schema, stacking rules, exclusion checks,
  `apply(upgrade)` (writes run keys; stat cards reuse the `baseStats` increment,
  stamina/capacity cards write flat bonuses, unlock cards call
  `learnAbility`/`addAbilityCharges`, conversions set
  `weaponProfileOverride`)
- `entities/Player.js` — run keys, `getEffectiveAbility()`, flat bonuses,
  `resetToFreshHero()` reset list

**Phase 2 — Generator**
- `systems/UpgradeGenerator.js` — filtering, tag weighting, rarity weights,
  3-unique selection, duplicate/stack-count handling

**Phase 3 — Reward screen**
- `scenes/UpgradeScene.js` (new) — cards + choose + reroll button
- `scenes/WinScene.js` — replace `attributePoints` grant with scene handoff;
  keep gold/essence/ability rewards
- `systems/WinChallengeSystem.js` — expose a pass/fail (non-multiplier) mode

**Phase 4 — Ability modifiers**
- `TurnManager.js` — damage/crit/execute/double-hit/on-hit hooks
- `Player.js` — `getEffectiveAbility()` + consumers (§3.2 list)
- `BattleScene.js` — effective cost/damage in labels & `onSkillClick` gating

**Phase 5 — Loadout UI**
- `scenes/LoadoutScene.js` — replace stats tab with upgrades list + derived
  readouts; keep charm/equipment/ability tabs

**Phase 6 — Knowledge upgrades**
- Reroll counters (`loadout.rerollsLeft`, Curiosity/Memory/Recall effects)
  in generator + UpgradeScene
- Enlightenment (4 cards) — generator param

**Phase 7 — Balance**
- `data/upgrades.json` values, rarity weights, reward frequency per enemy
  tier; NG+ weight curve

**Deliberately untouched:** `Enemy.js`, `EffectRegistry.js`,
`socketCharms/*.json`, `abilityFamilies.json`, `freeKanjiPools.js`,
`GameSaves`/API controller, daily-challenge flow.

---

## 6. Suggested initial `data/upgrades.json` seeds (code-shaped)

Stat/flat cards map 1:1 to existing math (cheapest to build first):

```json
{ "id": "might",      "rarity": "common",   "family": "power",        "stacking": "stackable", "maxStacks": 99, "effect": { "type": "stat", "stat": "strength", "value": 1 } }
{ "id": "life",       "rarity": "common",   "family": "survivability","stacking": "stackable", "maxStacks": 99, "effect": { "type": "stat", "stat": "vitality", "value": 1 } }
{ "id": "stamina_1",  "rarity": "rare",     "family": "survivability","stacking": "unique",   "effect": { "type": "flat_stamina", "value": 1 } }
{ "id": "capacity_1", "rarity": "rare",     "family": "survivability","stacking": "unique",   "effect": { "type": "flat_active_slot", "value": 1 } }
{ "id": "sharp_weapon","rarity": "rare",    "family": "weapon",       "stacking": "conversion", "excludes": ["heavy_weapon","lucky_edge"], "effect": { "type": "weapon_profile", "profile": "sharp_charm_sword" } }
{ "id": "quick_stab_unlock","rarity": "rare","family": "power",      "stacking": "unlock",   "effect": { "type": "unlock_ability", "abilityId": "quick_stab" } }
{ "id": "deep_cut",   "rarity": "rare",     "family": "ability",      "stacking": "unique", "abilityId": "quick_stab", "effect": { "type": "ability_modifier", "onHitEffects": [{ "effectId": "bleed", "value": 2 }] } }
```

---

## 7. What stays exactly as the original plan says

Everything in the original document about: rarity philosophy (§4), family
definitions (§6), stacking taxonomy (§25), mutual exclusions (§26), duplicate
handling (§27), three-card quality rules (§30), reroll default rules (§31),
site-XP-unlocks-content-not-power (§32), hero charms remain persistent (§34),
equipment stays persistent (§35), death/reset semantics (§42), and the
production design rules (§45) — all unchanged and all compatible with the code
mapping above.
