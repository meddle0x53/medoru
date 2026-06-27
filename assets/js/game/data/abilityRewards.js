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
    // Socket-1 charm family abilities. These are added to the relevant equipment
    // pool only when the matching family is equipped.
    family: {
      bleed: ['gutting_slash'],
      heavy: ['seismic_slam'],
      fire: ['flame_arc'],
    },
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
  if (player && typeof player.getSocketCharmFamily === 'function') {
    const weaponFamily = player.getSocketCharmFamily('primary_weapon')
    if (weaponFamily && classTable.family?.[weaponFamily]) {
      weapon.push(...classTable.family[weaponFamily])
    }
    const shieldFamily = player.getSocketCharmFamily('secondary_weapon')
    if (shieldFamily && classTable.family?.[shieldFamily]) {
      shield.push(...classTable.family[shieldFamily])
    }
  }

  return { weapon, shield, class: classPool }
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
