# The Hollow Ouroboros — Stats, Scaling & Charms Reference

> Complete reference of the current stat system, damage formulas, equipment
> scaling, and every charm in the game. Purpose: evaluate replacing raw
> stat-point allocation with a **skill-tree system** (players put points into
> visible skills; the existing stats continue to exist underneath and are
> derived from skill-tree choices).

---

## 1. The seven stats

Base values for a fresh hero (`Player.js`):

| Stat | Base | Drives |
|---|---|---|
| **vitality** | 20 | Max HP: `80 + vitality × 5` (× charm `maxHpMultiplier`) |
| **stamina** | 10 | Max stamina per turn: `8 + floor(stamina / 3)` |
| **capacity** | 5 | Number of equippable abilities (see slot table §6) |
| **skill** | 10 | Crit chance, Setup Defence amount, parry, several defenses |
| **strength** | 12 | Weapon scaling (primary), physical defense |
| **mana** | 5 | Elemental defense, infusion success |
| **luck** | 5 | Infusion proc, parry, miss, post-battle reward rolls |

### What each stat actually does (formulas)

| Stat | Effect | Formula |
|---|---|---|
| vitality | Max HP | `floor((80 + vit × 5) × (1 + charmMaxHpMultiplier))` |
| stamina | Max stamina / turn | `8 + floor(sta / 3)` (min pool; each ability costs 1–5) |
| capacity | Active ability slots | 3 / 4 / 5 / 6 at capacity 0 / 15 / 35 / 60 |
| capacity | Battle-pool slots | 10 / 12 / 14 / 15 / 20 at 0 / 20 / 30 / 40 / 60 |
| capacity | Overall known abilities | 15 / 18 / 20 / 22 / 30 at 0 / 20 / 25 / 45 / 60 |
| skill | Crit chance | `min(25%, skill × 5%) + charm critChance`, total cap 50% |
| skill | Setup Defence amount | scales block value (skill × 0.8 per ability def) |
| strength | Physical defense | `floor(strength × 0.5)` |
| mana | Elemental defense | `floor(mana × 0.5)` |
| mana | Infusion failure chance | `max(10%, 80% − mana × 2%)` |
| luck | Infusion proc chance | `min(30%, luck × 1%)` |
| luck | Parry chance | `+ luck / 100` |
| luck | Enemy miss vs you | `evasion + luck / 120` |
| luck | Post-battle bonus rolls | attribute points / gold / essence procs |

### Stat soft-cap factor (used by weapon scaling)

`getStatFactor(stat)` → 0.0–1.0, three linear segments:

```
0–25   : 0.5 × stat/25          (stat 5 → 0.10, 15 → 0.30, 25 → 0.50)
26–50  : 0.5 + 0.35 × (stat−25)/25   (35 → 0.64, 50 → 0.85)
51–99  : 0.85 + 0.15 × (stat−50)/49  (60 → 0.88, 99 → 1.00)
```

Diminishing returns by design — early points are worth much more than late
points (a classic Dark Souls-style soft cap).

---

## 2. Stat points — how a hero grows today

- **No points from leveling.** `BASE_STAT_POINTS = 0`,
  `STAT_POINTS_PER_LEVEL = 0`. The game reuses the site account level, which
  does not feed points.
- **Points come from winning battles**: `base = enemy.level + luckProc`,
  multiplied by the post-battle gamble challenge (fail ×(1−luck/200),
  success ×(1.5+luck/100)) and by NG+ (`1.5^ngLevel`). Typical range 4–18
  per fight.
- `permanentStatPointBonus` (meta upgrade) adds on top.
- Points are spent 1:1 on any of the 7 stats in the loadout screen. Each
  point immediately recalculates the derived value (HP, max stamina, etc.).
- Hero level = site level (from `user_stats`), currently only feeds the
  shop/word-difficulty systems and the essence-shop economy.

**Current design tension (motivation for skill trees):** players face a raw
7-stat spreadsheet with soft caps and derived formulas they cannot see.
There is no character "build" — every optimal player converges on similar
allocations, and the points-per-fight drip (4–18) makes individual point
decisions feel low-stakes.

---

## 3. Weapon damage — the full pipeline

Abilities are JSON-defined. Example — Forward Slash:
`{ basePower: 7, element: physical, staminaCost: 3, kanjiPool: [...] }`.
(`scalingStat`/`scalingMultiplier` on the ability JSON are used for ENEMIES
only; the player's damage comes from the weapon.)

```
weaponDamage = floor(
  ( base
    + Σ over weapon's effective scaling grades: base × GRADE_MULT × getStatFactor(stat)
    + activeKanjiBonus                                    (flat, from kanji challenges)
  )
  × (ability.basePower + activeBasePowerBonus) / 8        (power ratio; 7/8 = 0.875 for Forward Slash)
  × (1 + charmEffects.damageBonus)
)

final   = floor(weaponDamage × challengeMult × comboMult × infusionMult × stanceMult)
raw     = floor(final × 1.5)   on crit                    (crit ×1.5)
raw    += swordSharpenBonus                               (scales with skill)
damage  = raw − enemyDefense                              (perfect kanji: enemy def ×0.2)
```

Multiplier stack, in order:
1. **Challenge** (kanji/word quiz on the attack): perfect ×1.25 / success ×1.0 / fail ×0.5
2. **Combo states**: momentum ×1.8, revenge ×1.4, streak/sequence/tag combos ×1.25–1.5, etc.
3. **Elemental infusion**: ×(1 + mana/20 + potency−1 + combo), capped ×3
4. **Crit**: ×1.5 (chance from skill + charms)
5. **Enemy defense** subtracted at the end; 0-wrong-stroke kanji cuts enemy defense to 20%

### Worked example — fresh hero Forward Slash

Long Sword level 0: `base = 20`, scaling `{strength: C(0.50), skill: D(0.30)}`,
hero str 12 (factor 0.24), skill 10 (factor 0.20):

```
bonus = 20×0.50×0.24 + 20×0.30×0.20 = 2.4 + 1.2 = 3.6
dmg   = floor(23.6 × 0.875) = 20   (success) / 25 (perfect) / 10 (fail)
```

Reference table (success, before defense):

| Build | Forward Slash |
|---|---|
| Fresh hero (str 12, skill 10), sword L0 | 20 |
| str 20, sword L0 | 21 |
| str 35, sword L3 (B scaling, base 26) | 33 |
| str 35, sword L5 (skill C, base 30) | 39 |
| str 60, sword L9 (A scaling, base 38) | 61 |
| str 99, sword L10 (A, base 40) | 68 |

---

## 4. Equipment & upgrades

### Long Sword (only player weapon currently)

| Property | Value |
|---|---|
| baseDamage | `20 + 2 × level` (20 → 40, levels 0–10) |
| Base scaling schedule | `strength: C(L0) → B(L3) → A(L9)`; `skill: D(L0) → C(L5)` |
| Sockets | 4 socket-charm slots |
| Upgrade cost (gold) | 50 → 100 → 200 → 500 per level (tiers at L3/L6/L9) |
| Stat budget per level | +2 base damage, +1 scaling grade step at thresholds |

### Wooden Shield (only player shield)

| Property | Value |
|---|---|
| baseDefense | `5 + level` |
| Base scaling schedule | `strength: D(L0) → C(L5) → B(L9)` (feeds block/setup values) |
| kanjiPool | `['守','防','盾','硬','堅']` (Setup Defence challenge pool) |
| Same slot/cost schedule as sword | |

### Scaling grades

Grade multipliers: `S 1.10 · A 0.90 · B 0.70 · C 0.50 · D 0.30 · E 0.15`

A weapon's **effective scaling** = base schedule, then every socketed
slot-1 charm **overwrites** it per stat:
- `{ fixed: 'X' }` — force grade X at all levels
- `{ milestones: {1:'C',5:'B',...} }` — grade by equipment level
- `null` — remove that stat's scaling entirely

---

## 5. Charms — full catalogue

Three charm types: **hero** (4 slots, always available), **weapon socket**
(4 slots, unlocked by weapon level), **shield socket** (4 slots, by shield
level). Slot unlock schedule for equipment: `0 slots at L0 → 1 at L1 → 2 at
L3 → 3 at L6 → 4 at L9`.

Charm effects aggregate into one flat map (`getCharmEffects`):
`{ strength: +2, damageBonus: +0.10, critChance: +0.05, defense: +3,
maxHpMultiplier: +0.10, ... }` which then feeds:
- stat bonuses → `getStatValue(stat)` (used by all stat formulas)
- `damageBonus` → weapon damage ×(1+bonus)
- `critChance` → crit chance (cap 50%)
- `defense` → flat defense adder
- `maxHpMultiplier` → max HP multiplier

> ⚠️ Known dead effect: `staminaRegen` (Kitsune Tail +2, Charm of Water +1)
> is defined but never consumed anywhere.

### 5a. Hero charms (16) — 4 slots, equip freely

| Charm | Rarity | Effect | Unlock |
|---|---|---|---|
| Charm of Power 力 | common | strength +2 | default |
| Charm of the Shield 盾 | common | defense +3 | default |
| Charm of Swiftness 速 | uncommon | skill +2 | default |
| Charm of Fortune 運 | rare | luck +3 | default |
| Charm of Fire 火 | rare | damageBonus +8% | default |
| Charm of Water 水 | uncommon | **staminaRegen +1 (dead)** | default |
| Small Void Charm 空 | common | skill/str/mana/luck +1 | default |
| Earth Charm 地 | common | str/sta/vit +1 | default |
| Magi Charm 魔 | common | mana +2 | default |
| Charm of the Sword 剣 | uncommon | strength +5 | reach map column 5 |
| Wind Charm 風 | rare | skill/mana +2 | reach map column 7 |
| Ancient Void Charm 虚 | rare | skill/str/mana/luck +2 | reach boss |
| Tanuki Fur Charm 狸 | rare | maxHpMultiplier +10% | first tanuki-mini-boss defeat |
| Kitsune Tail Charm 尾 | rare | **staminaRegen +2 (dead)** | first kitsune defeat |
| Abyss Charm 渕 | epic | ALL seven stats +3 | defeat boss |
| Backpack Charm 袋 | epic | capacity +7 | defeat boss twice |

### 5b. Weapon socket charms — slot 1 (scaling rewrites + ability family)

Each rewrites the sword's scaling (see §4) and sets an **ability family**
that unlocks family-locked abilities for the warrior:

| Charm | Scaling rewrite | Family | Unlocks / notes |
|---|---|---|---|
| Sharp Charm 鋭 | str→fixed D; skill: C(L1)→B(L5)→A(L9) | bleed | Quick Stab (突き, requires this charm in socket 0); Gutting Slash added to reward pool |
| Heavy Charm 重 | str: B(L1)→A(L6)→S(L10) | heavy | Guard Break (requires this charm in socket 0); Seismic Slam reward pool |
| Fire Charm 火 | str→D, skill→D, mana: D→A | fire | Flame Arc reward pool; blade element fire |
| Water Charm 水 | same pattern, mana-scaled | water | — (element water) |
| Wind Charm 風 | same | wind | Gale Strike reward pool |
| Earth Charm 土 | same | earth | — |
| Poison Charm 毒 | same | poison | — |
| Dark Charm 闇 | same | dark | element void |
| Light Charm 光 | same | light | — |
| Lucky Charm 運 | **removes str & skill scaling**; luck: C(L1)→B(L5)→A(L9)→S(L10) | luck | full luck-scaling build |

**Family table** (`abilityFamilies.json`, warrior): bleed → gutting_slash;
heavy → seismic_slam; fire → flame_arc; wind → gale_strike.

### 5c. Weapon socket charms — slot 2 (passive procs)

| Charm | Proc |
|---|---|
| Life Dew Charm 活 | 15% on hit → heal 2 HP |
| Venom Edge Charm 毒 | 12% on hit → inflict poison |
| Wind Spirit Charm 風 | 50% on turn start → +1 stamina |

### 5d. Shield socket charms — slot 1 (scaling rewrites + family)

| Charm | Scaling rewrite | Family |
|---|---|---|
| Sturdy Charm 固 | str: C(L1)→B(L6)→A(L10) | sturdy |
| Warding Charm 防 | str→E; mana: D(L1)→C(L4)→B(L8)→A(L10) | warding |
| Lucky Shield Charm 運 | **removes str scaling**; luck: C→S | luck_guard |

### 5e. Shield socket charms — slot 2 (passives)

| Charm | Effect |
|---|---|
| Thorn Shell Charm 貝 | 20% on defend → reflect 3 damage |
| Steady Guard Charm 安 | flat defense +2 while equipped |

### 5f. Weapon/shield "stat" charms (older system, from `charms.js`)

A second, older charm set typed WEAPON/SHIELD (not socket JSON): Sword-Dance
(critChance +5%), Blade (damageBonus +10%), Fang (str +1), Ice (defense +4),
Iron (defense +2), Shield-Wind (skill +2). These occupy the same weapon/shield
charm slots as the socket charms and mix additively in `getCharmEffects`.

---

## 6. Combat resources & misc systems relevant to a redesign

- **Stamina**: refilled to max each turn (`resetForTurn`). Ability costs 1–5.
  Socket proc (Wind Spirit) can refund +1.
- **Readiness / focus**: 0–1 meter from end-turn word challenge; feeds parry.
- **Parry**: base 15% + luck/100 + readiness×20% + quiz bonus ± kanji quality,
  capped 5–60%. Parry charges built by drawing kanji on defensive abilities.
- **Infusion**: spend mana stat + kanji challenge to add an element to the next
  attack (damage mult up to ×3, status effects).
- **Kanji challenges**: every ability use draws a kanji; quality (perfect /
  sloppy / fail) multiplies the action (×1.25 / ×1.0 / ×0.5) and perfect
  kanji bypasses 80% of enemy defense. "Free kanji mode" replaces static
  ability pools with per-run rolled pools from selected JLPT levels.
- **Single-use abilities**: 1 charge when learned; consumed on use; button
  disappears until re-earned as a reward.
- **Enemies**: stats rolled from JSON ranges; NG+ multiplies HP/str/def/etc.
  by 1.5^level. **Stamina is deliberately NOT NG+-scaled** (AI action cap of
  5/turn would leave the extra pool unspent). Ability damage fields scale;
  stamina costs don't.

---

## 7. Redesign notes for the skill-tree proposal

Constraints & hooks that matter if points move into skill trees:

1. **Stats must remain the backing model** — every formula above reads
   `getStatValue(stat)`; a tree would just be a projection that sets
   `baseStats` (and `statAllocations` for the loadout UI).
2. **7 stats, 5-ish player-facing archetypes**: tank (vit/sta), berserker
   (str), assassin (skill/crit), mage (mana/infusion), gambler (luck). The
   tree can literally be these archetypes.
3. **Soft caps already create natural tier boundaries** — tree tiers could
   mirror the 25/50 breakpoints.
4. **Stat points per fight (4–18)** suit a tree with cheap early nodes.
5. **Charms already are "equipment mini-trees"** (scaling rewrites + family
   unlocks) — the skill tree should probably not duplicate what socket-1
   charms do (route scaling), or should integrate with it.
6. **Capacity is the build-defining stat** (ability slot counts) — a strong
   candidate for tree nodes ("+1 active slot").
7. Known dead effects to clean up in any redesign: `staminaRegen`.
8. UI today shows `Base X + Alloc Y = Z (+ Charm W)` per stat — a tree would
   replace this tab but the same derived-stat readouts are worth keeping.
