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
    // Drop tables per class. Rolls are independent.
    drops: {
      warrior: [
        { type: 'item', id: 'health_potion', chance: 0.10 },
        { type: 'item', id: 'stone', chance: 0.20 },
        { type: 'charm', id: 'tetsu_charm', chance: 0.02, rarity: 'normal' },
        { type: 'charm', id: 'kouri_charm', chance: 0.005, rarity: 'special' },
      ],
      // Placeholders for future classes
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
