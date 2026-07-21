/**
 * Post-battle ability reward pools.
 * Reward abilities are class and equipment based.
 * Rarity weights now scale by map column and tile type.
 */

import ABILITY_FAMILIES from './abilityFamilies.json'
import { ALL_ACTIONS } from './actions.js'
import { TILE_TYPES } from './tileTypes.js'

export const ABILITY_REWARDS = {
  warrior: {
    // Long Sword weapon skills
    weapon_Long_Sword: ['heavy_slash', 'quick_stab', 'guard_break', 'two_hand_heavy', 'sword_buff', 'berserk'],
    // Wooden Shield skills
    shield_Wooden_Shield: ['shield_parry', 'setup_defence', 'shield_bash'],
    // Generic warrior class skills
    class: ['focus', 'taunt', 'dash'],
  },
  // Placeholders for future classes
  mage: {
    weapon_Staff: [],
    class: [],
    family: {},
  },
  archer: {
    weapon_Bow: [],
    class: [],
    family: {},
  },
}

/**
 * Rarity weights for normal battles and memory challenges based on map column.
 */
const COLUMN_RARITY_WEIGHTS = {
  low: { common: 0.70, uncommon: 0.15, rare: 0.10, epic: 0.05 },
  midLow: { common: 0.60, uncommon: 0.20, rare: 0.15, epic: 0.05 },
  midHigh: { common: 0.50, uncommon: 0.25, rare: 0.20, epic: 0.05 },
  high: { common: 0.40, uncommon: 0.30, rare: 0.20, epic: 0.10 },
}

/**
 * Return rarity weights for an ability reward based on the tile that generated it.
 * Normal battles / memory challenges use column-based scaling.
 * Mini-boss and boss tiles use fixed weights.
 * Returns null if no tile is provided (caller falls back to uniform random).
 */
export function getRarityWeightsForTile(tile) {
  if (!tile) return null

  if (tile.type === TILE_TYPES.BOSS) {
    return { common: 0, uncommon: 0.30, rare: 0.30, epic: 0.40 }
  }
  if (tile.type === TILE_TYPES.MINI_BOSS) {
    return { common: 0.20, uncommon: 0.30, rare: 0.30, epic: 0.20 }
  }

  const col = tile.col ?? 0
  if (col <= 2) return COLUMN_RARITY_WEIGHTS.low
  if (col <= 4) return COLUMN_RARITY_WEIGHTS.midLow
  if (col <= 6) return COLUMN_RARITY_WEIGHTS.midHigh
  return COLUMN_RARITY_WEIGHTS.high
}

function mapAbilityRarity(rarity) {
  if (rarity === 'normal') return 'common'
  return rarity || 'common'
}

/**
 * Build a reward pool for the player, grouped by source category.
 * Accepts either a Player object or the old (playerClass, weaponName, shieldName)
 * signature for backward compatibility.
 * Returns { weapon, shield, class } arrays.
 */
export function getRewardPool(playerOrClass = 'warrior', weaponName, shieldName) {
  const isPlayer = playerOrClass && typeof playerOrClass === 'object' && playerOrClass.loadout
  const player = isPlayer ? playerOrClass : null
  const playerClass = player?.loadout?.class || (typeof playerOrClass === 'string' ? playerOrClass : 'warrior')
  const classTable = ABILITY_REWARDS[playerClass] || ABILITY_REWARDS.warrior

  const weaponNameResolved = player?.weapon?.name || weaponName
  const shieldNameResolved = player?.shield?.name || shieldName

  const weaponKey = weaponNameResolved ? `weapon_${weaponNameResolved.replace(/\s+/g, '_')}` : null
  const shieldKey = shieldNameResolved ? `shield_${shieldNameResolved.replace(/\s+/g, '_')}` : null

  const weapon = weaponKey && classTable[weaponKey] ? [...classTable[weaponKey]] : []
  const shield = shieldKey && classTable[shieldKey] ? [...classTable[shieldKey]] : []
  const classPool = classTable.class ? [...classTable.class] : []

  // Inject family-locked abilities based on the equipped socket-1 charm families.
  // The family -> ability mapping lives in abilityFamilies.json so it can be
  // edited without touching JavaScript.
  const familyTable = ABILITY_FAMILIES[playerClass] || {}
  if (player && typeof player.getSocketCharmFamily === 'function') {
    const weaponFamily = player.getSocketCharmFamily('primary_weapon')
    if (weaponFamily && familyTable[weaponFamily]) {
      weapon.push(...familyTable[weaponFamily])
    }
    const shieldFamily = player.getSocketCharmFamily('secondary_weapon')
    if (shieldFamily && familyTable[shieldFamily]) {
      shield.push(...familyTable[shieldFamily])
    }
  }

  return { weapon, shield, class: classPool }
}

/**
 * Pick a set of reward ability IDs.
 * Guarantees variety by drawing at least one ability from each available
 * category (weapon/shield/class) before filling the rest from the full pool.
 * If a tile is provided, abilities are weighted by their rarity using the
 * tile's column and type.
 */
function isSingleUseAbility(id) {
  const action = ALL_ACTIONS.find(a => a.id === id)
  return action?.singleUse === true
}

function weightedPickId(ids, weights) {
  if (!weights) {
    return ids[Math.floor(Math.random() * ids.length)]
  }

  const entries = ids.map(id => {
    const action = ALL_ACTIONS.find(a => a.id === id)
    const rarity = mapAbilityRarity(action?.rarity)
    return { id, weight: weights[rarity] || 0 }
  })

  const total = entries.reduce((sum, e) => sum + e.weight, 0)
  if (total <= 0) {
    return ids[Math.floor(Math.random() * ids.length)]
  }

  let roll = Math.random() * total
  for (const entry of entries) {
    roll -= entry.weight
    if (roll <= 0) return entry.id
  }
  return entries[entries.length - 1].id
}

export function pickRewardAbilities(pool, count, alreadyKnownIds = [], tile = null) {
  const weights = getRarityWeightsForTile(tile)
  const known = new Set(alreadyKnownIds)
  const picks = []
  // Single-use abilities can be rewarded again to add charges; multi-use abilities are only offered once.
  const isEligible = (id) => !known.has(id) || isSingleUseAbility(id)
  const notPicked = (id) => !picks.includes(id)

  const categories = ['weapon', 'shield', 'class']

  // Round 1: one pick from each category so rewards feel varied
  for (const cat of categories) {
    if (picks.length >= count) break
    const options = pool[cat].filter(isEligible).filter(notPicked)
    if (options.length === 0) continue
    picks.push(weightedPickId(options, weights))
  }

  // Round 2: fill remaining slots from all remaining eligible abilities
  while (picks.length < count) {
    const allOptions = [...pool.weapon, ...pool.shield, ...pool.class]
      .filter(isEligible)
      .filter(notPicked)
    if (allOptions.length === 0) break
    picks.push(weightedPickId(allOptions, weights))
  }

  return picks
}
