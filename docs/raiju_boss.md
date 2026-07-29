# Raijū, the One-Eyed Storm — Boss Design

> **雷獣・隻眼 (Raijū Sekigan)**  
> *"The Beast That Survived Heaven."*

A wounded thunder-beast that turns its disabilities into a fighting style. The encounter is built around the player's existing toolkit — parries, Dash, Focus, block, combo states, and elemental infusions — rather than raw damage.

---

## 1. Core concept

- No dialogue, no roars: only thunder and a single watching eye.
- High **Skill** gives the Raijū *many* actions and dangerous combos instead of one-shot damage.
- Its missing foreleg makes movement unpredictable: attacks slide, ignore some defence, and punish players who rely on Momentum.
- It evolves through four phases, each changing its sprite set and adding a new passive rule.

---

## 2. Stats

| Stat | Value |
|---|---|
| Level | 8–10 |
| HP | 520–560 |
| STA | 18–22 |
| STR | 10–12 |
| SKL | 16–18 |
| MAN | 18–20 |
| LCK | 14 |
| DEF | 14 |
| ARM | 6 |

Role: `boss`. Intended for map 1 and map 2 boss tiles.

---

## 3. New status effect: Electrified

A single new debuff is enough to make the fight distinctive. It directly attacks the Warrior's defensive toolkit.

```json
{
  "id": "electrified",
  "name": "Electrified",
  "category": "debuff",
  "stackRule": "refresh",
  "duration": { "min": 1, "max": 1 },
  "staminaMultiplier": 0.5,
  "description": "Next Dash cannot critically strike. Parry chance -15%. Stamina regen reduced 50%."
}
```

### Mechanical impact

| System | Current behaviour | With Electrified |
|---|---|---|
| **Stamina regen** | Resets to `maxStamina × staminaMultipliers` at start of player turn | Multiplier 0.5 → half stamina regen |
| **Parry chance** | `base + LCK/100 + readiness×0.20 + quiz ± quality` | Subtract 15 percentage points (floored at 5%) |
| **Dash** | Grants `rushing` (guaranteed crit next attack) | Does **not** grant `rushing` while Electrified |

### Code changes needed

1. Add `electrified` to `STATUS_EFFECTS` in `assets/js/game/systems/EffectRegistry.js`.
2. In `Player.getParryChance()` check `this.getEffectEntry('electrified')` and subtract `0.15`.
3. In `TurnManager` Dash branch, skip `applyComboState(..., 'rushing', ...)` if the performer is Electrified and log *"Electrified! Dash cannot build Rushing."*

---

## 4. Phases

### Phase 1 — The Lame Hunter (100% HP)

Cautious, single-target attacks only. No storms yet.

| Ability | Type | Element | STA | Base | Scaling | Effects | Challenge | Notes |
|---|---|---|---|---|---|---|---|---|
| **Thunder Bite** | attack | void | 3 | 18 | STR × 1.0 | 30% Electrified | none | Fast bite with lingering shock |
| **Broken Pounce** | attack | void | 4 | 14 | SKL × 1.1 | — | none | Consumes player's `momentum` for +50% damage; high skill scaling represents the sliding, defence-ignoring lunge |
| **Lightning Howl** | buff | — | 3 | — | — | Self: `power_up`, +20% evasion | 40% word → `neutralize` | Sets up the signature combo |
| **Watchful Eye** | buff | — | 2 | — | — | Self: `watchful_charge` (+50% next attack damage) | 35% word → `cancel` | Telegraphs a big follow-up |

**Broken Pounce** uses the existing combo-state system:

```json
"combo": {
  "consumesState": {
    "target": "enemy",
    "state": "momentum",
    "damageMultiplier": 1.5,
    "log": "Broken Pounce rips through Momentum!"
  }
}
```

**Watchful Eye** is implemented as a self-buff (`buffType: next_attack_bonus`, value 50%) rather than a reactive punish on Focus. This keeps the mind game — the player sees the boss charging and must decide whether to defend — without adding cross-turn reactive hooks.

---

### Phase 2 — The Empty Eye Opens (≤ 65% HP)

Announcement:

> *"The empty eye bursts open with divine lightning."*

Sprite changes: eye becomes a blazing storm, lightning spreads across the body.

**New passive — Static Charge**

After every second attack, the Raijū gains `static_charge`. Its next lightning ability consumes it for **+25% damage**.

Implementation:

1. Add `static_charge` to `combatStates.json` (buff, short duration).
2. Track an attack counter on the Raijū instance.
3. After every second attack in phase 2+, apply `static_charge` to the Raijū.
4. Lightning abilities are flagged with `"isLightning": true`.
5. In the enemy damage path, if `static_charge` is present and the ability is lightning, multiply damage by 1.25 and consume the state.

| Ability | Type | Element | STA | Base | Scaling | Effects | Challenge | Notes |
|---|---|---|---|---|---|---|---|---|
| **Thunder Dash** | attack | storm | 5 | 16 | SKL × 1.2 | `storm` base: 35% weak, 35% frost | 45% word → `neutralize` | Punishes Dash builds |
| **Chain Lightning** | attack | void | 6 | 8 | MAN × 0.6 | 10% madness per hit | 40% word → `halveChance` | Hits 3 times; hurts block timing |
| **Rolling Storm** | recover | — | 2 | — | — | Recover 8 STA, gain `sake_power`-like +15% damage | 35% word → `weaken` (50%) | Lets the AI keep chaining |

**Chain Lightning** is implemented as a single attack with `damageMultiplier` and an `effect` that applies madness, narratively described as three arcs. To make it mechanically distinct, it has a **low base per hit but three hits total**; in code we model this as one larger damage value plus the madness chance, because the engine resolves one damage call per ability use.

---

### Phase 3 — The Living Storm (≤ 30% HP)

Announcement:

> *"The missing leg explodes into lightning. The Raijū floats."*

Sprite changes: missing leg replaced by a spectral limb of pure lightning; body hovers.

**New passive — Storm Tag**

Every Raijū attack is treated as having the `storm` tag. This is mostly narrative/flavour; it signals that all attacks now carry storm-element base effects (weak + frost).

| Ability | Type | Element | STA | Base | Scaling | Effects | Challenge | Notes |
|---|---|---|---|---|---|---|---|---|
| **Divine Judgment** | attack | storm | 7 | 24 | MAN × 1.3 | `storm` base: weak + frost | 50% word → `weaken` (50%) | Heavy storm damage using the existing combo element |
| **Heaven Splitter** | attack | physical | 6 | 20 | STR × 1.2 | — | 45% word → `weaken` (50%) | Consumes Electrified for ×2 damage; otherwise normal |
| **Eye of Heaven** | buff | — | 4 | — | — | Self: `eye_of_heaven` (perfect accuracy, +50% crit) | 40% word → `cancel` | Next two attacks are terrifyingly accurate |

**Heaven Splitter** consumes the `electrified` debuff from the player:

```json
"consumesEffect": {
  "effectId": "electrified",
  "damageMultiplier": 2.0,
  "log": "Heaven Splitter channels Electrified flesh!"
}
```

This requires a small engine addition: if an ability declares `consumesEffect` and the target has that effect, multiply damage and remove the effect.

**Eye of Heaven** is a new buff effect:

```json
{
  "id": "eye_of_heaven",
  "name": "Eye of Heaven",
  "category": "buff",
  "stackRule": "refresh",
  "duration": { "min": 2, "max": 2 },
  "perfectAccuracy": true,
  "critChanceBonus": 0.50,
  "description": "Perfect accuracy and +50% critical chance for the next attacks."
}
```

In `Enemy.performAction`, while this effect is active the enemy ignores miss chance and adds 50% to its crit roll.

---

### Phase 4 — Unstable Ascension (≤ 10% HP)

The Raijū is dying. Lightning becomes uncontrollable.

**New passive — Lightning Arc**

After every action, there is a **40% chance** to immediately perform a free **Lightning Arc**.

| Ability | Type | Element | STA | Base | Scaling | Effects |
|---|---|---|---|---|---|---|
| **Lightning Arc** | attack | storm | 0 | 10 | MAN × 0.5 | 20% Electrified |

This gives the final phase a frantic, unpredictable rhythm. Sometimes the free arc helps the boss; sometimes it wastes the window it just bought.

Implementation: a phase-specific modifier or a hardcoded check in the enemy-turn loop for the Raijū at phase index 3.

---

## 5. Signature combo

The AI is weighted to prefer this sequence when available:

```
Turn 1: Lightning Howl  (buff)
Turn 2: Thunder Dash    (attack)
Turn 3: Heaven Splitter (attack)
```

To encourage this:

- `Lightning Howl` and `Thunder Dash` have high `aiWeight`.
- `Heaven Splitter` has the highest `aiWeight` among attacks so it is picked once the setup is in place.
- Phase 1 excludes phase-locked abilities; phase 2 unlocks Thunder Dash; phase 3 unlocks Heaven Splitter and Divine Judgment.

The player gradually learns to read the wind-up and respond with block, parry, or cancel challenges.

---

## 6. Player counterplay

| Warrior tool | Why it matters |
|---|---|
| **Setup Defence** | Excellent against Thunder Bite, but Chain Lightning's multi-hit drains block quickly |
| **Shield Parry** | Best answer to Heaven Splitter if timed; Electrified lowers the odds |
| **Dash** | Strong early, but Electrified removes the guaranteed crit |
| **Focus** | Risky — Watchful Eye telegraphs a charged follow-up |
| **Raise Shield** | Great against Heaven Splitter's single big hit |
| **Berserk** | Lifesteal helps survive long phases |
| **Sheathe Blade** | Perfect counter to Broken Pounce's melee slide |
| **Guard Break** → Heavy Slash / Seismic Slam | Staggered combo punishes the boss hard |

The fight does not invalidate the player's toolkit — it forces them to vary it.

---

## 7. Sprites

All main enemy sprites should be **1024×1536 PNGs** to match the existing art pipeline. The engine scales them down via the `layout` block.

| Key | Phase | Pose | Size |
|---|---|---|---|
| `enemy_raiju_phase1_default` | 1 | idle | 1024×1536 |
| `enemy_raiju_phase1_attack` | 1 | attack | 1024×1536 |
| `enemy_raiju_phase1_defend` | 1 | defend / hurt | 1024×1536 |
| `enemy_raiju_phase1_buff` | 1 | buff / howl / eye glow | 1024×1536 |
| `enemy_raiju_phase1_defeated` | 1 | defeated | 1024×1536 |
| `enemy_raiju_phase2_default` | 2 | eye blazing, mane raised | 1024×1536 |
| `enemy_raiju_phase2_attack` | 2 | attack | 1024×1536 |
| `enemy_raiju_phase2_defend` | 2 | defend | 1024×1536 |
| `enemy_raiju_phase2_buff` | 2 | buff | 1024×1536 |
| `enemy_raiju_phase3_default` | 3 | floating, spectral leg | 1024×1536 |
| `enemy_raiju_phase3_attack` | 3 | attack | 1024×1536 |
| `enemy_raiju_phase3_defend` | 3 | defend | 1024×1536 |
| `enemy_raiju_phase3_buff` | 3 | buff | 1024×1536 |
| `enemy_raiju_phase4_default` | 4 | body fracturing into arcs | 1024×1536 |
| `enemy_raiju_phase4_attack` | 4 | unstable lightning burst | 1024×1536 |
| `enemy_raiju_portrait` | any | UI portrait | 512×512 or 1024×1536 |
| `enemy_raiju_icon` | any | map icon | 128×128 |

Until the real sprites are ready, the JSON can point at placeholder keys (e.g. reuse `enemy_danzaburo_default`).

---

## 8. Suggested JSON structure (excerpt)

```json
{
  "id": "raiju",
  "name": "Raijū",
  "nameJa": "雷獣・隻眼",
  "description": "The Beast That Survived Heaven.",
  "level": 9,
  "baseGold": 80,
  "roles": ["boss"],
  "mapIds": [1, 2],
  "maxColumn": 10,
  "sprites": {
    "default": "enemy_raiju_phase1_default",
    "attack": "enemy_raiju_phase1_attack",
    "defend": "enemy_raiju_phase1_defend",
    "buff": "enemy_raiju_phase1_buff",
    "death": "enemy_raiju_phase1_defeated"
  },
  "portrait": "enemy_raiju_portrait",
  "icon": "enemy_raiju_icon",
  "stats": {
    "hp": { "min": 520, "max": 560 },
    "stamina": { "min": 18, "max": 22 },
    "strength": { "min": 10, "max": 12 },
    "skill": { "min": 16, "max": 18 },
    "mana": { "min": 18, "max": 20 },
    "luck": { "min": 14, "max": 14 },
    "defense": { "min": 14, "max": 14 },
    "armor": { "min": 6, "max": 6 }
  },
  "abilities": [
    { "id": "thunder_bite", "name": "Thunder Bite", "type": "attack", "element": "void", ... },
    { "id": "broken_pounce", "name": "Broken Pounce", "type": "attack", "element": "void", "combo": { "consumesState": { "target": "enemy", "state": "momentum", "damageMultiplier": 1.5 } }, ... },
    { "id": "lightning_howl", "name": "Lightning Howl", "type": "buff", ... },
    { "id": "watchful_eye", "name": "Watchful Eye", "type": "buff", ... },
    { "id": "thunder_dash", "name": "Thunder Dash", "type": "attack", "element": "storm", "isLightning": true, ... },
    { "id": "chain_lightning", "name": "Chain Lightning", "type": "attack", "element": "void", "isLightning": true, ... },
    { "id": "rolling_storm", "name": "Rolling Storm", "type": "recover", ... },
    { "id": "divine_judgment", "name": "Divine Judgment", "type": "attack", "element": "storm", "isLightning": true, ... },
    { "id": "heaven_splitter", "name": "Heaven Splitter", "type": "attack", "element": "physical", "consumesEffect": { "effectId": "electrified", "damageMultiplier": 2.0 }, ... },
    { "id": "eye_of_heaven", "name": "Eye of Heaven", "type": "buff", ... },
    { "id": "lightning_arc", "name": "Lightning Arc", "type": "attack", "element": "storm", "isLightning": true, ... }
  ],
  "phases": [
    { "hpThreshold": 1.00, "name": "The Lame Hunter", "abilityFilter": { "only": ["thunder_bite", "broken_pounce", "lightning_howl", "watchful_eye"] } },
    { "hpThreshold": 0.65, "name": "The Empty Eye Opens", "announce": "The empty eye bursts open with divine lightning.", "sprites": { "default": "enemy_raiju_phase2_default", "attack": "enemy_raiju_phase2_attack", "defend": "enemy_raiju_phase2_defend", "buff": "enemy_raiju_phase2_buff" } },
    { "hpThreshold": 0.30, "name": "The Living Storm", "announce": "The missing leg explodes into divine lightning. The Raijū floats.", "sprites": { "default": "enemy_raiju_phase3_default", ... } },
    { "hpThreshold": 0.10, "name": "Unstable Ascension", "announce": "The Raijū's lightning spirals out of control!", "sprites": { "default": "enemy_raiju_phase4_default", ... }, "modifiers": { "freeActionChance": 0.40, "freeActionId": "lightning_arc" } }
  ],
  "firstDefeatRewards": [
    { "type": "charm", "id": "some_storm_charm" }
  ],
  "drops": {
    "warrior": [
      { "type": "item", "id": "health_potion", "chance": 0.50 },
      { "type": "item", "id": "stone", "chance": 0.35 }
    ],
    "mage": [],
    "archer": []
  }
}
```

---

## 9. Implementation checklist

- [ ] Add `electrified` status effect to `EffectRegistry.js`.
- [ ] Add `eye_of_heaven` status effect to `EffectRegistry.js`.
- [ ] Add `static_charge` combo state to `combatStates.json`.
- [ ] Modify `Player.getParryChance()` for the -15% Electrified penalty.
- [ ] Modify `TurnManager` Dash branch to suppress `rushing` while Electrified.
- [ ] Add `consumesEffect` handling in enemy damage resolution.
- [ ] Add `perfectAccuracy` / `critChanceBonus` handling for `eye_of_heaven`.
- [ ] Add Static Charge counter logic during the enemy turn (phase 2+).
- [ ] Add Phase 4 free Lightning Arc logic.
- [ ] Create `assets/js/game/data/enemies/raiju.json` with placeholder sprites.
- [ ] Register Raijū in `assets/js/game/data/enemies/index.js`.
- [ ] Replace boss pool entries in map JSONs with `raiju`.
- [ ] Provide final sprite PNGs and update the sprite keys.
- [ ] Bump game version and rebuild.

---

## 10. Why this works with existing systems

- **Electrified** is just a debuff that three existing subsystems read (`staminaMultiplier`, parry chance, Dash combo state).
- **Storm element** already exists as a Water + Wind combo element with base effects (weak + frost).
- **Static Charge** reuses the combo-state system for temporary damage buffs.
- **Heaven Splitter** extends the enemy ability schema with `consumesEffect`, similar to how player skills consume combo states.
- **Phases** reuse the existing enemy phase machinery: sprite overrides, announcements, ability filters, and modifiers.
- **Counterplay** is built from the warrior abilities the player already has; no new hero mechanics are required.
