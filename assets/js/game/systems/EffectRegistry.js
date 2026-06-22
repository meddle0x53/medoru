/**
 * EffectRegistry
 *
 * Version-controlled definitions for every status effect, elemental guard,
 * progressive chance, and element-vs-defence interaction.
 *
 * Abilities will reference these IDs; the combat engine resolves the behavior.
 */

export const ELEMENTS = {
  FIRE: 'fire',
  WATER: 'water',
  WIND: 'wind',
  EARTH: 'earth',
  VOID: 'void',
  POISON: 'poison',
  DARK: 'dark',
  LIGHT: 'light',
}

/**
 * Dark / Light are treated as Void until their own mechanics are designed.
 */
export const EFFECTIVE_ELEMENT = {
  [ELEMENTS.DARK]: ELEMENTS.VOID,
  [ELEMENTS.LIGHT]: ELEMENTS.VOID,
}

export const EFFECT_CATEGORIES = {
  BUFF: 'buff',
  DEBUFF: 'debuff',
  ONE_OFF: 'one-off',
}

/**
 * Core status effect catalog.
 * Each entry is pure data; combat code will interpret the flags.
 */
export const STATUS_EFFECTS = {
  burn: {
    id: 'burn',
    name: 'Burned',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    duration: { min: 3, max: 5 },
    tick: {
      damage: { source: 'snapshot', multiplier: 0.75 },
    },
    snapshotKey: 'burnInitialDamage',
    description: 'Take 75% of the initial fire damage each turn.',
  },

  poison: {
    id: 'poison',
    name: 'Poisoned',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    duration: { min: 5, max: 10 },
    tick: {
      damage: { source: 'snapshot', multiplier: 0.50 },
    },
    snapshotKey: 'poisonInitialDamage',
    curableBy: ['antidote', 'purify'],
    description: 'Take 50% of the initial poison damage each turn.',
  },

  weak: {
    id: 'weak',
    name: 'Weak',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'refresh',
    duration: { min: 2, max: 3 },
    outgoingDamageMultiplier: 0.75,
    description: 'Deal 75% damage.',
  },

  bleed: {
    id: 'bleed',
    name: 'Bleed',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'refresh',
    trigger: {
      damage: { source: 'targetMaxHp', multiplier: 0.10 },
      consumeOnTrigger: true,
    },
    description: 'Next damage instance consumes Bleed and deals 10% of max HP.',
  },

  blunt: {
    id: 'blunt',
    name: 'Blunt',
    category: EFFECT_CATEGORIES.ONE_OFF,
    incomingDamageMultiplier: 2.0,
    description: 'The triggering earth attack deals double damage.',
  },

  frost: {
    id: 'frost',
    name: 'Frost',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    duration: { min: 1, max: 2 },
    staminaMultiplier: 0.5,
    incomingDamageMultiplier: 1.25,
    description: 'Next turn stamina is halved; take 25% more damage.',
  },

  madness: {
    id: 'madness',
    name: 'Madness',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'refresh',
    duration: { min: 1, max: 3 },
    onApply: 'rollMadnessOutcome',
    description: 'Triggers a random bad effect or halves stamina next turn.',
  },

  stamina_crash: {
    id: 'stamina_crash',
    name: 'Stamina Crash',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'refresh',
    duration: { min: 1, max: 1 },
    staminaMultiplier: 0.5,
    description: 'Stamina is halved next turn.',
  },

  // Combo infusion values (used as infusion IDs, not necessarily applied as status effects)
  blaze: {
    id: 'blaze',
    name: 'Blaze',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'A fierce fire infusion.',
  },
  magma: {
    id: 'magma',
    name: 'Magma',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Fire and earth combined.',
  },
  storm: {
    id: 'storm',
    name: 'Storm',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Water and wind combined.',
  },
  mud: {
    id: 'mud',
    name: 'Mud',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Water and earth combined.',
  },
  dust: {
    id: 'dust',
    name: 'Dust',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Wind and earth combined.',
  },
  blizzard: {
    id: 'blizzard',
    name: 'Blizzard',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Water and ice combined.',
  },
  toxic_flame: {
    id: 'toxic_flame',
    name: 'Toxic Flame',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Fire and poison combined.',
  },
  toxic_cloud: {
    id: 'toxic_cloud',
    name: 'Toxic Cloud',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Wind and poison combined.',
  },
  venomous_earth: {
    id: 'venomous_earth',
    name: 'Venomous Earth',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Earth and poison combined.',
  },
  hemorrhage: {
    id: 'hemorrhage',
    name: 'Hemorrhage',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Wind and bleed combined.',
  },
  impale: {
    id: 'impale',
    name: 'Impale',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Earth and bleed combined.',
  },
  infected_wound: {
    id: 'infected_wound',
    name: 'Infected Wound',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Bleed and poison combined.',
  },
  toxic_ice: {
    id: 'toxic_ice',
    name: 'Toxic Ice',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Ice and poison combined.',
  },
  inferno: {
    id: 'inferno',
    name: 'Inferno',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'A raging fire storm.',
  },
  tornado: {
    id: 'tornado',
    name: 'Tornado',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Wind, water, and earth combined.',
  },
  volcanic_mud: {
    id: 'volcanic_mud',
    name: 'Volcanic Mud',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Mud set ablaze.',
  },
  wildfire: {
    id: 'wildfire',
    name: 'Wildfire',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    description: 'Fire spread by wind.',
  },

  ember: {
    id: 'ember',
    name: 'Ember',
    category: EFFECT_CATEGORIES.DEBUFF,
    stackRule: 'replace',
    duration: { min: 3, max: 5 },
    tick: {
      damage: { source: 'snapshot', multiplier: 0.75, spread: true },
    },
    snapshotKey: 'emberInitialDamage',
    description: 'Self-recoil from fire attacks; damage is spread over turns.',
  },

  power_up: {
    id: 'power_up',
    name: 'Power Up',
    category: EFFECT_CATEGORIES.BUFF,
    stackRule: 'refresh',
    duration: { min: 1, max: 3 },
    outgoingDamageMultiplier: 1.25,
    description: 'Successful attacks deal 25% more damage.',
  },

  element_infuse: {
    id: 'element_infuse',
    name: 'Element Infuse',
    category: EFFECT_CATEGORIES.BUFF,
    stackRule: 'replace',
    duration: { min: 1, max: 2 },
    description: 'The next attack is treated as the infused element.',
  },

  // Elemental guards
  fire_guard: {
    id: 'fire_guard',
    name: 'Fire Defence',
    category: EFFECT_CATEGORIES.BUFF,
    stackRule: 'refresh',
    duration: { min: 2, max: 4 },
    blocks: [ELEMENTS.EARTH],
    removedBy: [ELEMENTS.WATER],
    description: 'Blocks earth attacks. Removed by water attacks.',
  },

  water_guard: {
    id: 'water_guard',
    name: 'Water Defence',
    category: EFFECT_CATEGORIES.BUFF,
    stackRule: 'refresh',
    duration: { min: 2, max: 4 },
    blocks: [ELEMENTS.FIRE],
    removedBy: [ELEMENTS.WIND],
    cures: ['burn'],
    description: 'Heals burn and blocks fire attacks. Removed by wind attacks.',
  },

  wind_guard: {
    id: 'wind_guard',
    name: 'Wind Defence',
    category: EFFECT_CATEGORIES.BUFF,
    stackRule: 'refresh',
    duration: { min: 2, max: 4 },
    blocks: [ELEMENTS.WATER],
    removedBy: [ELEMENTS.EARTH],
    cures: ['weak'],
    description: 'Blocks water attacks and removes weak. Removed by earth attacks.',
  },

  earth_guard: {
    id: 'earth_guard',
    name: 'Earth Defence',
    category: EFFECT_CATEGORIES.BUFF,
    stackRule: 'refresh',
    duration: { min: 2, max: 4 },
    blocks: [ELEMENTS.WIND],
    removedBy: [ELEMENTS.EARTH],
    description: 'Blocks wind attacks. Removed by earth attacks.',
  },

  void_guard: {
    id: 'void_guard',
    name: 'Void Defence',
    category: EFFECT_CATEGORIES.BUFF,
    stackRule: 'refresh',
    duration: { min: 2, max: 4 },
    voidChanceMultiplier: 0.5,
    bonusGuard: ['fire_guard', 'water_guard', 'wind_guard', 'earth_guard'],
    description: 'Void effect chances are halved. Also grants a random elemental guard.',
  },
}

/**
 * Default progressive chances used when an ability does not override them.
 * chance = base + step * (consecutiveHits - 1), capped at cap.
 */
export const DEFAULT_PROGRESSIVE_CHANCES = {
  burn: { base: 0.10, step: 0.05, cap: 0.35 },
  weak: { base: 0.15, step: 0.05, cap: 0.40 },
  frost: { base: 0.02, step: 0.02, cap: 0.10 },
  bleed: { base: 0.05, step: 0.05, cap: 0.25 },
  blunt: { base: 0.05, step: 0.05, cap: 0.25 },
  madness: { base: 0.05, step: 0.05, cap: 0.25 },
}

/**
 * Element-vs-defence interactions.
 * Keys: attack element. Values: per-guard effect descriptors.
 */
const INTERACTION_MATRIX = {
  [ELEMENTS.FIRE]: {
    fire_guard: { blocked: false },
    water_guard: { blocked: true, removeGuard: true, cureEffects: ['burn'] },
    wind_guard: { blocked: false },
    earth_guard: { blocked: false },
    void_guard: { voidChanceMultiplier: 0.5 },
  },
  [ELEMENTS.WATER]: {
    fire_guard: { blocked: false, removeGuard: true },
    water_guard: { blocked: false },
    wind_guard: { blocked: false },
    earth_guard: { blocked: false },
    void_guard: { voidChanceMultiplier: 0.5 },
  },
  [ELEMENTS.WIND]: {
    fire_guard: { blocked: false },
    water_guard: { blocked: false, removeGuard: true },
    wind_guard: { blocked: false, cureEffects: ['weak'] },
    earth_guard: { blocked: false },
    void_guard: { voidChanceMultiplier: 0.5 },
  },
  [ELEMENTS.EARTH]: {
    fire_guard: { blocked: true },
    water_guard: { blocked: false },
    wind_guard: { blocked: false, removeGuard: true },
    earth_guard: { blocked: false, removeGuard: true },
    void_guard: { voidChanceMultiplier: 0.5 },
  },
  [ELEMENTS.VOID]: {
    fire_guard: { blocked: false },
    water_guard: { blocked: false },
    wind_guard: { blocked: false },
    earth_guard: { blocked: false },
    void_guard: { voidChanceMultiplier: 0.5 },
  },
  [ELEMENTS.POISON]: {
    // Poison is unaffected by elemental guards.
  },
}

// ---------- helpers ----------

export function getEffect(effectId) {
  return STATUS_EFFECTS[effectId] || null
}

export function effectExists(effectId) {
  return effectId in STATUS_EFFECTS
}

export function isBuff(effectId) {
  const effect = getEffect(effectId)
  return effect?.category === EFFECT_CATEGORIES.BUFF
}

export function isDebuff(effectId) {
  const effect = getEffect(effectId)
  return effect?.category === EFFECT_CATEGORIES.DEBUFF
}

export function rollDuration(effect) {
  const { min, max } = effect?.duration || { min: 1, max: 1 }
  return Math.floor(Math.random() * (max - min + 1)) + min
}

/**
 * Compute a progressive trigger chance.
 *
 * @param {object} config - { base, step, cap }
 * @param {number} consecutiveHits - number of consecutive same-element hits (>=1)
 */
export function rollChance(config, consecutiveHits = 1) {
  const { base = 0, step = 0, cap = 1 } = config || {}
  const chance = base + step * Math.max(0, consecutiveHits - 1)
  return Math.min(chance, cap)
}

export function getDefaultChance(effectId) {
  return DEFAULT_PROGRESSIVE_CHANCES[effectId] || { base: 0, step: 0, cap: 0 }
}

/**
 * Resolve what happens when an element hits a target with active guard effects.
 *
 * @param {string} attackElement
 * @param {string[]} activeEffectIds - effect IDs currently on the target
 * @returns {object} {
 *   blocked: boolean,
 *   removeGuards: string[],
 *   cureEffects: string[],
 *   voidChanceMultiplier: number
 * }
 */
export function resolveElementVsDefence(attackElement, activeEffectIds) {
  const effectiveElement = EFFECTIVE_ELEMENT[attackElement] || attackElement
  const matrix = INTERACTION_MATRIX[effectiveElement] || {}

  const result = {
    blocked: false,
    removeGuards: [],
    cureEffects: [],
    voidChanceMultiplier: 1.0,
  }

  for (const effectId of activeEffectIds) {
    const interaction = matrix[effectId]
    if (!interaction) continue

    const effect = getEffect(effectId)

    if (interaction.blocked) {
      result.blocked = true
    }
    if (interaction.removeGuard) {
      result.removeGuards.push(effectId)
    }
    if (interaction.cureEffects) {
      for (const cured of interaction.cureEffects) {
        if (!result.cureEffects.includes(cured)) {
          result.cureEffects.push(cured)
        }
      }
    }
    if (interaction.voidChanceMultiplier !== undefined) {
      result.voidChanceMultiplier *= interaction.voidChanceMultiplier
    }

    // Apply passive guard cures even when the attack is not blocked.
    if (effect?.cures) {
      for (const cured of effect.cures) {
        if (!result.cureEffects.includes(cured)) {
          result.cureEffects.push(cured)
        }
      }
    }
  }

  return result
}

const MADNESS_EFFECT_POOL = ['burn', 'bleed', 'frost', 'weak', 'poison']

/**
 * Roll the random outcome of Madness.
 *
 * @returns {object} { type: 'effect', effectId: string } | { type: 'stamina_halved' }
 */
export function rollMadnessOutcome() {
  const roll = Math.random()
  if (roll < 0.5) {
    const effectId = MADNESS_EFFECT_POOL[Math.floor(Math.random() * MADNESS_EFFECT_POOL.length)]
    return { type: 'effect', effectId }
  }
  return { type: 'stamina_halved' }
}

/**
 * Pick a random bonus guard for Void Defence.
 */
export function getRandomBonusGuard() {
  const guards = STATUS_EFFECTS.void_guard.bonusGuard
  return guards[Math.floor(Math.random() * guards.length)]
}

/**
 * Spread a total damage value evenly over a number of turns.
 * Useful for Ember and similar "total damage over duration" effects.
 */
export function spreadDamageOverTurns(total, turns) {
  if (turns <= 0) return []
  const base = Math.floor(total / turns)
  const remainder = total - base * turns
  const ticks = Array(turns).fill(base)
  for (let i = 0; i < remainder; i++) {
    ticks[i] += 1
  }
  return ticks
}
