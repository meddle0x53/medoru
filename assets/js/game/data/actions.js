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
 * Returns { active, inactive }
 */
export function splitActions(player) {
  const available = getAvailableActions(player)
  const maxActive = getMaxActiveActions(player.capacity || 3)

  // If player has stored preferences, use them
  if (player.activeActionIds && player.activeActionIds.length > 0) {
    const active = available.filter(a => player.activeActionIds.includes(a.id))
    const inactive = available.filter(a => !player.activeActionIds.includes(a.id))
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

  // Default split for demo
  const defaultActiveIds = ['forward_slash', 'setup_defence', 'shield_parry']
  const active = []
  const inactive = []

  for (const action of available) {
    if (defaultActiveIds.includes(action.id) && active.length < maxActive) {
      active.push(action)
    } else {
      inactive.push(action)
    }
  }

  // Ensure at least one attack is active
  if (!active.some(a => a.type === 'attack')) {
    const firstAttack = inactive.find(a => a.type === 'attack')
    if (firstAttack) {
      inactive.splice(inactive.indexOf(firstAttack), 1)
      active.push(firstAttack)
    }
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
    default: return { main: 0x7f8c8d, hover: 0x95a5a6, label: '???' }
  }
}
