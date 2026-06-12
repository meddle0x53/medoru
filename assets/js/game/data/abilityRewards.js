/**
 * Post-battle ability reward pools.
 * Reward abilities are class and equipment based.
 * All rewards are currently rarity 'normal'.
 */

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
  },
  archer: {
    weapon_Bow: [],
    class: [],
  },
}

/**
 * Build a reward pool for the player, grouped by source category.
 * Returns { weapon, shield, class } arrays.
 */
export function getRewardPool(playerClass = 'warrior', weaponName, shieldName) {
  const classTable = ABILITY_REWARDS[playerClass] || ABILITY_REWARDS.warrior

  const weaponKey = weaponName ? `weapon_${weaponName.replace(/\s+/g, '_')}` : null
  const shieldKey = shieldName ? `shield_${shieldName.replace(/\s+/g, '_')}` : null

  return {
    weapon: weaponKey && classTable[weaponKey] ? [...classTable[weaponKey]] : [],
    shield: shieldKey && classTable[shieldKey] ? [...classTable[shieldKey]] : [],
    class: classTable.class ? [...classTable.class] : [],
  }
}

/**
 * Pick a set of reward ability IDs.
 * Guarantees variety by drawing at least one ability from each available
 * category (weapon/shield/class) before filling the rest from the full pool.
 */
export function pickRewardAbilities(pool, count, alreadyKnownIds = []) {
  const known = new Set(alreadyKnownIds)
  const picks = []
  const isUnknown = (id) => !known.has(id)
  const notPicked = (id) => !picks.includes(id)

  const categories = ['weapon', 'shield', 'class']

  // Round 1: one pick from each category so rewards feel varied
  for (const cat of categories) {
    if (picks.length >= count) break
    const options = shuffle(pool[cat].filter(isUnknown).filter(notPicked))
    if (options.length > 0) {
      picks.push(options[0])
    }
  }

  // Round 2: fill remaining slots from all remaining unknown abilities
  const allOptions = shuffle(
    [...pool.weapon, ...pool.shield, ...pool.class]
      .filter(isUnknown)
      .filter(notPicked)
  )

  while (picks.length < count && allOptions.length > 0) {
    picks.push(allOptions.shift())
  }

  return picks
}

function shuffle(array) {
  const arr = [...array]
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[arr[i], arr[j]] = [arr[j], arr[i]]
  }
  return arr
}
