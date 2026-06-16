/**
 * Monster definitions for the rogue-like loop.
 * Eventually this will move to JSON config files.
 */

export const MONSTERS = {
  kasa_obake: {
    id: 'kasa_obake',
    name: 'Kasa-obake',
    nameJa: '傘おばけ',
    level: 1,
    baseGold: 5,
    drops: {
      warrior: [
        { type: 'item', id: 'health_potion', chance: 0.10 },
        { type: 'item', id: 'stone', chance: 0.20 },
        { type: 'charm', id: 'tetsu_charm', chance: 0.02, rarity: 'normal' },
        { type: 'charm', id: 'kouri_charm', chance: 0.005, rarity: 'special' },
      ],
      mage: [],
      archer: [],
    },
  },
  mini_boss: {
    id: 'mini_boss',
    name: 'Elite Kasa-obake',
    nameJa: '傘おばけ頭目',
    level: 3,
    baseGold: 15,
    drops: {
      warrior: [
        { type: 'item', id: 'health_potion', chance: 0.25 },
        { type: 'item', id: 'stone', chance: 0.35 },
        { type: 'charm', id: 'tetsu_charm', chance: 0.05, rarity: 'normal' },
        { type: 'charm', id: 'kouri_charm', chance: 0.02, rarity: 'special' },
      ],
      mage: [],
      archer: [],
    },
  },
  boss: {
    id: 'boss',
    name: 'Umbrella Tyrant',
    nameJa: '傘の暴君',
    level: 5,
    baseGold: 40,
    drops: {
      warrior: [
        { type: 'item', id: 'health_potion', chance: 0.50 },
        { type: 'item', id: 'stone', chance: 0.50 },
        { type: 'charm', id: 'tetsu_charm', chance: 0.12, rarity: 'normal' },
        { type: 'charm', id: 'kouri_charm', chance: 0.06, rarity: 'special' },
      ],
      mage: [],
      archer: [],
    },
  },
}

export function getMonster(id) {
  return MONSTERS[id] || MONSTERS.kasa_obake
}

export function rollDrops(monster, playerClass = 'warrior') {
  const table = (monster.drops && monster.drops[playerClass]) || []
  return table.filter(drop => Math.random() < drop.chance)
}
