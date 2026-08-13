// Charms are small luminous kanji that float above the hero's head.
// They do NOT change the hero's actual sprite — only a colored glow/kanji overlay.
//
// Slot rules:
//   - Hero has 4 base charm slots.
//   - Weapons gain charm slots based on upgrade level (e.g. floor(level / 3), max 3).
//   - Shields use the same slot formula.
//   - Some charms are "sword/shield charms" and can ONLY be socketed into a weapon or shield slot.
//
// For now this file is the static charm database. Eventually it can move to the
// server and be loaded as game data.

export const CHARM_TYPES = {
  HERO: 'hero',     // can be equipped in hero charm slots
  WEAPON: 'weapon', // can only be equipped in weapon charm slots
  SHIELD: 'shield', // can only be equipped in shield charm slots
}

export const CHARMS = [
  {
    id: 'chikara_charm',
    name: 'Charm of Power',
    nameJa: '力の護符',
    kanji: '力',
    color: 0xff4444, // red glow
    type: CHARM_TYPES.HERO,
    rarity: 'common',
    effect: { stat: 'strength', value: 2 },
  },
  {
    id: 'tate_charm',
    name: 'Charm of the Shield',
    nameJa: '盾の護符',
    kanji: '盾',
    color: 0x3498db, // blue glow
    type: CHARM_TYPES.HERO,
    rarity: 'common',
    effect: { stat: 'defense', value: 3 },
  },
  {
    id: 'hayai_charm',
    name: 'Charm of Swiftness',
    nameJa: '速の護符',
    kanji: '速',
    color: 0x44ff44, // green glow
    type: CHARM_TYPES.HERO,
    rarity: 'uncommon',
    effect: { stat: 'skill', value: 2 },
  },
  {
    id: 'un_charm',
    name: 'Charm of Fortune',
    nameJa: '運の護符',
    kanji: '運',
    color: 0xffd700, // gold glow
    type: CHARM_TYPES.HERO,
    rarity: 'rare',
    effect: { stat: 'luck', value: 3 },
  },
  {
    id: 'tanuki_fur_charm',
    name: 'Tanuki Fur Charm',
    nameJa: '狸毛の護符',
    kanji: '狸',
    color: 0x8B5A2B, // tanuki-brown glow
    type: CHARM_TYPES.HERO,
    rarity: 'rare',
    firstDefeatReward: true,
    effect: { stat: 'maxHpMultiplier', value: 0.10 },
  },
  {
    id: 'kitsune_tail_charm',
    name: 'Kitsune Tail Charm',
    nameJa: '狐尾の護符',
    kanji: '尾',
    color: 0xe0e0ff, // pale foxfire glow
    type: CHARM_TYPES.HERO,
    rarity: 'rare',
    firstDefeatReward: true,
    effect: { stat: 'staminaRegen', value: 1 },
  },
  {
    id: 'hi_charm',
    name: 'Charm of Fire',
    nameJa: '火の護符',
    kanji: '火',
    color: 0xff6600, // orange glow
    type: CHARM_TYPES.HERO,
    rarity: 'rare',
    effect: { stat: 'damageBonus', value: 0.08 }, // +8% damage
  },
  {
    id: 'mizu_charm',
    name: 'Charm of Water',
    nameJa: '水の護符',
    kanji: '水',
    color: 0x00ccff, // cyan glow
    type: CHARM_TYPES.HERO,
    rarity: 'uncommon',
    effect: { stat: 'staminaRegen', value: 1 },
  },
  {
    id: 'small_void_charm',
    name: 'Small Void Charm',
    nameJa: '小空虚の護符',
    kanji: '空',
    color: 0x8e44ad, // muted purple glow
    type: CHARM_TYPES.HERO,
    rarity: 'common',
    effect: { stats: ['skill', 'strength', 'mana', 'luck'], value: 1 },
  },
  {
    id: 'ancient_void_charm',
    name: 'Ancient Void Charm',
    nameJa: '古代空虚の護符',
    kanji: '虚',
    color: 0x5b2c6f, // deep purple glow
    type: CHARM_TYPES.HERO,
    rarity: 'rare',
    effect: { stats: ['skill', 'strength', 'mana', 'luck'], value: 2 },
    unlockCondition: 'bossReached',
  },
  {
    id: 'abyss_charm',
    name: 'Abyss Charm',
    nameJa: '渕の護符',
    kanji: '渕',
    color: 0x1a1a2e, // dark abyss glow
    type: CHARM_TYPES.HERO,
    rarity: 'epic',
    effect: { stats: ['skill', 'strength', 'mana', 'luck', 'capacity', 'vitality', 'stamina'], value: 3 },
    unlockCondition: 'bossDefeated',
  },
  {
    id: 'wind_charm',
    name: 'Wind Charm',
    nameJa: '風の護符',
    kanji: '風',
    color: 0xccffcc, // pale green glow
    type: CHARM_TYPES.HERO,
    rarity: 'rare',
    effect: { stats: ['skill', 'mana'], value: 2 },
    unlockCondition: 'column7Reached',
  },
  {
    id: 'earth_charm',
    name: 'Earth Charm',
    nameJa: '地の護符',
    kanji: '地',
    color: 0x8b4513, // brown glow
    type: CHARM_TYPES.HERO,
    rarity: 'common',
    effect: { stats: ['strength', 'stamina', 'vitality'], value: 1 },
  },
  {
    id: 'charm_of_the_sword',
    name: 'Charm of the Sword',
    nameJa: '剣の護符',
    kanji: '剣',
    color: 0xff2222, // red glow
    type: CHARM_TYPES.HERO,
    rarity: 'uncommon',
    effect: { stat: 'strength', value: 5 },
    unlockCondition: 'column5Reached',
  },
  {
    id: 'backpack_charm',
    name: 'Backpack Charm',
    nameJa: '袋の護符',
    kanji: '袋',
    color: 0xd4a017, // tan/gold glow
    type: CHARM_TYPES.HERO,
    rarity: 'epic',
    effect: { stat: 'capacity', value: 7 },
    unlockCondition: 'bossDefeatedTwice',
  },
  {
    id: 'magi_charm',
    name: 'Magi Charm',
    nameJa: '魔の護符',
    kanji: '魔',
    color: 0x9b59b6, // purple glow
    type: CHARM_TYPES.HERO,
    rarity: 'common',
    effect: { stat: 'mana', value: 2 },
  },
  {
    id: 'ken_no_mai_charm',
    name: 'Sword-Dance Charm',
    nameJa: '剣舞の護符',
    kanji: '剣',
    color: 0xff2222, // deep red glow
    type: CHARM_TYPES.WEAPON,
    rarity: 'rare',
    effect: { stat: 'critChance', value: 0.05 }, // +5% crit
  },
  {
    id: 'yaiba_charm',
    name: 'Blade Charm',
    nameJa: '刃の護符',
    kanji: '刃',
    color: 0xcc3333,
    type: CHARM_TYPES.WEAPON,
    rarity: 'uncommon',
    effect: { stat: 'damageBonus', value: 0.10 },
  },
  {
    id: 'kiba_charm',
    name: 'Fang Charm',
    nameJa: '牙の護符',
    kanji: '牙',
    color: 0xff5555,
    type: CHARM_TYPES.WEAPON,
    rarity: 'common',
    effect: { stat: 'strength', value: 1 },
  },
  {
    id: 'kouri_charm',
    name: 'Ice Charm',
    nameJa: '氷の護符',
    kanji: '氷',
    color: 0x66ccff,
    type: CHARM_TYPES.SHIELD,
    rarity: 'uncommon',
    effect: { stat: 'defense', value: 4 },
  },
  {
    id: 'tetsu_charm',
    name: 'Iron Charm',
    nameJa: '鉄の護符',
    kanji: '鉄',
    color: 0x999999,
    type: CHARM_TYPES.SHIELD,
    rarity: 'common',
    effect: { stat: 'defense', value: 2 },
  },
  {
    id: 'kaze_charm',
    name: 'Wind Charm',
    nameJa: '風の護符',
    kanji: '風',
    color: 0xccffcc,
    type: CHARM_TYPES.SHIELD,
    rarity: 'rare',
    effect: { stat: 'skill', value: 2 },
  },
]

export function getCharmById(id) {
  return CHARMS.find((c) => c.id === id) || null
}

export function getCharmsByType(type) {
  return CHARMS.filter((c) => c.type === type)
}

// How many charm slots equipment gets based on its upgrade level.
// Matches the weapon/shield socket unlock schedule:
// Level 0 → 0 slots
// Level +1 → 1 slot
// Level +3 → 2 slots
// Level +6 → 3 slots
// Level +9 → 4 slots
export function getWeaponCharmSlots(weaponLevel) {
  const level = weaponLevel || 0
  if (level >= 9) return 4
  if (level >= 6) return 3
  if (level >= 3) return 2
  if (level >= 1) return 1
  return 0
}

export function getShieldCharmSlots(shieldLevel) {
  const level = shieldLevel || 0
  if (level >= 9) return 4
  if (level >= 6) return 3
  if (level >= 3) return 2
  if (level >= 1) return 1
  return 0
}

// Validate an equip attempt.
// Returns { ok: true } or { ok: false, reason: string }.
export function canEquipCharm(charm, heroSlotsUsed, weaponSlotsUsed, shieldSlotsUsed, weaponLevel, shieldLevel) {
  if (!charm) return { ok: false, reason: 'Charm not found.' }

  if (charm.type === CHARM_TYPES.HERO) {
    if (heroSlotsUsed >= 4) {
      return { ok: false, reason: 'All hero charm slots are full.' }
    }
    return { ok: true }
  }

  if (charm.type === CHARM_TYPES.WEAPON) {
    const maxSlots = getWeaponCharmSlots(weaponLevel)
    if (maxSlots === 0) {
      return { ok: false, reason: 'Weapon is not upgraded enough for charm slots.' }
    }
    if (weaponSlotsUsed >= maxSlots) {
      return { ok: false, reason: 'All weapon charm slots are full.' }
    }
    return { ok: true }
  }

  if (charm.type === CHARM_TYPES.SHIELD) {
    const maxSlots = getShieldCharmSlots(shieldLevel)
    if (maxSlots === 0) {
      return { ok: false, reason: 'Shield is not upgraded enough for charm slots.' }
    }
    if (shieldSlotsUsed >= maxSlots) {
      return { ok: false, reason: 'All shield charm slots are full.' }
    }
    return { ok: true }
  }

  return { ok: false, reason: 'Unknown charm type.' }
}
