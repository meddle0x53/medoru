# Enemies

This document describes every enemy in the game, how their definitions work, how their AI selects abilities, how player challenges can weaken or cancel those abilities, and how their sprites and layout are handled.

## 1. How enemies work

### 1.1 Definitions and loading

Enemy definitions live as individual JSON files in `assets/js/game/data/enemies/`. They are imported and exported from `assets/js/game/data/enemies/index.js` as `ENEMY_DEFINITIONS`. `BootScene` iterates this list to preload every referenced sprite, portrait, and icon as a PNG from `priv/static/images/game/`.

A tile decides which enemy appears:
- If the map JSON supplies an `enemyPools` entry for the tile type (e.g. `mini_boss`), one of those IDs is chosen.
- Otherwise `pickEnemyForTile` filters by `roles` (`battle` / `mini_boss` / `boss`), `mapIds`, and `maxColumn`.

### 1.2 Roles

| Role | Meaning |
|---|---|
| `battle` | Normal random encounter enemy |
| `mini_boss` | Appears on mini-boss tiles; currently the only one is Danzaburō-danuki |
| `boss` | Appears on the final boss tile |
| `summon` | Spawned by another enemy (e.g. Tanuki Clone) |

### 1.3 Stats

Every enemy has min/max stats. When the enemy is spawned, each stat is rolled uniformly in that range. Stats are: `hp`, `stamina`, `strength`, `skill`, `mana`, `luck`, `defense`, `armor`.

### 1.4 Abilities

Each ability is a JSON object with the following common fields:

| Field | Meaning |
|---|---|
| `id` | Internal identifier |
| `name` | Display name |
| `type` | `attack`, `debuff`, `buff`, `heal`, `recover`, `summon`, `transform` |
| `element` | Element used for guard/resistance checks (`physical`, `fire`, `wind`, `earth`, `void`, combo elements, etc.) |
| `staminaCost` | STA spent to use it |
| `aiWeight` | Higher weight = more likely when the AI chooses among usable abilities |
| `maxUsesPerTurn` | Hard cap on how many times this ability can be used in one enemy turn |
| `basePower` / `scalingStat` / `scalingMultiplier` | Damage formula: `basePower + stat × scalingMultiplier` |
| `effects` | Array of status effects to apply on hit/resolve |
| `sprite` | Sprite key to show while the ability animates; falls back to the `attack` pose |
| `challenges` | Optional word challenge(s) the player can answer to weaken/cancel the ability |
| `minPhaseIndex` / `maxPhaseIndex` | Restrict ability to specific boss phase(s) |
| `isBasicAttack` | If true, phase modifiers like `basicAttackDamageMultiplier` apply |

### 1.5 Ability types in detail

| Type | Behaviour |
|---|---|
| `attack` | Deals damage. Applies `effects` after damage. Supports element-vs-defence resolution and ember recoil for fire. |
| `debuff` | Deals (usually small) damage and applies negative effects. |
| `buff` | Buffs self. `buffType: next_attack_bonus` adds flat damage to the next attack; `evasion` adds a miss chance buff; otherwise a generic buff is stored. |
| `heal` | Restores HP by percent or flat amount, cleanses listed effects, and can apply a `buffEffect`. |
| `recover` | Restores stamina by `staminaRecover`. |
| `summon` | Adds new enemies to the encounter with HP scaled by `summonHpMultiplier`. |
| `transform` | Replaces the enemy with another enemy definition, keeping the current HP ratio. Transformed enemy loses phases. |

### 1.6 AI action selection

During the enemy turn, each enemy keeps taking actions until one of these conditions is met:
- It has already taken 5 actions.
- It has 0 or less stamina.
- No ability is usable.

When choosing the next action:
1. Filter abilities to those that are affordable and have not hit `maxUsesPerTurn`.
2. Sort by priority: setup actions (`buff`/`debuff`/`summon`/`transform`) come first, then `attack`, then `heal`, then `recover`.)
3. Within the same priority, pick the highest `aiWeight`.
4. Only one setup action is allowed per turn. After a setup action is used, the next action must be a non-setup ability.
5. If the enemy just entered a new phase, it prefers an ability whose `minPhaseIndex` equals the new phase.

### 1.7 Phases

A boss can define `phases`, each with an `hpThreshold`. The active phase is the one with the highest threshold still above the current HP ratio. Phase transitions can:
- Change sprites (`phase.sprites`).
- Announce text (`phase.announce`).
- Apply global modifiers (`phase.modifiers`), e.g. `basicAttackDamageMultiplier`, `summonChanceBonus`.
- Filter or override abilities (`phase.abilityFilter`, `phase.abilityOverrides`).

### 1.8 Player challenges against enemy abilities

An ability can list one or more `challenges`. Each challenge has a `chance` to trigger before the ability resolves. If it triggers, the player is given a timed word/meaning challenge built from their known word list. The outcome modifies the ability:

| Outcome | Effect |
|---|---|
| `cancel` / `neutralize` | The ability is cancelled entirely. |
| `weaken` | Damage is multiplied by `weakenMultiplier` (default 0.5). |
| `halveChance` | All effect chances are halved. |
| `boostChance` | All effect chances are multiplied by 2.1. |
| `setChance` | Sets a specific effect’s chance to a fixed value. |
| `setValue` | Sets an arbitrary ability value such as `damageMultiplier` or `evasion`. |

### 1.9 Sprites and layout

Each enemy defines a `sprites` block:

| Key | Used for | Fallback |
|---|---|---|
| `default` | Idle stance | — |
| `attack` | Attack animation | `default` |
| `defend` | Taking damage/blocking | `default` |
| `buff` | Buff/heal/summon animation | `default` |
| `death` | Defeated pose | `default` |

Optional `portrait` and `icon` keys are loaded if present. Phase sprites override the base sprites for that phase.

Sprites are loaded from `priv/static/images/game/<key>.png`. All current enemy source sprites are **1024×1536** PNGs. The game canvas is logically **960×540**, so the `layout` block scales them down (typical scale 0.10–0.30). The layout also provides x/y positions for 1, 2, or 3 living enemies so the scene can place them correctly.

### 1.10 Drops

Each enemy has a per-class drop table (`warrior`, `mage`, `archer`). Each entry has an item/charm/socketCharm ID and a `chance`. After the enemy dies, the table is rolled once per entry.

## 2. Enemy roster

### Summary

| Enemy | Role | Map IDs | Level | HP | STA | STR | SKL | MAN | LCK | DEF | ARM |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Bake-neko** 化け猫 | battle | 1 | 1 | 75–90 | 10–12 | 1–2 | 4–5 | 5 | 9 | 3–4 | 2–3 |
| **Danzaburō-danuki** 団三郎狸 | mini_boss | 1, 2 | 1 | 240–260 | 12–14 | 4–5 | 5–6 | 6–7 | 8–10 | 6–10 | 3–4 |
| **Hitotsume-kozō** 一つ目小僧 | battle | 1 | 1 | 55–70 | 8–10 | 2–3 | 2–3 | 3–5 | 1–2 | 2–4 | 1–2 |
| **Kasa-obake** 傘おばけ | battle | 1, 2 | 1 | 70–80 | 6–8 | 3–4 | 1–2 | 0 | 1–2 | 3–5 | 1–2 |
| **Elite Kasa-obake** 傘おばけ頭目 | battle | 1, 2 | 3 | 140 | 10 | 7 | 4 | 0 | 2 | 8 | 3 |
| **Umbrella Tyrant** 傘の暴君 | boss | 1, 2 | 5 | 220 | 12 | 11 | 6 | 0 | 3 | 12 | 4 |
| **Tanuki Clone** 狸の幻影 | summon | 1 | 1 | 60–75 | 6–8 | 2–3 | 2–3 | 2–3 | 1–2 | 2–3 | 0–1 |

### Bake-neko `bake_neko`

A supernatural cat with keen reflexes and ghostly flames.

- **Role:** battle
- **Maps:** 1
- **Max column:** 8
- **Level:** 1 | **Base gold:** 7
- **Stats:** HP 75–90, STA 10–12, STR 1–2, SKL 4–5, MAN 5, LCK 9, DEF 3–4, ARM 2–3

**Sprites**

| Pose | Key | Size |
|---|---|---|
| default | `enemy_bake_neko_default` | 1024×1536 |
| attack | `enemy_bake_neko_attack` | 1024×1536 |
| defend | `enemy_bake_neko_defend` | 1024×1536 |
| buff | `enemy_bake_neko_buff` | 1024×1536 |
| death | `enemy_bake_neko_defeated` | 1024×1536 |
| portrait | `enemy_bake_neko_portrait` | 512×512 |
| icon | `enemy_bake_neko_icon` | 128×128 |

**Layout positions (x, y, scale)**

- `1` enemy: (690, 470, 0.16)
- `2` enemy: (600, 460, 0.14) / (780, 460, 0.14)
- `3` enemy: (540, 455, 0.12) / (690, 455, 0.12) / (840, 455, 0.12)

**Abilities**

| Ability | Type | STA | Element | Power | Scaling | Effects | Challenge |
|---|---|---|---|---|---|---|---|
| Feline Agility | buff | 1 | — | — | — | — | 50% word (known, N5/N4, freq≤2000) onSuccess=neutralize onFail={'type': 'setValue', 'key': 'evasion', 'value': 0.3} |
| Razor Claws | attack | 3 | physical | 10 | strength × 1.0 | bleed 30% 1-1t | 50% word (known, N5/N4, freq≤2000) onSuccess={'type': 'setChance', 'effectId': 'bleed', 'value': 0.2} onFail={'type': 'setChance', 'effectId': 'bleed', 'value': 0.35} |
| Shadow Pounce | attack | 4 | void | 12 | skill × 0.8 | — | 50% word (known, N5/N4, freq≤2000) onSuccess={'type': 'setValue', 'key': 'damageMultiplier', 'value': 1.1} onFail={'type': 'setValue', 'key': 'damageMultiplier', 'value': 1.3} |
| Ghost Flame | attack | 2 | fire | 4 | mana × 0.5 | burn 20% 3-5t | 50% word (known, N5/N4, freq≤2000) onSuccess={'type': 'setChance', 'effectId': 'burn', 'value': 0.1} onFail={'type': 'setChance', 'effectId': 'burn', 'value': 0.25} |

**Drops (warrior)**

- `health_potion` (item) — 10%
- `kaze_charm` (charm) — 2%

---

### Danzaburō-danuki `danzaburo_danuki`

A towering tanuki trickster who conjures sake, mirages, and borrowed forms.

- **Role:** mini_boss
- **Maps:** 1, 2
- **Max column:** 10
- **Level:** 1 | **Base gold:** 25
- **Stats:** HP 240–260, STA 12–14, STR 4–5, SKL 5–6, MAN 6–7, LCK 8–10, DEF 6–10, ARM 3–4

**Sprites**

| Pose | Key | Size |
|---|---|---|
| default | `enemy_danzaburo_default` | 1024×1536 |
| attack | `enemy_danzaburo_attack` | 1024×1536 |
| defend | `enemy_danzaburo_defend` | 1024×1536 |
| buff | `enemy_danzaburo_buff` | 1024×1536 |
| death | `enemy_danzaburo_defeated` | 1024×1536 |
| portrait | `enemy_danzaburo_default` | 1024×1536 |
| icon | `enemy_bake_neko_icon` | 128×128 |

**Layout positions (x, y, scale)**

- `1` enemy: (690, 475, 0.18)
- `2` enemy: (690, 475, 0.18) / (810, 475, 0.18)
- `3` enemy: (690, 475, 0.18) / (570, 475, 0.18) / (810, 475, 0.18)

**Abilities**

| Ability | Type | STA | Element | Power | Scaling | Effects | Challenge |
|---|---|---|---|---|---|---|---|
| Tanuki Staff | attack | 2 | physical | 9 | strength × 0.9 | — | 35% word (known, N5/N4, freq≤1000) onSuccess=weaken onFail=full |
| Falling Leaves | attack | 3 | wind | 6 | skill × 0.7 | blind 35% 2-3t | 50% word (known, N5/N4, freq≤2000) onSuccess=neutralize onFail={'type': 'setChance', 'effectId': 'blind', 'value': 0.5} |
| Stone Belly | attack | 3 | earth | 7 | strength × 0.8 | slow 45% 1-1t, blunt 20% 1-1t | 40% word (known, N5/N4, freq≤2000) onSuccess=halveChance onFail=boostChance |
| Forest Mirage | summon | 4 | — | — | — | — | 45% kanji (known, N5/N4) onSuccess=cancel onFail=full |
| Sake of a Hundred Years | heal | 5 | — | — | — | — | 35% word (known, N5/N4/N3, freq≤2000) onSuccess=weaken onFail=full |
| Tanuki Transformation | transform | 5 | — | — | — | — | 40% word (known, N5/N4, freq≤2000) onSuccess=cancel onFail=full |

**Phases**

- **Phase 0:** `Calm Deceiver` at HP ≤ 100%
  - Ability filter: `{'exclude': ['falling_leaves']}`
- **Phase 1:** `Drunken Fury` at HP ≤ 40%
  - Announce: "Danzaburō enters Drunken Fury! Its staff blurs and the forest shivers!"
  - Sprites: {'default': 'enemy_danzaburo_phase2_default'}
  - Modifiers: `{'basicAttackDamageMultiplier': 2.0, 'summonChanceBonus': 0.25}`

**Drops (warrior)**

- `health_potion` (item) — 25%
- `stone` (item) — 35%
- `kaze_charm` (charm) — 5%
- `tetsu_charm` (charm) — 5%
- `kouri_charm` (charm) — 3%

---

### Hitotsume-kozō `hitotsume_kozo`

A one-eyed monk spirit that curses with its gaze.

- **Role:** battle
- **Maps:** 1
- **Max column:** 10
- **Level:** 1 | **Base gold:** 5
- **Stats:** HP 55–70, STA 8–10, STR 2–3, SKL 2–3, MAN 3–5, LCK 1–2, DEF 2–4, ARM 1–2

**Sprites**

| Pose | Key | Size |
|---|---|---|
| default | `enemy_hitotsume_kozo` | 1024×1536 |
| attack | `enemy_hitotsume_kozo_attack` | 1024×1536 |
| defend | `enemy_hitotsume_kozo_defend` | 1024×1536 |
| buff | `enemy_hitotsume_kozo_buff` | 1024×1536 |
| death | `enemy_hitotsume_kozo_defeated` | 1024×1536 |
| portrait | `enemy_hitotsume_kozo_portrait` | 1024×1024 |
| icon | `enemy_hitotsume_kozo_icon` | 128×128 |

**Layout positions (x, y, scale)**

- `1` enemy: (690, 475, 0.2)
- `2` enemy: (600, 465, 0.16) / (780, 465, 0.16)
- `3` enemy: (540, 460, 0.12) / (690, 460, 0.12) / (840, 460, 0.12)

**Abilities**

| Ability | Type | STA | Element | Power | Scaling | Effects | Challenge |
|---|---|---|---|---|---|---|---|
| Eye Bonk | attack | 2 | physical | 5 | strength × 0.8 | — | — |
| Frightening Gaze | debuff | 4 | — | 0 | mana × 0 | weak 50% 2-2t, slow 20% 1-1t | 50% word (known, N5/N4/N3, freq≤2000) onSuccess=halveChance onFail=boostChance |
| Evil Eye | debuff | 4 | void | 4 | mana × 0.5 | void_touched 20% 2-3t, weak 10% 2-2t | 50% word (known, N5/N4/N3, freq≤2000) onSuccess=halveChance onFail=boostChance |

**Drops (warrior)**

- `health_potion` (item) — 10%
- `stone` (item) — 20%
- `kouri_charm` (charm) — 2%

---

### Kasa-obake `kasa_obake`

A possessed umbrella spirit.

- **Role:** battle
- **Maps:** 1, 2
- **Max column:** 10
- **Level:** 1 | **Base gold:** 5
- **Stats:** HP 70–80, STA 6–8, STR 3–4, SKL 1–2, MAN 0, LCK 1–2, DEF 3–5, ARM 1–2

**Sprites**

| Pose | Key | Size |
|---|---|---|
| default | `enemy_kasa_obake` | 1024×1536 |
| attack | `enemy_kasa_obake_attack` | 1024×1536 |
| defend | `enemy_kasa_obake_defend` | 1024×1536 |
| buff | `enemy_kasa_obake_buff` | 1024×1536 |
| death | `enemy_kasa_obake_defeated` | 1024×1536 |

**Layout positions (x, y, scale)**

- `1` enemy: (690, 570, 0.3)
- `2` enemy: (600, 548, 0.22) / (780, 548, 0.22)
- `3` enemy: (540, 501, 0.16) / (690, 501, 0.16) / (840, 501, 0.16)

**Abilities**

| Ability | Type | STA | Element | Power | Scaling | Effects | Challenge |
|---|---|---|---|---|---|---|---|
| Claw Strike | attack | 3 | physical | 10 | strength × 1.0 | — | 25% word (known, N5/N4/N3, freq≤2000) onSuccess=weaken onFail=full |
| Intimidate | buff | 2 | — | — | — | — | 35% kanji (known, N5) onSuccess=cancel onFail=full |
| Ember Breath | attack | 4 | fire | 6 | strength × 0.8 | burn 25% 3-5t, weak 100% 2-2t | — |
| Gale Claw | attack | 3 | wind | 7 | strength × 0.9 | bleed 15% 1-1t | — |
| Stone Smash | attack | 5 | earth | 9 | strength × 1.1 | blunt 20% | — |

**Drops (warrior)**

- `health_potion` (item) — 10%
- `stone` (item) — 20%
- `tetsu_charm` (charm) — 2%
- `kouri_charm` (charm) — 0%

---

### Elite Kasa-obake `kasa_obake_elite`

A stronger umbrella spirit.

- **Role:** battle
- **Maps:** 1, 2
- **Max column:** 10
- **Level:** 3 | **Base gold:** 15
- **Stats:** HP 140, STA 10, STR 7, SKL 4, MAN 0, LCK 2, DEF 8, ARM 3

**Sprites**

| Pose | Key | Size |
|---|---|---|
| default | `enemy_kasa_obake` | 1024×1536 |
| attack | `enemy_kasa_obake_attack` | 1024×1536 |
| defend | `enemy_kasa_obake_defend` | 1024×1536 |
| buff | `enemy_kasa_obake_buff` | 1024×1536 |
| death | `enemy_kasa_obake_defeated` | 1024×1536 |

**Layout positions (x, y, scale)**

- `1` enemy: (690, 570, 0.3)
- `2` enemy: (600, 548, 0.22) / (780, 548, 0.22)
- `3` enemy: (540, 531, 0.16) / (690, 531, 0.16) / (840, 531, 0.16)

**Abilities**

| Ability | Type | STA | Element | Power | Scaling | Effects | Challenge |
|---|---|---|---|---|---|---|---|
| Claw Strike | attack | 3 | physical | 10 | strength × 1.0 | — | 25% word (known, N5/N4, freq≤1000) onSuccess=weaken onFail=full |
| Intimidate | buff | 2 | — | — | — | — | 35% kanji (known, N5) onSuccess=cancel onFail=full |
| Blaze Swipe | attack | 5 | blaze | 12 | strength × 1.1 | — | — |
| Dust Strike | attack | 4 | dust | 10 | strength × 1.0 | — | — |

**Drops (warrior)**

- `health_potion` (item) — 25%
- `stone` (item) — 35%
- `tetsu_charm` (charm) — 5%
- `kouri_charm` (charm) — 2%

---

### Umbrella Tyrant `kasa_obake_tyrant`

The lord of all umbrella spirits.

- **Role:** boss
- **Maps:** 1, 2
- **Max column:** 10
- **Level:** 5 | **Base gold:** 40
- **Stats:** HP 220, STA 12, STR 11, SKL 6, MAN 0, LCK 3, DEF 12, ARM 4

**Sprites**

| Pose | Key | Size |
|---|---|---|
| default | `enemy_kasa_obake` | 1024×1536 |
| attack | `enemy_kasa_obake_attack` | 1024×1536 |
| defend | `enemy_kasa_obake_defend` | 1024×1536 |
| buff | `enemy_kasa_obake_buff` | 1024×1536 |
| death | `enemy_kasa_obake_defeated` | 1024×1536 |

**Layout positions (x, y, scale)**

- `1` enemy: (690, 570, 0.3)
- `2` enemy: (600, 548, 0.22) / (780, 548, 0.22)
- `3` enemy: (540, 531, 0.16) / (690, 531, 0.16) / (840, 531, 0.16)

**Abilities**

| Ability | Type | STA | Element | Power | Scaling | Effects | Challenge |
|---|---|---|---|---|---|---|---|
| Claw Strike | attack | 3 | physical | 10 | strength × 1.0 | — | 25% word (known, N5/N4, freq≤1000) onSuccess=weaken onFail=full |
| Intimidate | buff | 2 | — | — | — | — | 35% kanji (known, N5) onSuccess=cancel onFail=full |
| Magma Slam | attack | 6 | magma | 16 | strength × 1.2 | — | — |
| Chaos Breath | attack | 5 | chaos | 14 | strength × 1.0 | — | — |

**Drops (warrior)**

- `health_potion` (item) — 50%
- `stone` (item) — 50%
- `tetsu_charm` (charm) — 12%
- `kouri_charm` (charm) — 6%

---

### Tanuki Clone `tanuki_clone`

A flickering copy spawned by Danzaburō's forest magic.

- **Role:** summon
- **Maps:** 1
- **Max column:** 10
- **Level:** 1 | **Base gold:** 3
- **Stats:** HP 60–75, STA 6–8, STR 2–3, SKL 2–3, MAN 2–3, LCK 1–2, DEF 2–3, ARM 0–1

**Sprites**

| Pose | Key | Size |
|---|---|---|
| default | `enemy_danzaburo_default` | 1024×1536 |
| attack | `enemy_danzaburo_attack` | 1024×1536 |
| defend | `enemy_danzaburo_defend` | 1024×1536 |
| buff | `enemy_danzaburo_buff` | 1024×1536 |
| death | `enemy_danzaburo_defeated` | 1024×1536 |

**Layout positions (x, y, scale)**

- `1` enemy: (780, 470, 0.12)
- `2` enemy: (600, 460, 0.12) / (780, 460, 0.12)
- `3` enemy: (540, 455, 0.1) / (690, 455, 0.1) / (840, 455, 0.1)

**Abilities**

| Ability | Type | STA | Element | Power | Scaling | Effects | Challenge |
|---|---|---|---|---|---|---|---|
| Clone Scratch | attack | 2 | physical | 4 | strength × 0.7 | — | — |

**Drops (warrior)**


---

## 3. Adding a new enemy

1. Create `assets/js/game/data/enemies/<id>.json`.
2. Import and add it to `ENEMY_DEFINITIONS` in `assets/js/game/data/enemies/index.js`.
3. Add PNG files to `priv/static/images/game/` for every sprite key, portrait, and icon referenced.
4. Add the enemy to the relevant map `enemyPools` (`battle`, `mini_boss`, `boss`) or rely on `roles`/`mapIds`/`maxColumn` fallback.
5. If it is a boss/mini-boss, consider adding `phases`, `firstDefeatRewards`, and a tile image.
6. Bump the game version and rebuild with `mix esbuild medoru`.
