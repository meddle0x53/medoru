/**
 * Action definitions for the Switch Action system.
 * Each action is a combat skill that can be active or inactive.
 * Compatible with TurnManager.useSkill() interface.
 *
 * Abilities are now loaded from JSON files so they can be edited without
 * touching JavaScript. The JSON is bundled at build time, keeping the game
 * fully offline-capable.
 */

import { ALL_ABILITIES } from './abilities/index.js'

export const ALL_ACTIONS = ALL_ABILITIES

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
    if (a.requiredSocketCharm) {
      if (!player.hasSocketCharmEquipped(a.requiredSocketCharm)) return false
    }
    if (a.requiredCharmFamily) {
      const type = a.equipmentType || 'weapon'
      if (player.getSocketCharmFamily(type) !== a.requiredCharmFamily) return false
    }
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
    case 'infuse': return { main: 0x9b59b6, hover: 0xaf7ac5, label: 'INF' }
    default: return { main: 0x7f8c8d, hover: 0x95a5a6, label: '???' }
  }
}
