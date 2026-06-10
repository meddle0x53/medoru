# Plan: Switch Action System

## Overview
Replace the do-nothing "Switch Action" button with a full action management dialog. Players can swap active/inactive combat actions based on their equipment and capacity stat.

## Demo Actions (5 total, 3 active)

| ID | Name | Type | Equipment | Stamina | Base Power | Kanji |
|---|---|---|---|---|---|---|
| forward_slash | Forward Slash | attack | Long Sword | 3 | 8 (×1.0 STR) | 力 |
| heavy_slash | Heavy Slash | attack | Long Sword | 4 | 16 (×1.2 STR) | 斬 |
| setup_defence | Setup Defence | defence | Wooden Shield | 2 | 5 block (×0.8 SKL) | 盾 |
| shield_parry | Shield Parry | parry | Wooden Shield | 2 | — | 受 |
| heal_potion | Heal Potion | heal | — | 1 | 15 HP | 薬 |

## Active Slot Formula
```javascript
function getMaxActiveActions(capacity) {
  return Math.min(5, Math.max(3, 2 + Math.floor(capacity / 10)))
}
// capacity  3 → 3 slots (current player)
// capacity 10 → 3 slots
// capacity 20 → 4 slots
// capacity 35 → 5 slots
```

## Parry System

### When It Triggers
During enemy turn, before each enemy attack, if **Shield Parry** is in the player's active actions.

### Parry Chance Formula
```javascript
function calculateParryChance(player) {
  const base = 0.15                           // 15% base
  const luckBonus = (player.luck || 0) / 100  // +1% per luck point
  const readinessBonus = (player.readiness || 0) * 0.10  // +10% if readiness = 1
  const quizBonus = player.lastReactionCorrect ? 0.10 : 0  // +10% if last reaction challenge was correct
  
  return Math.min(0.60, base + luckBonus + readinessBonus + quizBonus)
  // Example: luck 5, readiness 1, reaction correct → 15% + 5% + 10% + 10% = 40%
}
```

### Parry Resolution
1. Roll `Math.random() < parryChance`
2. **If parry succeeds:**
   - Show "PARRIED!" floating text + shield parry sprite
   - Enemy attack deals **0 damage**
   - Trigger **counter-attack** with equipped sword action
   - Counter-attack uses kanji drawing (same as Forward Slash)
   - Kanji result affects counter damage:
     - Perfect (0 wrong): full counter damage
     - Sloppy (1-2 wrong): 75% counter damage
     - Fail/timeout: 50% counter damage
   - After counter-attack, resume enemy turn
3. **If parry fails:** normal enemy attack proceeds

### Counter-Attack Damage
```javascript
function calculateCounterDamage(player, kanjiResult) {
  const swordDmg = player.calculateWeaponDamage()
  let multiplier = 0.5  // base counter is weaker
  if (kanjiResult?.completed) {
    if (kanjiResult.wrongStrokes === 0) multiplier = 1.0
    else if (kanjiResult.wrongStrokes <= 2) multiplier = 0.75
  }
  return Math.floor(swordDmg * multiplier)
}
```

## Data Model

### Action Definition
```javascript
{
  id: string,
  name: string,
  nameJa: string,
  type: 'attack' | 'defence' | 'parry' | 'heal' | 'buff',
  equipmentType: 'weapon' | 'shield' | 'item' | null,
  requiredEquipment: string | null,  // e.g. "Long Sword"
  staminaCost: number,
  
  // For attacks
  basePower?: number,
  scalingStat?: string,
  scalingMultiplier?: number,
  
  // For defence
  baseBlock?: number,
  
  // For parry
  baseParryChance?: number,
  
  // For heal
  healAmount?: number,
  
  // Kanji challenge
  kanji?: string,
  kanjiStrokeData?: object,
}
```

### Player State Changes
```javascript
// Equipment-bound actions (derived from equipped weapon/shield)
this.equippedWeaponActions = []   // actions for current weapon
this.equippedShieldActions = []   // actions for current shield
this.activeActions = []           // currently slotted (3-5)
this.inactiveActions = []         // owned but not slotted
this.parryAvailable = false       // true if Shield Parry is active
```

## UI: Switch Action Dialog

### Layout
- **Title:** "Switch Actions" 
- **Slots indicator:** "3 / 3 Active" 
- **Active section** (top): cards for each active action, green border, checkmark icon
- **Inactive section** (bottom): cards for available inactive actions, dimmed
- **Swap flow:**
  1. Click inactive action → it highlights with "Select to equip"
  2. Click active action → swap happens, confirmation shown
  3. Or: drag-and-drop style (optional, click-based is fine for MVP)
- **Confirm / Cancel buttons**

### Action Card Design
```
┌─────────────────────────┐
│ [⚔] Heavy Slash    4 STA│
│ Long Sword · ATK        │
│ Kanji: 斬               │
└─────────────────────────┘
```

Color coding:
- Attack: red border/icon
- Defence: blue border/icon  
- Parry: purple border/icon
- Heal: green border/icon

## Implementation Order

1. **Data Layer**
   - Create `data/actions.js` with all action definitions
   - Add `getMaxActiveActions(capacity)` helper
   - Update Player.js with active/inactive action arrays

2. **UI Layer**
   - Create `createSwitchActionDialog()` in BattleScene
   - Style action cards with equipment icons + kanji hints
   - Handle click-to-swap logic
   - Update "Switch Action" button to open dialog

3. **Parry Integration**
   - Add parry check in `runEnemyTurn()` before each attack
   - Show parry sprite → counter-attack sprite flow
   - Integrate kanji drawing for counter-attack
   - Add combat logs for parry/counter

4. **Heavy Slash Integration**
   - Add to action list, wire through TurnManager
   - Use forward_slash sprite as placeholder
   - Different damage formula (higher base + scaling)

5. **Validation**
   - Only show actions for equipped gear
   - Enforce capacity slot limit
   - At least 1 attack action must remain active

## Files to Modify
- `assets/js/game/data/actions.js` (new)
- `assets/js/game/entities/Player.js`
- `assets/js/game/scenes/BattleScene.js`
- `assets/js/game/systems/TurnManager.js`
- `assets/js/game/data/skills.js` (remove heal potion, keep for backwards compat)
