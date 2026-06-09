/**
 * Item definitions for the "Use Item" action.
 */
export const ITEMS = [
  {
    id: 'health_potion',
    name: 'Health Potion',
    icon: '🧪',
    description: 'Restores 10 HP.',
    type: 'heal',
    baseValue: 10,
    staminaCost: 1,
  },
  {
    id: 'stone',
    name: 'Stone',
    icon: '🪨',
    description: 'Deals 5 base damage. Scales with Strength (D).',
    type: 'damage',
    baseValue: 5,
    scaling: { strength: 'D' },
    staminaCost: 1,
  },
]
