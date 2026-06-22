/**
 * Infusion reaction table and elemental base effects.
 *
 * Infusing an already-infused ability can cancel, boost, or transform into a
 * combo element.  When an infused (or elemental enemy) attack lands, the base
 * element also applies its natural status effect.
 */

// Which mechanical element a given infusion value resolves to for defence,
// streaks and other elemental checks.  Combo elements resolve to their
// dominant base element.
export const ELEMENT_FOR_INFUSION = {
  fire: 'fire',
  water: 'water',
  wind: 'wind',
  earth: 'earth',
  void: 'void',
  poison: 'poison',
  frost: 'water',

  // combo elements
  blaze: 'fire',
  magma: 'fire',
  storm: 'water',
  nature: 'water',
  dust: 'earth',
  plague: 'poison',
  venom: 'poison',
  spore: 'poison',
  rot: 'poison',
  abyss: 'void',
  chaos: 'void',
  wither: 'void',
  silence: 'void',
  blight: 'void',
}

export function getElementForInfusion(value) {
  return ELEMENT_FOR_INFUSION[value] || null
}

// Guard granted by shield infusions.
const GUARD_FOR_INFUSION = {
  fire: 'fire_guard',
  water: 'water_guard',
  wind: 'wind_guard',
  earth: 'earth_guard',
  void: 'void_guard',
  poison: null,
  frost: 'water_guard',

  blaze: 'fire_guard',
  magma: 'fire_guard',
  storm: 'water_guard',
  nature: 'water_guard',
  dust: 'earth_guard',
  plague: null,
  venom: null,
  spore: null,
  rot: null,
  abyss: 'void_guard',
  chaos: 'void_guard',
  wither: 'void_guard',
  silence: 'wind_guard',
  blight: 'void_guard',
}

export function getGuardForInfusion(value) {
  return GUARD_FOR_INFUSION[value]
}

// Base elemental hit effects.
// `damageMultiplier` is added to the infused damage multiplier.
// `effects` is a list of { effectId, chance } applied on hit.
export const INFUSION_BASE_EFFECTS = {
  fire: { effects: [{ effectId: 'burn', chance: 0.4 }] },
  water: { effects: [{ effectId: 'frost', chance: 0.5 }] },
  wind: { effects: [{ effectId: 'weak', chance: 0.5 }] },
  earth: { effects: [{ effectId: 'blunt', chance: 0.4 }] },
  void: { damageMultiplier: 0.2, effects: [{ effectId: 'madness', chance: 0.3 }] },
  poison: { effects: [{ effectId: 'poison', chance: 0.5 }] },
  frost: { effects: [{ effectId: 'frost', chance: 0.5 }] },

  blaze: { damageMultiplier: 0.1, effects: [{ effectId: 'burn', chance: 0.35 }, { effectId: 'weak', chance: 0.35 }] },
  magma: { damageMultiplier: 0.15, effects: [{ effectId: 'burn', chance: 0.35 }, { effectId: 'blunt', chance: 0.35 }] },
  storm: { damageMultiplier: 0.1, effects: [{ effectId: 'frost', chance: 0.35 }, { effectId: 'weak', chance: 0.35 }] },
  nature: { damageMultiplier: 0.15, effects: [{ effectId: 'frost', chance: 0.35 }, { effectId: 'blunt', chance: 0.35 }] },
  dust: { damageMultiplier: 0.1, effects: [{ effectId: 'weak', chance: 0.35 }, { effectId: 'blunt', chance: 0.35 }] },

  plague: { damageMultiplier: 0.15, effects: [{ effectId: 'burn', chance: 0.3 }, { effectId: 'poison', chance: 0.4 }] },
  venom: { damageMultiplier: 0.15, effects: [{ effectId: 'frost', chance: 0.3 }, { effectId: 'poison', chance: 0.4 }] },
  spore: { damageMultiplier: 0.15, effects: [{ effectId: 'weak', chance: 0.3 }, { effectId: 'poison', chance: 0.4 }] },
  rot: { damageMultiplier: 0.15, effects: [{ effectId: 'blunt', chance: 0.3 }, { effectId: 'poison', chance: 0.4 }] },

  chaos: { damageMultiplier: 0.25, effects: [{ effectId: 'burn', chance: 0.3 }, { effectId: 'madness', chance: 0.25 }] },
  abyss: { damageMultiplier: 0.25, effects: [{ effectId: 'frost', chance: 0.3 }, { effectId: 'madness', chance: 0.25 }] },
  silence: { damageMultiplier: 0.25, effects: [{ effectId: 'weak', chance: 0.3 }, { effectId: 'madness', chance: 0.25 }] },
  wither: { damageMultiplier: 0.25, effects: [{ effectId: 'blunt', chance: 0.3 }, { effectId: 'madness', chance: 0.25 }] },
  blight: { damageMultiplier: 0.25, effects: [{ effectId: 'poison', chance: 0.35 }, { effectId: 'madness', chance: 0.25 }] },
}

export function getInfusionBaseEffect(value) {
  return INFUSION_BASE_EFFECTS[value]
}

export const INFUSION_ICONS = {
  fire: '🔥',
  water: '💧',
  wind: '🌪',
  earth: '🪨',
  void: '🌑',
  poison: '☠️',
  frost: '❄️',
  bleed: '🩸',

  blaze: '🔥🌪',
  magma: '🔥🪨',
  storm: '🌪💧',
  nature: '💧🪨',
  dust: '🌪🪨',

  plague: '🔥☠️',
  venom: '💧☠️',
  spore: '🌪☠️',
  rot: '🪨☠️',

  chaos: '🌑🔥',
  abyss: '🌑💧',
  silence: '🌑🌪',
  wither: '🌑🪨',
  blight: '🌑☠️',
}

// Reaction table keyed by sorted elemental identifiers.
// Values are the resulting infusion name.
const COMBO_REACTIONS = {
  'fire,wind': 'blaze',
  'fire,earth': 'magma',
  'wind,water': 'storm',
  'water,earth': 'nature',
  'wind,earth': 'dust',

  'fire,poison': 'plague',
  'water,poison': 'venom',
  'wind,poison': 'spore',
  'earth,poison': 'rot',

  'fire,void': 'chaos',
  'water,void': 'abyss',
  'wind,void': 'silence',
  'earth,void': 'wither',
  'poison,void': 'blight',
}

function elementalId(value) {
  // Bleed is a pure status, everything else maps to an element.
  if (value === 'bleed') return 'bleed'
  return getElementForInfusion(value) || value
}

function comboKey(a, b) {
  return [a, b].sort().join(',')
}

/**
 * Resolve what happens when an ability already infused with `existingValue`
 * receives a second infusion of `newValue`.
 *
 * Returns an object describing the outcome:
 *   type: 'boost' | 'cancel' | 'transform' | 'replace' | 'add_status'
 *   value: final infusion value
 *   extraEffects: extra status effects to apply alongside the value
 *   potencyDelta: amount to add to the existing infusion potency
 *   message: human-readable reaction description
 */
export function resolveInfusionReaction(existingValue, newValue, existingInfusion = null) {
  const a = elementalId(existingValue)
  const b = elementalId(newValue)

  // Same element / identical mapped element -> intensify.
  if (a === b) {
    const name = existingValue === newValue ? existingValue : `${existingValue}/${newValue}`
    return {
      type: 'boost',
      value: existingValue,
      extraEffects: [],
      potencyDelta: 0.5,
      message: `${name} intensifies!`,
    }
  }

  // Void corrupts or consumes whatever touches it.
  if (newValue === 'void') {
    return { type: 'replace', value: 'void', extraEffects: [], potencyDelta: 0.5, message: 'Void corrupts the infusion!' }
  }
  if (existingValue === 'void') {
    return { type: 'boost', value: 'void', extraEffects: [], potencyDelta: 0.5, message: 'Void consumes the new essence!' }
  }

  // Bleed layers on top of elemental infusions without changing the element.
  if (newValue === 'bleed') {
    return {
      type: 'add_status',
      value: existingValue,
      extraEffects: ['bleed'],
      potencyDelta: 0,
      message: `${existingValue} gains bleeding edge!`,
    }
  }
  if (existingValue === 'bleed') {
    return {
      type: 'transform',
      value: newValue,
      extraEffects: ['bleed'],
      potencyDelta: 0,
      message: `${newValue} seethes with blood!`,
    }
  }

  // Fire and water annihilate each other.
  if ((a === 'fire' && b === 'water') || (a === 'water' && b === 'fire')) {
    return { type: 'cancel', value: null, extraEffects: [], potencyDelta: 0, message: 'Fire and water cancel out!' }
  }

  // Look up a combo reaction using elemental ids.
  const key = comboKey(a, b)
  const combo = COMBO_REACTIONS[key]
  if (combo) {
    return {
      type: 'transform',
      value: combo,
      extraEffects: [],
      potencyDelta: 0.25,
      message: `Combo: ${combo}!`,
    }
  }

  // No special interaction: the new infusion replaces the old one.
  return {
    type: 'replace',
    value: newValue,
    extraEffects: [],
    potencyDelta: 0,
    message: `${newValue} replaces ${existingValue}.`,
  }
}
