/**
 * Socket-specific charms for weapons and shields.
 *
 * Data is loaded from JSON files under ./socketCharms/ so it can be edited
 * without touching JavaScript. The JSON is bundled at build time, keeping the
 * game fully offline-capable.
 *
 * Scaling rule format:
 *   { fixed: 'D' }                  -> always this grade
 *   { milestones: {1:'C',5:'B'} }   -> grade based on equipment level
 *   null                            -> remove this stat from scaling
 *
 * Passive proc format:
 *   {
 *     trigger: 'on_hit' | 'on_defend' | 'on_turn_start' | 'on_battle_start',
 *     chance: 0.15,
 *     effects: [
 *       { type: 'heal', value: 2 },
 *       { type: 'damage', value: 3 },
 *       { type: 'inflict_status', effectId: 'poison' },
 *       { type: 'regen_stamina', value: 1 },
 *       { type: 'thorns', value: 3 }
 *     ]
 *   }
 */

import primaryWeaponData from './socketCharms/primary_weapon.json'
import secondaryWeaponData from './socketCharms/secondary_weapon.json'

export const SOCKET_SLOTS = {
  WEAPON: 4,
  SHIELD: 4,
}

function parseColor(value) {
  if (typeof value === 'number') return value
  if (typeof value === 'string') {
    const hex = value.replace('#', '')
    return parseInt(hex, 16)
  }
  return 0xffffff
}

function normalizeCharm(charm) {
  return {
    ...charm,
    color: parseColor(charm.color),
  }
}

const ALL_WEAPON_CHARMS = (primaryWeaponData.charms || [])
  .map(normalizeCharm)

const ALL_SHIELD_CHARMS = (secondaryWeaponData.charms || [])
  .map(normalizeCharm)

export const ALL_SOCKET_CHARMS = [...ALL_WEAPON_CHARMS, ...ALL_SHIELD_CHARMS]

export const WEAPON_SOCKET_1_CHARMS = ALL_WEAPON_CHARMS.filter((c) => c.slot === 1)
export const SHIELD_SOCKET_1_CHARMS = ALL_SHIELD_CHARMS.filter((c) => c.slot === 1)
export const SOCKET_1_CHARMS = [...WEAPON_SOCKET_1_CHARMS, ...SHIELD_SOCKET_1_CHARMS]

export function getSocketCharmById(id) {
  return ALL_SOCKET_CHARMS.find((c) => c.id === id) || null
}

export function getSocketCharmsForSlot(slot, equipmentType) {
  const normalized = equipmentType === 'shield'
    ? 'secondary_weapon'
    : equipmentType === 'weapon'
      ? 'primary_weapon'
      : equipmentType
  const pool = normalized === 'secondary_weapon' ? ALL_SHIELD_CHARMS : ALL_WEAPON_CHARMS
  return pool.filter((c) => c.slot === slot)
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
