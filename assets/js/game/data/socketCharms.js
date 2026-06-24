/**
 * Socket-specific charms for weapons and shields.
 *
 * Socket 1 charms are build-defining: they override base scaling and unlock
 * ability families. Socket 2/3/4 charms are defined later.
 *
 * Scaling rule format:
 *   { fixed: 'D' }                  -> always this grade
 *   { milestones: {1:'C',5:'B'} }   -> grade based on equipment level
 *   null                            -> remove this stat from scaling
 */

export const SOCKET_SLOTS = {
  WEAPON: 4,
  SHIELD: 4,
}

// First-socket sword charms.
export const WEAPON_SOCKET_1_CHARMS = [
  {
    id: 'sharp_charm_sword',
    name: 'Sharp Charm',
    nameJa: '鋭さの護符',
    kanji: '鋭',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0xcccccc,
    description: 'A keen edge. Favours skill and unlocks bleed abilities.',
    scaling: {
      strength: { fixed: 'D' },
      skill: { milestones: { 1: 'C', 5: 'B', 9: 'A' } },
    },
    abilityFamily: 'bleed',
  },
  {
    id: 'heavy_charm_sword',
    name: 'Heavy Charm',
    nameJa: '重さの護符',
    kanji: '重',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0x8b4513,
    description: 'A weighty blade. Favours raw strength.',
    scaling: {
      strength: { milestones: { 1: 'B', 6: 'A', 10: 'S' } },
    },
    abilityFamily: 'heavy',
  },
  {
    id: 'fire_charm_sword',
    name: 'Fire Charm',
    nameJa: '火の護符',
    kanji: '火',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0xff6600,
    description: 'Infuses the blade with flame. Adds arcane scaling.',
    scaling: {
      strength: { fixed: 'D' },
      skill: { fixed: 'D' },
      mana: { milestones: { 1: 'D', 4: 'C', 8: 'B', 10: 'A' } },
    },
    abilityFamily: 'fire',
    element: 'fire',
  },
  {
    id: 'water_charm_sword',
    name: 'Water Charm',
    nameJa: '水の護符',
    kanji: '水',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0x00ccff,
    description: 'Infuses the blade with frost. Adds arcane scaling.',
    scaling: {
      strength: { fixed: 'D' },
      skill: { fixed: 'D' },
      mana: { milestones: { 1: 'D', 4: 'C', 8: 'B', 10: 'A' } },
    },
    abilityFamily: 'water',
    element: 'water',
  },
  {
    id: 'wind_charm_sword',
    name: 'Wind Charm',
    nameJa: '風の護符',
    kanji: '風',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0xccffcc,
    description: 'A whistling edge. Adds arcane scaling.',
    scaling: {
      strength: { fixed: 'D' },
      skill: { fixed: 'D' },
      mana: { milestones: { 1: 'D', 4: 'C', 8: 'B', 10: 'A' } },
    },
    abilityFamily: 'wind',
    element: 'wind',
  },
  {
    id: 'earth_charm_sword',
    name: 'Earth Charm',
    nameJa: '土の護符',
    kanji: '土',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0x8b4513,
    description: 'A grounded blade. Adds arcane scaling.',
    scaling: {
      strength: { fixed: 'D' },
      skill: { fixed: 'D' },
      mana: { milestones: { 1: 'D', 4: 'C', 8: 'B', 10: 'A' } },
    },
    abilityFamily: 'earth',
    element: 'earth',
  },
  {
    id: 'poison_charm_sword',
    name: 'Poison Charm',
    nameJa: '毒の護符',
    kanji: '毒',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0x9932cc,
    description: 'A toxic edge. Adds arcane scaling.',
    scaling: {
      strength: { fixed: 'D' },
      skill: { fixed: 'D' },
      mana: { milestones: { 1: 'D', 4: 'C', 8: 'B', 10: 'A' } },
    },
    abilityFamily: 'poison',
    element: 'poison',
  },
  {
    id: 'dark_charm_sword',
    name: 'Dark Charm',
    nameJa: '闇の護符',
    kanji: '闇',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0x4b0082,
    description: 'A shadowed blade. Adds arcane scaling.',
    scaling: {
      strength: { fixed: 'D' },
      skill: { fixed: 'D' },
      mana: { milestones: { 1: 'D', 4: 'C', 8: 'B', 10: 'A' } },
    },
    abilityFamily: 'dark',
    element: 'void',
  },
  {
    id: 'light_charm_sword',
    name: 'Light Charm',
    nameJa: '光の護符',
    kanji: '光',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0xffd700,
    description: 'A radiant blade. Adds arcane scaling.',
    scaling: {
      strength: { fixed: 'D' },
      skill: { fixed: 'D' },
      mana: { milestones: { 1: 'D', 4: 'C', 8: 'B', 10: 'A' } },
    },
    abilityFamily: 'light',
    element: 'light',
  },
  {
    id: 'lucky_charm_sword',
    name: 'Lucky Charm',
    nameJa: '運の護符',
    kanji: '運',
    slot: 1,
    equipmentType: 'primary_weapon',
    color: 0xffd700,
    description: 'A fortune-seeking blade. Scales with luck.',
    scaling: {
      strength: null,
      skill: null,
      luck: { milestones: { 1: 'C', 5: 'B', 9: 'A', 10: 'S' } },
    },
    abilityFamily: 'luck',
  },
]

// First-socket shield charms (mirror sword families conceptually).
export const SHIELD_SOCKET_1_CHARMS = [
  {
    id: 'sturdy_charm_shield',
    name: 'Sturdy Charm',
    nameJa: '頑丈の護符',
    kanji: '固',
    slot: 1,
    equipmentType: 'secondary_weapon',
    color: 0x999999,
    description: 'Reinforces the shield for raw defense.',
    scaling: {
      strength: { milestones: { 1: 'C', 6: 'B', 10: 'A' } },
    },
    abilityFamily: 'sturdy',
  },
  {
    id: 'elemental_charm_shield',
    name: 'Warding Charm',
    nameJa: '防魔の護符',
    kanji: '防',
    slot: 1,
    equipmentType: 'secondary_weapon',
    color: 0x66ccff,
    description: 'Channels mana into elemental guard.',
    scaling: {
      strength: { fixed: 'E' },
      mana: { milestones: { 1: 'D', 4: 'C', 8: 'B', 10: 'A' } },
    },
    abilityFamily: 'warding',
  },
  {
    id: 'lucky_charm_shield',
    name: 'Lucky Shield Charm',
    nameJa: '幸運の盾護符',
    kanji: '運',
    slot: 1,
    equipmentType: 'secondary_weapon',
    color: 0xffd700,
    description: 'Dodge and parry by sheer luck.',
    scaling: {
      strength: null,
      luck: { milestones: { 1: 'C', 5: 'B', 9: 'A', 10: 'S' } },
    },
    abilityFamily: 'luck_guard',
  },
]

export const SOCKET_1_CHARMS = [...WEAPON_SOCKET_1_CHARMS, ...SHIELD_SOCKET_1_CHARMS]

export function getSocketCharmById(id) {
  return SOCKET_1_CHARMS.find((c) => c.id === id) || null
}

export function getSocketCharmsForSlot(slot, equipmentType) {
  if (slot !== 1) return []
  const normalized = equipmentType === 'shield' ? 'secondary_weapon' : equipmentType === 'weapon' ? 'primary_weapon' : equipmentType
  const pool = normalized === 'secondary_weapon' ? SHIELD_SOCKET_1_CHARMS : WEAPON_SOCKET_1_CHARMS
  return pool
}

/**
 * Resolve a milestone schedule to a grade for the given equipment level.
 */
export function gradeForSchedule(schedule, level) {
  const thresholds = Object.keys(schedule)
    .map((k) => parseInt(k, 10))
    .sort((a, b) => a - b)
  let grade = schedule[thresholds[0]]
  for (const t of thresholds) {
    if (level >= t) grade = schedule[t]
  }
  return grade
}
