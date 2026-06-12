/**
 * Action definitions for the Switch Action system.
 * Each action is a combat skill that can be active or inactive.
 * Compatible with TurnManager.useSkill() interface.
 */

export const ALL_ACTIONS = [
  {
    id: 'forward_slash',
    name: 'Forward Slash',
    nameJa: '斬撃',
    description: 'A swift sword strike.',
    type: 'attack',
    equipmentType: 'weapon',
    requiredEquipment: 'Long Sword',
    staminaCost: 3,
    basePower: 8,
    scalingStat: 'strength',
    scalingMultiplier: 1.0,
    kanji: '力',
    rarity: 'normal',
    moveHint: { en: 'Make a POWERFUL swing.', ja: '強力な一振りを。' },
  },
  {
    id: 'heavy_slash',
    name: 'Heavy Slash',
    nameJa: '重斬',
    description: 'A powerful but slower strike.',
    type: 'attack',
    equipmentType: 'weapon',
    requiredEquipment: 'Long Sword',
    staminaCost: 4,
    basePower: 16,
    scalingStat: 'strength',
    scalingMultiplier: 1.2,
    kanji: '斬',
    rarity: 'normal',
    moveHint: { en: 'Unleash a DEVASTATING blow!', ja: '壊滅的な一撃を放て！' },
  },
  {
    id: 'setup_defence',
    name: 'Setup Defence',
    nameJa: '防御',
    description: 'Raise your guard.',
    type: 'defence',
    equipmentType: 'shield',
    requiredEquipment: 'Wooden Shield',
    staminaCost: 2,
    baseBlock: 5,
    scalingStat: 'skill',
    scalingMultiplier: 0.8,
    kanji: '盾',
    rarity: 'normal',
    moveHint: { en: 'Raise your GUARD.', ja: '盾を構えろ。' },
  },
  {
    id: 'shield_parry',
    name: 'Shield Parry',
    nameJa: '受け流し',
    description: 'Chance to parry and counter-attack when hit.',
    type: 'parry',
    equipmentType: 'shield',
    requiredEquipment: 'Wooden Shield',
    staminaCost: 2,
    baseParryChance: 0.15,
    kanji: '受',
    rarity: 'normal',
  },
  {
    id: 'use_item',
    name: 'Use Item',
    nameJa: 'アイテム',
    description: 'Use an item from your inventory.',
    type: 'item',
    equipmentType: null,
    requiredEquipment: null,
    staminaCost: 1,
    kanji: '使',
    rarity: 'normal',
  },
  {
    id: 'quick_stab',
    name: 'Quick Stab',
    nameJa: '突き',
    description: 'A fast thrust that costs little stamina.',
    type: 'attack',
    equipmentType: 'weapon',
    requiredEquipment: 'Long Sword',
    staminaCost: 2,
    basePower: 5,
    scalingStat: 'skill',
    scalingMultiplier: 0.9,
    kanji: '突',
    rarity: 'normal',
  },
  {
    id: 'guard_break',
    name: 'Guard Break',
    nameJa: '破防',
    description: 'An overhead smash that ignores enemy defense.',
    type: 'attack',
    equipmentType: 'weapon',
    requiredEquipment: 'Long Sword',
    staminaCost: 5,
    basePower: 12,
    scalingStat: 'strength',
    scalingMultiplier: 1.0,
    kanji: '破',
    rarity: 'normal',
  },
  {
    id: 'focus',
    name: 'Focus',
    nameJa: '集中',
    description: 'Raise readiness to maximum.',
    type: 'buff',
    equipmentType: null,
    requiredEquipment: null,
    staminaCost: 2,
    kanji: '集',
    rarity: 'normal',
  },
  {
    id: 'taunt',
    name: 'Taunt',
    nameJa: '挑発',
    description: 'Force the enemy to target you and lower their defense.',
    type: 'debuff',
    equipmentType: null,
    requiredEquipment: null,
    staminaCost: 2,
    kanji: '挑',
    rarity: 'normal',
  },
  {
    id: 'dash',
    name: 'Dash',
    nameJa: '疾走',
    description: 'Dodge the next enemy attack.',
    type: 'defence',
    equipmentType: null,
    requiredEquipment: null,
    staminaCost: 3,
    kanji: '疾',
    rarity: 'normal',
  },
  {
    id: 'two_hand_heavy',
    name: 'Two-Hand Heavy',
    nameJa: '両手重撃',
    description: 'A powerful two-handed strike.',
    type: 'attack',
    equipmentType: 'weapon',
    requiredEquipment: 'Long Sword',
    staminaCost: 5,
    basePower: 24,
    scalingStat: 'strength',
    scalingMultiplier: 1.2,
    kanji: '両',
    rarity: 'normal',
  },
  {
    id: 'sword_buff',
    name: 'Sharpen Blade',
    nameJa: '鋭気',
    description: 'Kanji quality sharpens your blade; sword attacks deal bonus damage.',
    type: 'buff',
    equipmentType: 'weapon',
    requiredEquipment: 'Long Sword',
    staminaCost: 3,
    kanji: '鋭',
    rarity: 'normal',
    buffType: 'sword_damage_bonus',
  },
  {
    id: 'shield_bash',
    name: 'Shield Bash',
    nameJa: '盾打',
    description: 'Strike with your shield and raise a partial guard.',
    type: 'attack_defence',
    equipmentType: 'shield',
    requiredEquipment: 'Wooden Shield',
    staminaCost: 2,
    basePower: 2,
    scalingStat: 'strength',
    scalingMultiplier: 0.5,
    baseBlock: 3,
    scalingBlockStat: 'skill',
    scalingBlockMultiplier: 0.4,
    kanji: '打',
    rarity: 'normal',
  },
  {
    id: 'berserk',
    name: 'Berserk',
    nameJa: '狂戦',
    description: 'Enter a rage; sword attacks heal you for part of the damage dealt.',
    type: 'buff',
    equipmentType: 'weapon',
    requiredEquipment: 'Long Sword',
    staminaCost: 6,
    kanji: '狂',
    rarity: 'normal',
    buffType: 'berserk_lifesteal',
  },
]

/**
 * Calculate max active action slots from capacity stat.
 * capacity  3 → 3 slots (minimum)
 * capacity 10 → 3 slots
 * capacity 20 → 4 slots
 * capacity 35 → 5 slots (maximum)
 */
export function getMaxActiveActions(capacity) {
  return Math.min(5, Math.max(3, 2 + Math.floor(capacity / 10)))
}

/**
 * Get all actions available to the player based on equipped gear.
 */
export function getAvailableActions(player) {
  return ALL_ACTIONS.filter(a => {
    if (!a.requiredEquipment) return true
    if (a.equipmentType === 'weapon') return player.weapon?.name === a.requiredEquipment
    if (a.equipmentType === 'shield') return player.shield?.name === a.requiredEquipment
    return true
  })
}

/**
 * Split available actions into active/inactive based on player state.
 * Uses the player's selected action pool if configured via loadout.
 * Returns { active, inactive }
 */
export function splitActions(player) {
  // Determine the action pool: loadout.selectedActionIds if available, otherwise all actions
  const poolIds = player.loadout?.selectedActionIds
  const universe = poolIds && poolIds.length > 0
    ? ALL_ACTIONS.filter(a => poolIds.includes(a.id))
    : ALL_ACTIONS

  const available = getAvailableActions(player)
  // Intersect available gear with selected pool
  const pool = universe.filter(a => available.some(av => av.id === a.id))

  const maxActive = getMaxActiveActions(player.capacity || 3)

  // Use loadout.activeActionIds if present, otherwise fall back to direct property
  const activeIds = player.loadout?.activeActionIds || player.activeActionIds || []

  if (activeIds.length > 0) {
    const active = pool.filter(a => activeIds.includes(a.id))
    const inactive = pool.filter(a => !activeIds.includes(a.id))
    // Ensure we have at least one attack in active
    if (!active.some(a => a.type === 'attack')) {
      const firstAttack = inactive.find(a => a.type === 'attack')
      if (firstAttack) {
        inactive.splice(inactive.indexOf(firstAttack), 1)
        active.push(firstAttack)
      }
    }
    // Trim to maxActive
    while (active.length > maxActive) {
      const nonAttack = active.findLast(a => a.type !== 'attack')
      if (nonAttack) {
        active.splice(active.indexOf(nonAttack), 1)
        inactive.unshift(nonAttack)
      } else {
        break
      }
    }
    return { active, inactive }
  }

  // No active abilities selected: fall back to a single known attack only.
  const active = []
  const inactive = [...pool]

  const firstAttack = inactive.find(a => a.type === 'attack')
  if (firstAttack) {
    inactive.splice(inactive.indexOf(firstAttack), 1)
    active.push(firstAttack)
  }

  return { active, inactive }
}

/**
 * Get the color config for an action type.
 */
export function getActionTypeColor(type) {
  switch (type) {
    case 'attack': return { main: 0xc0392b, hover: 0xe74c3c, label: 'ATK' }
    case 'defence': return { main: 0x2980b9, hover: 0x3498db, label: 'DEF' }
    case 'parry': return { main: 0x8e44ad, hover: 0x9b59b6, label: 'PRY' }
    case 'heal': return { main: 0x27ae60, hover: 0x2ecc71, label: 'HL' }
    case 'item': return { main: 0x16a085, hover: 0x1abc9c, label: 'ITM' }
    case 'buff': return { main: 0xf39c12, hover: 0xf1c40f, label: 'BUF' }
    case 'debuff': return { main: 0x8e44ad, hover: 0x9b59b6, label: 'DEB' }
    case 'attack_defence': return { main: 0x16a085, hover: 0x1abc9c, label: 'ATK/DEF' }
    default: return { main: 0x7f8c8d, hover: 0x95a5a6, label: '???' }
  }
}
