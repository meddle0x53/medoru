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
 */
export function getMaxActiveActions(capacity) {
  if (capacity >= 60) return 6
  if (capacity >= 35) return 5
  if (capacity >= 15) return 4
  return 3
}

/**
 * Max combat abilities available in the battle pool (selectedActionIds, excluding use_item).
 */
export function getMaxBattlePoolActions(capacity) {
  if (capacity >= 60) return 20
  if (capacity >= 40) return 15
  if (capacity >= 30) return 14
  if (capacity >= 20) return 12
  return 10
}

/**
 * Max total learned combat abilities (knownActionIds, excluding use_item).
 */
export function getMaxOverallAbilities(capacity) {
  if (capacity >= 60) return 30
  if (capacity >= 45) return 22
  if (capacity >= 25) return 20
  if (capacity >= 20) return 18
  return 15
}

/**
 * Get all actions available to the player based on equipped gear.
 */
export function getAvailableActions(player) {
  const unlockedIds = new Set(player.loadout?.unlockedAbilityIds || [])
  return ALL_ACTIONS.filter(a => {
    if (a.id === 'use_item') return true
    if (!unlockedIds.has(a.id)) return false
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
  // Determine the action pool: loadout.selectedActionIds if available, otherwise all actions.
  // Use Item is handled separately and never consumes a combat active slot.
  const poolIds = player.loadout?.selectedActionIds
  const universe = poolIds && poolIds.length > 0
    ? ALL_ACTIONS.filter(a => poolIds.includes(a.id) && a.id !== 'use_item')
    : ALL_ACTIONS.filter(a => a.id !== 'use_item')

  const available = getAvailableActions(player)
  // Intersect available gear with selected pool
  const pool = universe.filter(a => available.some(av => av.id === a.id))

  const maxActive = getMaxActiveActions(player.capacity || 3)

  // Use loadout.activeActionIds if present, otherwise fall back to direct property
  const activeIds = player.loadout?.activeActionIds || player.activeActionIds || []
  const useItemActive = activeIds.includes('use_item')

  if (activeIds.length > 0) {
    const active = []
    for (const id of activeIds) {
      if (id === 'use_item') continue
      const action = pool.find(a => a.id === id)
      if (action) active.push(action)
    }
    const inactive = pool.filter(a => !active.some(act => act.id === a.id))

    // Ensure we have at least one attack in active
    if (!active.some(a => a.type === 'attack')) {
      const firstAttack = inactive.find(a => a.type === 'attack')
      if (firstAttack) {
        inactive.splice(inactive.indexOf(firstAttack), 1)
        active.push(firstAttack)
      }
    }

    // Trim combat active abilities to maxActive (Use Item is added afterwards).
    while (active.length > maxActive) {
      const nonAttack = active.findLast(a => a.type !== 'attack')
      if (nonAttack) {
        active.splice(active.indexOf(nonAttack), 1)
        inactive.unshift(nonAttack)
      } else {
        break
      }
    }

    if (useItemActive) {
      const useItemAction = ALL_ACTIONS.find(a => a.id === 'use_item')
      if (useItemAction) active.push(useItemAction)
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

  if (useItemActive) {
    const useItemAction = ALL_ACTIONS.find(a => a.id === 'use_item')
    if (useItemAction) active.push(useItemAction)
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
