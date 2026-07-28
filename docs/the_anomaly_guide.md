# The Anomaly — Warrior Hero Reference

> **Class:** Warrior  
> **Role:** Balanced sword-and-shield fighter  
> **Japanese name:** 異常存在

This document consolidates the playable warrior hero, starting equipment, all charm types, the rarity/reward system, kanji challenge mechanics, every warrior ability, and the status/infusion interactions that tie them together.

---

## 1. Base Stats & Derived Values

### 1.1 Starting Attributes

| Stat | Base | Governs |
|------|------|---------|
| Vitality (VIT) | 20 | Max HP |
| Stamina (STA) | 10 | Max stamina pool |
| Capacity (CAP) | 5 | Ability slots and pools |
| Skill (SKL) | 10 | Crit chance, parry, some damage scaling |
| Strength (STR) | 15 | Physical damage and physical defence |
| Mana (MAN) | 5 | Elemental damage/defence and infusion success |
| Luck (LCK) | 5 | Parry, lifesteal thresholds, infusion chance |

### 1.2 Derived Stats

- **Max HP** = `floor((80 + VIT × 5) × (1 + maxHpMultiplier from charms))`
- **Max Stamina** = `8 + floor(STA / 3)`
- **Base Crit Chance** = `min(0.50, min(0.25, SKL × 0.05) + charm critChance)`
- **Readiness bonus to defence** = `floor(readiness × 7)`
- **Readiness bonus to parry** = `readiness × 0.20`

`readiness` is a 0–1 value built by the **Focus** ability and the end-of-turn word challenge. Higher readiness makes the next turn safer and more accurate.

---

## 2. Starting Equipment

### 2.1 Long Sword (Starting Weapon)

- **Base damage:** `20 + level × 2`
- **Max level:** 10
- **Upgrade costs:** 50 / 100 / 200 / 500 gold per bracket
- **Base scaling schedule:**
  - Strength: C (0) → B (3) → A (9)
  - Skill: D (0) → C (5)

The Long Sword is required by most weapon abilities. Socketing a **slot-1 socket charm** changes its scaling and unlocks family-locked abilities.

### 2.2 Wooden Shield (Starting Shield)

- **Base defence:** `5 + level × 1`
- **Max level:** 10
- **Base scaling schedule:**
  - Strength: D (0) → C (5) → B (9)

The Wooden Shield is required by shield abilities. Like the weapon, its scaling is overridden by socket charms.

### 2.3 Scaling Grade Multipliers

| Grade | Multiplier |
|-------|------------|
| S | 1.10 |
| A | 0.90 |
| B | 0.70 |
| C | 0.50 |
| D | 0.30 |
| E | 0.15 |

### 2.4 Stat Factor Soft Cap

Stats give diminishing returns through the `getStatFactor` curve:

- 0–25 → factor grows from 0.0 to 0.5
- 26–50 → factor grows from 0.5 to 0.85
- 51–99 → factor grows from 0.85 to 1.0

This factor is multiplied by the grade multiplier and equipment base when computing bonus damage/defence.

---

## 3. Charms

Charms are floating kanji that grant passive bonuses. There are three independent systems: **hero charms**, **static equipment charms**, and **socket charms**.

### 3.1 Hero Charms

Hero charms are equipped into 4 base hero slots. Effects of the same type stack additively.

| ID | Name | Kanji | Rarity | Effect |
|----|------|-------|--------|--------|
| `chikara_charm` | Charm of Power | 力 | Common | +2 STR |
| `tate_charm` | Charm of the Shield | 盾 | Common | +3 DEF |
| `hayai_charm` | Charm of Swiftness | 速 | Uncommon | +2 SKL |
| `un_charm` | Charm of Fortune | 運 | Rare | +3 LCK |
| `tanuki_fur_charm` | Tanuki Fur Charm | 狸 | Rare | +10% max HP |
| `hi_charm` | Charm of Fire | 火 | Uncommon | +8% damage |
| `mizu_charm` | Charm of Water | 水 | Uncommon | +1 STA regen |

### 3.2 Static Equipment Charms

These older charms occupy weapon/shield charm slots. Slot count grows with equipment level: 0 slots at level 0, 1 at +1, 2 at +3, 3 at +6, 4 at +9.

| ID | Name | Type | Rarity | Effect |
|----|------|------|--------|--------|
| `ken_no_mai_charm` | Sword-Dance Charm | Weapon | Rare | +5% crit |
| `yaiba_charm` | Blade Charm | Weapon | Uncommon | +10% damage |
| `kiba_charm` | Fang Charm | Weapon | Common | +1 STR |
| `kouri_charm` | Ice Charm | Shield | Uncommon | +4 DEF |
| `tetsu_charm` | Iron Charm | Shield | Common | +2 DEF |
| `kaze_charm` | Wind Charm | Shield | Rare | +2 SKL |

### 3.3 Socket Charms

Socket charms are inserted directly into the weapon/shield `socketCharmIds` array (4 sockets per item). They have two primary roles:

1. **Slot 1** determines the item’s **ability family**, **element**, and scaling overrides.
2. **Slot 2** provides combat passives.

#### 3.3.1 Weapon Socket Charms (Slot 1)

| ID | Family | Element | Scaling Focus |
|----|--------|---------|---------------|
| `sharp_charm_sword` | bleed | — | Skill-focused; STR locked to D |
| `heavy_charm_sword` | heavy | — | Strength-focused |
| `fire_charm_sword` | fire | fire | Mana-focused; STR/SKL locked to D |
| `water_charm_sword` | water | water | Mana-focused |
| `wind_charm_sword` | wind | wind | Mana-focused |
| `earth_charm_sword` | earth | earth | Mana-focused |
| `poison_charm_sword` | poison | poison | Mana-focused |
| `dark_charm_sword` | dark | void | Mana-focused |
| `light_charm_sword` | light | light | Mana-focused |
| `lucky_charm_sword` | luck | — | Luck-focused; removes STR/SKL scaling |

#### 3.3.2 Weapon Socket Charms (Slot 2)

| ID | Passive |
|----|---------|
| `life_dew_charm_sword` | 15% chance on hit to heal 2 HP |
| `venom_edge_charm_sword` | 12% chance on hit to inflict poison |
| `wind_spirit_charm_sword` | 50% chance at turn start to regen 1 STA |

#### 3.3.3 Shield Socket Charms (Slot 1)

| ID | Family | Scaling Focus |
|----|--------|---------------|
| `sturdy_charm_shield` | sturdy | Strength-focused defence |
| `elemental_charm_shield` | warding | Mana-focused defence; STR locked to E |
| `lucky_charm_shield` | luck_guard | Luck-focused defence; removes STR scaling |

#### 3.3.4 Shield Socket Charms (Slot 2)

| ID | Passive |
|----|---------|
| `thorn_shell_charm_shield` | 20% chance when hit to deal 3 thorns damage |
| `steady_guard_charm_shield` | +2 DEF while equipped |

---

## 4. Ability Rarity & Reward System

Every ability has a **rarity** that controls both its drop weight and its UI colour.

### 4.1 Rarity Colours

| Rarity | Colour | Hex (main) | Used for |
|--------|--------|------------|----------|
| Common | Purple | `#8e44ad` | Common abilities |
| Uncommon | Copper | `#b87333` | Uncommon abilities |
| Rare | Silver | `#bdc3c7` | Rare abilities |
| Epic | Gold | `#f1c40f` | Epic abilities |

> Note: Common abilities appear purple because that is the chosen common colour, not because they are weak.

### 4.2 Reward Rarity Weights

Post-battle rewards are drawn from the warrior reward pool (weapon / shield / class). Weights depend on the tile:

| Source | Common | Uncommon | Rare | Epic |
|--------|--------|----------|------|------|
| Column 0–2 | 70% | 15% | 10% | 5% |
| Column 3–4 | 60% | 20% | 15% | 5% |
| Column 5–6 | 50% | 25% | 20% | 5% |
| Column 7+ | 40% | 30% | 20% | 10% |
| Mini-boss | 20% | 30% | 30% | 20% |
| Boss | 0% | 30% | 30% | 40% |

Rewards guarantee at least one pick from each available category (weapon, shield, class) before filling the rest from the full pool.

### 4.3 Single-Use vs Multi-Use

- **Single-use abilities** can be rewarded repeatedly; each reward adds a **charge**. If no charges remain, the ability cannot be used in battle.
- **Multi-use abilities** are only offered as rewards until learned. Once known, they never appear again.

### 4.4 Capacity & Ability Slots

| Capacity | Active Battle Slots | Battle Pool Size | Max Learned Abilities |
|----------|---------------------|------------------|-----------------------|
| < 15 | 3 | 10 | 15 |
| 15–19 | 4 | 10 | 15 |
| 20–24 | 4 | 12 | 18 |
| 25–29 | 4 | 12 | 20 |
| 30–34 | 4 | 14 | 20 |
| 35–39 | 5 | 15 | 20 |
| 40–44 | 5 | 15 | 22 |
| 45–59 | 5 | 15 | 22 |
| 60+ | 6 | 20 | 30 |

`use_item` is always available and does not consume a combat active slot.


---

## 5. Kanji Challenge Mechanics

Most combat abilities require drawing a kanji. The challenge is resolved by the **WeaponKanjiChallengeSystem** (or custom logic for stances, Dash, Berserk, Sharpen Blade, and infusions).

### 5.1 Common Challenge Fields

| Field | Typical Value | Meaning |
|-------|---------------|---------|
| `skipChance` | 10% / 20% / 40% | Chance to skip the drawing challenge entirely |
| `focusOverrideChance` | 20% | Chance to draw the current focus kanji instead of the ability pool |
| `failThreshold` | `halfUp` | Fail if wrong strokes ≥ `ceil(totalStrokes / 2)` |
| `powerBonusTiers` | 0→+1, 4→+2, 8→+3 | Flat power bonus based on total strokes of the drawn kanji |

### 5.2 Outcome Branches

- **Skipped:** no drawing challenge, usually success but no power bonus.
- **Fallback:** no stroke data available, success but no power bonus.
- **Pass:** drawing completed under the fail threshold; applies power bonus and effect chance overrides.
- **Fail:** drawing failed or too many wrong strokes; ability still resolves as a **fail** result (reduced damage / no bonus).
- **Perfect (0 wrong strokes):** the next attack bypasses 80% of enemy defence.

### 5.3 Focus Override

If a focus kanji is set and the 20% focus override triggers, the player draws that kanji instead. This lets you deliberately train a kanji while still using combat abilities.

---

## 6. Warrior Abilities

### 6.1 Core Attacks

| Ability | STA | Rarity | Single | Scaling | Base | Effect | Notes |
|---------|-----|--------|--------|---------|------|--------|-------|
| **Forward Slash** 斬撃 | 3 | Common | No | STR × 1.0 | 6 | 10% bleed (capped 20%, 1 turn) | Bread-and-butter strike |
| **Heavy Slash** 重斬 | 4 | Common | Yes | STR × 1.2 | 15 | 30% power_up (1–2 turns), 15% blunt (capped 30%) | Slower but stronger |
| **Quick Stab** 突き | 2 | Uncommon | Yes | SKL × 0.9 | 5 | 15% bleed (1 turn) | Requires `sharp_charm_sword` in weapon slot 1 |
| **Guard Break** 破防 | 5 | Common | Yes | STR × 1.0 | 14 | 50% blunt | Requires `heavy_charm_sword` in weapon slot 1 |
| **Two-Hand Heavy** 両手重撃 | 5 | Uncommon | Yes | STR × 1.3 | 25 | 30% power_up, 20% blunt (capped 40%) | High base power |

### 6.2 Defence & Parry

| Ability | STA | Rarity | Single | Type | Mechanics |
|---------|-----|--------|--------|------|-----------|
| **Setup Defence** 防御 | 2 | Common | No | Defence | Grants block equal to `baseBlock 5 + shield scaling`; scales with the shield’s effective scaling schedule |
| **Shield Parry** 受け流し | 2 | Common | No | Parry | Sets up a parry charge. Parry chance = `15% + LCK/100 + readiness×0.20 + quizBonus ± quality`, capped 5%–60% |
| **Shield Bash** 盾打 | 2 | Common | Yes | Attack+Defence | Deals `2 + STR×0.5` damage, grants 3 base block, 10% blunt (20% on perfect, 5% on fail) |

### 6.3 Stances & Utility

| Ability | STA | Rarity | Single | Effect |
|---------|-----|--------|--------|--------|
| **Use Item** アイテム | 1 | Common | No | Opens the inventory item menu |
| **Focus** 集中 | 6 | Common | No | Adds readiness: skipped/fallback +0.5, pass +0.7, fail +0.3 |
| **Taunt** 挑発 | 5 | Uncommon | Yes | Battle-long stance: player damage ×1.5, enemy damage ×1.5; pass ×1.7/×1.4, fail ×1.3/×1.7 |
| **Zen** 禅 | 5 | Uncommon | Yes | Battle-long stance: player damage ÷1.5, enemy damage ÷1.5; pass ÷1.7, fail ÷1.3. Cancels Taunt |
| **Dash** 疾走 | 6 | Rare | Yes | Per-battle reflex: each non-Dash ability used adds miss chance to the enemy turn |

### 6.4 Buffs

| Ability | STA | Rarity | Single | Effect |
|---------|-----|--------|--------|--------|
| **Sharpen Blade** 鋭気 | 3 | Rare | Yes | Grants a `sword_damage_bonus` buff. Bonus damage scales with SKL, stroke count, and wrong strokes; final bonus is halved. Duration extended by LCK |
| **Berserk** 狂戦 | 8 | Epic | Yes | Grants stacking lifesteal. Starts at 10%; successful kanji adds `+2% × cleanStrokes`. Multiple uses stack up to 100% |

### 6.5 Family-Locked Attacks

These abilities require the matching **slot-1 weapon socket charm family**.

| Ability | STA | Rarity | Family | Scaling | Base | Element | Effect |
|---------|-----|--------|--------|---------|------|---------|--------|
| **Gutting Slash** 斬り裂き | 5 | Rare | bleed | SKL × 1.0 | 14 | physical | 35% bleed (capped 65%, 2–3 turns) |
| **Seismic Slam** 地碎打 | 5 | Rare | heavy | STR × 1.2 | 20 | physical | 25% blunt (capped 45%) |
| **Flame Arc** 炎弧 | 4 | Rare | fire | MAN × 1.1 | 12 | fire | 30% burn (capped 50%, 2–3 turns) |
| **Gale Strike** 風斬り | 4 | Rare | wind | SKL × 1.1 | 12 | wind | 25% weak (capped 45%, 2–3 turns) |

All four are **multi-use**; once learned they are never offered again.

### 6.6 Infusion Abilities

Infusions are single-use, 2-STA abilities that attach an element to the next compatible weapon/shield ability. Infusing an already-infused ability can boost, cancel, or transform it into a combo element.

| Ability | Element | Kanji Pool Tiers |
|---------|---------|------------------|
| **Infuse Fire** 火纏い | fire | 0: 火・炎 / 10: 焔・灯 / 20: 灼・焦・燃 |
| **Infuse Water** 水纏い | water | 0: 水・川 / 10: 海・河 / 20: 湖・泉・波 |
| **Infuse Wind** 風纏い | wind | 0: 風・空 / 10: 気・雲 / 20: 嵐・吹・暴 |
| **Infuse Earth** 土纏い | earth | 0: 土・地 / 10: 山・岩 / 20: 石・砂・崖 |
| **Infuse Void** 虚纏い | void | 0: 虚・無 / 10: 空・闇 / 20: 冥・暗・滅 |
| **Infuse Ice** 氷纏い | frost (water) | 0: 氷・冷 / 10: 雪・冬 / 20: 涼・霜・凍 |
| **Infuse Bleed** 血纏い | bleed | 0: 血・刀 / 10: 刃・傷 / 20: 剣・矢・槍 |
| **Infuse Poison** 毒纏い | poison | 0: 毒・虫 / 10: 薬・蛇 / 20: 菌・疫・藻 |

### 6.7 Detailed Special Mechanics

#### Forward Slash / Heavy Slash / Two-Hand Heavy
- Standard weapon attack loop.
- Damage = `floor((basePower + STR×scalingMultiplier + weaponBaseDamage) × multipliers)`.
- Perfect kanji (0 wrong strokes) reduces enemy defence to 20% for the hit.
- Power bonus tiers add +1/+2/+3 flat damage based on drawn kanji strokes.

#### Quick Stab
- Cheap, high-speed thrust.
- **Requirement:** first weapon socket charm must be `sharp_charm_sword`.
- Higher skip chance (30%) than most attacks.

#### Guard Break
- **Requirement:** first weapon socket charm must be `heavy_charm_sword`.
- Blunt chance is overridden by challenge outcome: 50% on skip/fallback, 70% on pass, 20% on fail.

#### Setup Defence
- Uses shield effective scaling schedule, not a raw stat multiplier.
- `block = floor((baseBlock + shieldBase × gradeMultiplier × statFactor) × multiplier)`.
- Infusing a defence skill also grants the matching elemental guard.

#### Shield Parry
- Setting up a parry consumes 2 STA and adds a charge with quality `perfect`, `sloppy`, or `fail`.
- When hit, consumes one charge and rolls parry chance.
- Parry chance modifiers:
  - Perfect charge: +15%
  - Fail charge: −10%
  - Luck: +LCK/100
  - Readiness: +readiness×0.20
  - Correct reaction challenge: +10%

#### Shield Bash
- Hybrid damage + block.
- Uses `setupDefenceBlock: true`, so the block portion follows Setup Defence scaling.
- Blunt chance scales with drawing quality.

#### Focus
- Readiness is capped at 1.0.
- High stamina cost; best used before a big defensive or critical turn.

#### Taunt
- Multiplies **all** player outgoing damage and **all** enemy incoming damage for the rest of the battle.
- Stacks multiplicatively if used repeatedly.
- Pass/fail shifts the risk/reward ratio.

#### Zen
- Divides both player and enemy damage.
- Cancels Taunt because it is the inverse stance.
- Pass makes the player even safer; fail weakens the effect.

#### Dash
- Battle-long reflex stance.
- On use: adds a per-ability miss bonus (5% skip/fallback, 7% pass, 3% fail).
- **During each player turn**, every non-Dash ability used adds that bonus to `turnMissChance`.
- `turnMissChance` resets to 0 at the start of each player turn, but the per-ability bonus persists for the whole battle.
- Using Dash multiple times increases the per-ability bonus.

#### Sharpen Blade
- Applies a `sword_damage_bonus` buff.
- Bonus formula in `TurnManager._calculateSwordBuffBonus`:
  - `quality = clamp(0–1, strokes/12 − wrongStrokes/maxMistakes)` where `maxMistakes = max(1, floor(strokes/2))`.
  - `baseBonus` scales with the user’s Skill value in a tiered fashion (first 40 at 1×, next 20 at 0.5×, etc.).
  - Final bonus = `floor(baseBonus × quality / 2)`.
- The buff only adds damage when the next skill uses `equipmentType: 'weapon'`.
- Buff duration is extended by Luck via a chance table (20% at 10 LCK up to 60% at 80+ LCK).

#### Berserk
- Applies a battle-long lifesteal buff.
- Default: 10% lifesteal on weapon attacks.
- If the kanji challenge is completed: `lifesteal = 10% + 2% × cleanStrokes`.
- If failed: 8% lifesteal.
- Multiple uses stack, capped at 100%.
- Lifesteal heals `floor(damageDealt × lifestealPercent / 100)`.

#### Gutting Slash / Seismic Slam / Flame Arc / Gale Strike
- Family-locked attacks from the reward pool.
- Each scales with the stat emphasised by its socket family (e.g. Flame Arc scales with Mana).
- Infusable with all base elements plus bleed/poison.
- Higher status chance and longer durations than starter attacks.


---

## 7. Infusion Reactions

When an already-infused ability receives a second infusion, the following reactions occur.

### 7.1 Same Element / Identical Mapping

- **Result:** `boost`
- Potency increases by +0.5.
- Message: “X intensifies!”

### 7.2 Void Interactions

- New infusion is **void** → replaces existing infusion with void.
- Existing infusion is **void** → void consumes the new essence and boosts potency.

### 7.3 Combo Reactions

| Combo | Ingredients | Result Element | Effects |
|-------|-------------|----------------|---------|
| Blaze | fire + wind | fire | burn + weak |
| Magma | fire + earth | fire | burn + blunt |
| Storm | wind + water | water | frost + weak |
| Nature | water + earth | water | frost + blunt |
| Dust | wind + earth | earth | weak + blunt |
| Plague | fire + poison | fire/poison | burn + poison |
| Venom | water + poison | water/poison | frost + poison |
| Spore | wind + poison | wind/poison | weak + poison |
| Rot | earth + poison | earth/poison | blunt + poison |
| Chaos | fire + void | void | burn + madness |
| Abyss | water + void | void | frost + madness |
| Silence | wind + void | void | weak + madness |
| Wither | earth + void | void | blunt + madness |
| Blight | poison + void | void | poison + madness |

Combo elements keep the dominant base element for guard/resistance checks and gain a damage multiplier of +10% to +25%.

### 7.4 Infusion Challenge & Failure

The infusion challenge uses the current focus kanji or a tiered pool kanji.

- Base failure chance = `max(0.1, 0.8 − MANA × 0.02)`
- Challenge bonus based on wrong-stroke ratio:
  - ≤ 1/3 wrong → −35% failure chance
  - ≤ 1/2 wrong → −20% failure chance
  - > 1/2 wrong → +10% failure chance
- If the infusion fizzles, STA is still spent and no element is applied.

### 7.5 Base Elemental Hit Effects

When an infused attack lands, the resolved element also applies its base effect:

| Element | Base Effect | Damage Modifier |
|---------|-------------|-----------------|
| fire | 40% burn | — |
| water | 50% frost | — |
| wind | 50% weak | — |
| earth | 40% blunt | — |
| void | 30% madness | +20% damage |
| poison | 50% poison | — |
| frost | 50% frost | — |

Combo elements apply their listed effects at reduced chances (usually 30–35%).

### 7.6 Elemental Guards

Shield infusions grant a guard buff:

| Guard | Blocks | Removed By | Extra |
|-------|--------|------------|-------|
| Fire Defence | earth | water | — |
| Water Defence | fire | wind | Cures burn |
| Wind Defence | water | earth | Cures weak |
| Earth Defence | wind | earth | — |
| Void Defence | — | — | Void chances halved; grants a random elemental guard |

---

## 8. Status Effects

| Effect | Category | Stack Rule | Key Mechanic |
|--------|----------|------------|--------------|
| **Burn** | Debuff | Replace | Tick damage = 75% of initial fire damage |
| **Poison** | Debuff | Replace | Tick damage = 50% of initial poison damage over 5–10 turns |
| **Bleed** | Debuff | Refresh | Next damage instance consumes Bleed and deals +10% of target max HP |
| **Blunt** | One-off | — | The triggering earth attack deals double damage |
| **Weak** | Debuff | Refresh | Outgoing damage × 0.75 |
| **Frost** | Debuff | Replace | Next turn stamina halved; incoming damage × 1.25 |
| **Madness** | Debuff | Refresh | On apply: 50% random bad effect, 50% stamina halved next turn |
| **Power Up** | Buff | Refresh | Outgoing damage × 1.25 for 1–3 turns |
| **Void Touched** | Debuff | Refresh | Incoming damage × 1.25 |
| **Stamina Crash** | Debuff | Refresh | Stamina halved next turn |
| **Slow** | Debuff | Refresh | Stamina reduced by 25% next turn |
| **Element Infuse** | Buff | Replace | Next attack is treated as the infused element |

Progressive chances (consecutive hits of the same element increase proc chance):

| Effect | Base | Step | Cap |
|--------|------|------|-----|
| burn | 10% | +5% | 35% |
| weak | 15% | +5% | 40% |
| frost | 2% | +2% | 10% |
| bleed | 5% | +5% | 25% |
| blunt | 5% | +5% | 25% |
| madness | 5% | +5% | 25% |

---

## 9. Combat Formulas

### 9.1 Weapon Damage

```
baseDamage  = ability.basePower
              + performer.getStatValue(scalingStat) × ability.scalingMultiplier
              + weaponBaseDamage
rawDamage   = floor(baseDamage × stanceMultiplier × powerUpMultiplier × weakMultiplier)
rawDamage   = floor(rawDamage × (1 + damageBonusCharms))
rawDamage   = floor(rawDamage × infusedDamageMultiplier)
if crit:    rawDamage = floor(rawDamage × 1.5)
rawDamage  += swordBuffBonus

effectiveDefence = target.getDefense()
if lastKanjiWrongStrokes === 0:
    effectiveDefence = floor(effectiveDefence × 0.2)

finalDamage = max(0, rawDamage − effectiveDefence)
finalDamage = floor(finalDamage × target.incomingDamageMultiplier)
actual = target.takeDamage(finalDamage)
```

### 9.2 Lifesteal

```
lifesteal = floor(actual × berserkLifestealPercent / 100)
if lifesteal > 0: performer.heal(lifesteal)
```

### 9.3 Block (Setup Defence / Shield Bash)

```
baseBlock   = ability.baseBlock
shieldScaling = shieldBaseDefence × Σ(gradeMultiplier × statFactor)
totalBlock  = floor((baseBlock + shieldScaling + shieldBonus) × multiplier)
performer.addBlock(totalBlock)
```

### 9.4 Shield Defence

```
shieldDefence = shieldBaseDefence
                + shieldBaseDefence × Σ(gradeMultiplier × statFactor)
                + activeShieldBonus
```

### 9.5 Total Defence

```
totalDefence = baseDefence + shieldDefence + floor(readiness × 7) + charmDefence
```

### 9.6 Parry Chance

```
chance = baseParryChance
       + luck / 100
       + readiness × 0.20
       + (lastReactionCorrect ? 0.10 : 0)
       + (quality === 'perfect' ? 0.15 : quality === 'fail' ? -0.10 : 0)
chance = clamp(0.05, 0.60, chance)
```

---

## 10. Quick Reference: Ability Unlock Conditions

| Ability | Unlock Condition |
|---------|------------------|
| Forward Slash | Starting ability |
| Setup Defence | Starting ability |
| Shield Parry | Starting ability |
| Use Item | Starting ability |
| Heavy Slash | Reward pool |
| Quick Stab | Reward pool + `sharp_charm_sword` equipped |
| Guard Break | Reward pool + `heavy_charm_sword` equipped |
| Focus | Reward pool |
| Taunt | Reward pool |
| Zen | Reward pool |
| Dash | Reward pool |
| Two-Hand Heavy | Reward pool |
| Sharpen Blade | Reward pool |
| Shield Bash | Reward pool |
| Berserk | Reward pool |
| Gutting Slash | Reward pool + weapon family = **bleed** |
| Seismic Slam | Reward pool + weapon family = **heavy** |
| Flame Arc | Reward pool + weapon family = **fire** |
| Gale Strike | Reward pool + weapon family = **wind** |
| Infuse X | Starting/reward abilities |

---

*Document generated from `assets/js/game/data/abilities/warrior.json`, `assets/js/game/data/charms.js`, `assets/js/game/data/socketCharms/`, `assets/js/game/data/abilityRewards.js`, `assets/js/game/systems/TurnManager.js`, `assets/js/game/systems/EffectRegistry.js`, and related battle scene code.*
