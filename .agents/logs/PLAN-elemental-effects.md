# Plan: Elemental Effects & Status System

**Status:** Draft — design data for upcoming ability definitions.  
**Goal:** Turn the combat mechanics described in the conversation into a small, data-driven status/effect system so abilities can be defined by referencing IDs, chances, and durations rather than hard-coding behavior.

---

## 1. Concepts

### 1.1 Elements

Every attack or defence has an element. For now the active combat elements are:

| Element | Code | Notes |
|---------|------|-------|
| Fire | `fire` | High risk / high reward DoT. |
| Water | `water` | Weakens, extinguishes burn, can freeze. |
| Wind | `wind` | Bleed, extends burn, cures weak. |
| Earth | `earth` | Blunt burst damage. |
| Void | `void` | Madness / random debuffs. |
| Poison | `poison` | Slower DoT, cured by antidote / special heal. |
| Dark | `dark` | Treated as `void` until later design. |
| Light | `light` | Treated as `void` until later design. |

### 1.2 Status Effects

A status effect is a timed modifier applied to a combatant. It can:

- deal damage on tick (DoT),
- reduce damage dealt (WEAK),
- increase damage taken,
- alter stamina regeneration,
- block/nullify incoming attacks of a specific element,
- trigger extra effects when the bearer is hit.

### 1.3 Progressive Chance

Several elemental triggers get more likely each time the **same element** is used consecutively against the same target. The sequence resets when a different element hits or when the effect triggers.

Formula used by the engine:

```text
chance = base + step * (consecutiveHits - 1)
chance = min(chance, cap)
```

Example for wind bleed: base 5%, step 5%, cap 25%.

---

## 2. Effect Catalog

Each row is a status effect definition the ability data will reference.

| ID | Name | Category | Stack Rule | Duration (turns) | Tick Damage | Other Rules |
|----|------|----------|------------|------------------|-------------|-------------|
| `burn` | Burned | debuff | replace (stronger application wins) | 3–5 | 75% of **initial fire damage** per turn | Applied by fire attacks. |
| `poison` | Poisoned | debuff | replace | 5–10 | 50% of **initial poison damage** per turn | Cured by antidote / special heal. |
| `weak` | Weak | debuff | refresh duration | 2–3 | — | Damage dealt reduced to 75%. Applied by fire (self), water (target), and madness. |
| `bleed` | Bleed | debuff | refresh / stack charges (design choice) | until triggered | 10% of target **max HP** when triggered | Applied by wind; triggers on next wind hit or next physical hit? Suggested: triggers on next damage instance. |
| `blunt` | Blunt | one-off | — | instant | — | The triggering earth attack deals double damage. |
| `frost` | Frost | debuff | replace | 1–2 | — | Next turn max stamina is halved; incoming damage +25%. |
| `madness` | Madness | debuff | refresh | 1–3 | — | On apply: randomly inflict one bad effect from `{burn, bleed, frost, weak, poison}` OR halve stamina next turn. |
| `ember` | Ember (self) | debuff | replace | 3–5 | 75% of **initial fire damage** total, spread per turn | Self-recoil when a fire attack ignites the target. |
| `power_up` | Power Up | buff | refresh | 1–3 | — | Successful attacks deal +25% damage. |
| `fire_guard` | Fire Defence | buff | refresh | 2–4 | — | Earth attacks are nullified. Removed by water attacks. |
| `water_guard` | Water Defence | buff | refresh | 2–4 | — | Heals burn; fire attacks are nullified. Removed by wind attacks. |
| `wind_guard` | Wind Defence | buff | refresh | 2–4 | — | Water attacks are nullified; removes weak. Removed by earth attacks. |
| `earth_guard` | Earth Defence | buff | refresh | 2–4 | — | Wind attacks are nullified. Removed by earth attacks. |
| `void_guard` | Void Defence | buff | refresh | 2–4 | — | Void effect chances are halved. Also grants a random one of `{fire_guard, water_guard, wind_guard, earth_guard}`. |

### 2.1 Notes / Clarifications

- **Burn self-penalty:** When a fire attack successfully inflicts `burn`, the attacker also receives `weak` and `ember`. This makes fire high-risk. The exact numbers are data knobs.
- **Bleed trigger:** Suggested rule — once `bleed` is applied, the next damage instance the target receives consumes it and deals the 10% max-HP bonus. This keeps wind’s identity as a “setup then punish” element.
- **Madness:** The random effect should be resolved once on apply and stored, not re-rolled every turn, so the UI can show the player what madness caused.

---

## 3. Element vs Defence Matrix

When an attack element meets an active defence buff on the target, the following happens before normal damage calculation:

| Attack \ Defence | `fire_guard` | `water_guard` | `wind_guard` | `earth_guard` | `void_guard` |
|------------------|--------------|---------------|--------------|---------------|--------------|
| **fire** | damage only | nullified, also removes burn if present | normal | normal | normal; void chance halved |
| **water** | removes guard | normal | normal; if target has burn, burn removed | normal | normal; void chance halved |
| **wind** | normal | removes guard | normal; removes weak | normal | normal; void chance halved |
| **earth** | nullified | normal | removes guard | removes guard | normal; void chance halved |
| **void** | normal | normal | normal | normal | chance halved |
| **poison** | normal | normal | normal | normal | normal |

Rules encoded from the conversation:

- Fire defence blocks earth.
- Water defence heals burn and blocks fire.
- Wind defence blocks water and removes weak.
- Earth defence blocks wind and is removed by earth.
- Void defence halves void effect percentages and gives a random other guard.

---

## 4. Progressive Chance Table

Used by the engine to compute trigger chance based on consecutive same-element hits.

| Effect | Base | Step | Cap | Reset Condition |
|--------|------|------|-----|-----------------|
| `burn` (fire) | 10% | 5% | 35% | hit with non-fire, or burn triggers |
| `ember` (fire self) | 100% on burn trigger | — | — | — |
| `weak` (water target) | 15% | 5% | 40% | hit with non-water, or weak triggers |
| `frost` (water) | 2% | 2% | 10% | hit with non-water, or frost triggers |
| `bleed` (wind) | 5% | 5% | 25% | hit with non-wind, or bleed triggers |
| `blunt` (earth) | 5% | 5% | 25% | hit with non-earth, or blunt triggers |
| `madness` (void) | 5% | 5% | 25% | hit with non-void, or madness triggers |

These numbers are starting balance values and should live in the ability/effect config, not be hard-coded.

---

## 5. Ability Configuration Schema

An ability JSON object can now describe effects declaratively:

```json
{
  "slug": "ember_slash",
  "name": "Ember Slash",
  "element": "fire",
  "type": "attack",
  "staminaCost": 18,
  "basePower": 14,
  "scalingStat": "strength",
  "scalingMultiplier": 1.0,
  "challengeType": "kanji",
  "challengeKanji": "火",
  "effects": [
    {
      "effectId": "burn",
      "target": "enemy",
      "chance": { "base": 0.10, "step": 0.05, "cap": 0.35 },
      "duration": { "min": 3, "max": 5 }
    },
    {
      "effectId": "ember",
      "target": "self",
      "chance": { "base": 1.0, "step": 0, "cap": 1.0 },
      "duration": { "min": 3, "max": 5 },
      "condition": "burn_applied"
    },
    {
      "effectId": "weak",
      "target": "self",
      "chance": { "base": 1.0, "step": 0, "cap": 1.0 },
      "duration": { "min": 2, "max": 2 },
      "condition": "burn_applied"
    }
  ]
}
```

### 5.1 Defence / Buff Ability Example

```json
{
  "slug": "water_veil",
  "name": "Water Veil",
  "element": "water",
  "type": "defence",
  "staminaCost": 20,
  "baseBlock": 10,
  "effects": [
    {
      "effectId": "water_guard",
      "target": "self",
      "chance": { "base": 1.0, "step": 0, "cap": 1.0 },
      "duration": { "min": 2, "max": 4 },
      "onApply": "cure_burn"
    }
  ]
}
```

### 5.2 Buff Ability Example

```json
{
  "slug": "chi_focus",
  "name": "Chi Focus",
  "element": "void",
  "type": "buff",
  "staminaCost": 25,
  "effects": [
    {
      "effectId": "power_up",
      "target": "self",
      "chance": { "base": 1.0, "step": 0, "cap": 1.0 },
      "duration": { "min": 2, "max": 3 },
      "damageBonus": 0.25
    }
  ]
}
```

### 5.3 Element-Changing Buff

A buff can tag the **next attack** with an element:

```json
{
  "slug": "ignite_stance",
  "name": "Ignite Stance",
  "type": "buff",
  "staminaCost": 12,
  "effects": [
    {
      "effectId": "element_infuse",
      "target": "self",
      "duration": { "min": 1, "max": 2 },
      "element": "fire"
    }
  ]
}
```

When the next damage ability is used, its element is overwritten by the infused element.

---

## 6. Enemy Weakness Schema

Lesser enemies, mini-bosses, and bosses expose elemental weaknesses:

```json
{
  "enemyKey": "kappa_scout",
  "weaknesses": {
    "fire": 1.5,
    "wind": 1.25,
    "earth": 0.75
  },
  "resistances": {
    "water": 0.5
  },
  "immunities": []
}
```

A weakness multiplier applies to the **final damage** of that element before defence nullification. A resistance below 1.0 reduces damage. `immunities` list elements that deal 0 damage.

---

## 7. Suggested Engine Registry

`assets/js/game/systems/EffectRegistry.js` (new file) holds the runtime definitions. It is version-controlled code, while individual abilities pull values from the DB / JSON config.

```js
export const STATUS_EFFECTS = {
  burn: {
    name: 'Burned',
    category: 'debuff',
    tickDamage: { source: 'initialDamage', multiplier: 0.75 },
    duration: { min: 3, max: 5 },
    onApply: 'snapshotInitialDamage',
  },
  poison: {
    name: 'Poisoned',
    category: 'debuff',
    tickDamage: { source: 'initialDamage', multiplier: 0.50 },
    duration: { min: 5, max: 10 },
    curableBy: ['antidote', 'purify'],
  },
  weak: {
    name: 'Weak',
    category: 'debuff',
    damageDealtMultiplier: 0.75,
    duration: { min: 2, max: 3 },
  },
  bleed: {
    name: 'Bleed',
    category: 'debuff',
    triggerDamage: { source: 'targetMaxHp', multiplier: 0.10 },
    consumeOnTrigger: true,
  },
  blunt: {
    name: 'Blunt',
    category: 'one-off',
    damageMultiplier: 2.0,
  },
  frost: {
    name: 'Frost',
    category: 'debuff',
    staminaMultiplier: 0.5,
    damageTakenMultiplier: 1.25,
    duration: { min: 1, max: 2 },
  },
  madness: {
    name: 'Madness',
    category: 'debuff',
    duration: { min: 1, max: 3 },
    onApply: 'rollMadnessOutcome',
  },
  ember: {
    name: 'Ember',
    category: 'debuff',
    tickDamage: { source: 'initialDamage', multiplier: 0.75, spreadOverDuration: true },
    duration: { min: 3, max: 5 },
  },
  power_up: {
    name: 'Power Up',
    category: 'buff',
    damageDealtMultiplier: 1.25,
    duration: { min: 1, max: 3 },
  },
  fire_guard:  { name: 'Fire Defence',  category: 'buff', blocks: ['earth'],       removedBy: ['water'] },
  water_guard: { name: 'Water Defence', category: 'buff', blocks: ['fire'],        removedBy: ['wind'], cures: ['burn'] },
  wind_guard:  { name: 'Wind Defence',  category: 'buff', blocks: ['water'],       removedBy: ['earth'], cures: ['weak'] },
  earth_guard: { name: 'Earth Defence', category: 'buff', blocks: ['wind'],        removedBy: ['earth'] },
  void_guard:  { name: 'Void Defence',  category: 'buff', voidChanceMultiplier: 0.5, bonusGuard: ['fire_guard','water_guard','wind_guard','earth_guard'] },
}
```

### 7.1 Lifecycle Hooks for Effects

`TurnManager` / `BattleScene` call these moments:

- `onApply(effect, ctx)` — snapshot values, resolve madness, apply guards.
- `onTurnStart(effect, ctx)` — tick DoT damage.
- `onTurnEnd(effect, ctx)` — decrement duration, remove expired.
- `onIncomingDamage(effect, ctx, damage)` — apply frost vulnerability, trigger bleed, etc.
- `onOutgoingDamage(effect, ctx, damage)` — apply weak/power-up multipliers.
- `onElementHit(effect, ctx, element)` — handle defence removal / nullification.

---

## 8. UI / Messaging

Each status effect needs a short icon + localized label. Suggested display:

- Small icon next to HP / stamina bar.
- Tool-tip on hover / long-press showing remaining turns and description.
- Combat log line when applied, ticked, or removed, e.g.:
  - "Kappa Scout is Burned (3 turns)."
  - "Ember Slash weakens you."
  - "Water Veil extinguishes the burn."

---

## 9. Open Balance / Design Questions

1. Does `burn` tick at the start or end of the victim’s turn?
2. Should multiple burns stack charges or always refresh?
3. Does `bleed` trigger on **any** damage or only on the next wind/physical hit?
4. Should `madness` be allowed to apply `poison` before poison abilities exist?
5. How expensive should void abilities be? Suggested: 1.5×–2× the stamina of a normal ability.
6. Should self-damage from `ember` ignore player defence, or is it reduced normally?
7. Do dark / light get their own status effects now, or are they strictly void clones?

---

## 10. Recommended Next Steps

1. **Approve this catalog** and answer the open questions.
2. **Create `EffectRegistry.js`** with the definitions above.
3. **Extend `TurnManager`** to run `onTurnStart` / `onTurnEnd` ticks and resolve defence interactions.
4. **Extend ability data** to include `element`, `effects[]`, and `weaknesses`.
5. **Seed a few elemental abilities** (e.g. Ember Slash, Aqua Cut, Gale Step, Stone Smash, Void Gaze) and test in a standalone battle.
