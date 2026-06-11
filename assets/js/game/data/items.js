export const ITEMS = [
  { id: 'health_potion', name: 'Health Potion', type: 'heal', baseValue: 10, staminaCost: 1, icon: '🧪', rarity: 'common', description: 'Restores a small amount of HP.' },
  { id: 'large_health_potion', name: 'Large Health Potion', type: 'heal', baseValue: 25, staminaCost: 2, icon: '🧫', rarity: 'uncommon', description: 'Restores a large amount of HP.' },
  { id: 'stone', name: 'Stone', type: 'damage', baseValue: 5, staminaCost: 1, icon: '🪨', rarity: 'common', description: 'Throw a stone at the enemy.', scaling: { strength: 'D' } },
  { id: 'bomb', name: 'Bomb', type: 'damage', baseValue: 15, staminaCost: 2, icon: '💣', rarity: 'uncommon', description: 'Deals heavy damage to the enemy.', scaling: { strength: 'C' } },
  { id: 'smoke_bomb', name: 'Smoke Bomb', type: 'buff', baseValue: 0, staminaCost: 1, icon: '💨', rarity: 'rare', description: 'Grants +1 readiness for the next turn.' },
  { id: 'strength_elixir', name: 'Strength Elixir', type: 'buff', baseValue: 0, staminaCost: 2, icon: '🧃', rarity: 'uncommon', description: 'Increases strength by 3 for this battle.' },
  { id: 'antidote', name: 'Antidote', type: 'heal', baseValue: 0, staminaCost: 1, icon: '💊', rarity: 'common', description: 'Cures poison and restores 5 HP.' },
  { id: 'throwing_knife', name: 'Throwing Knife', type: 'damage', baseValue: 8, staminaCost: 1, icon: '🗡️', rarity: 'common', description: 'A quick ranged attack.', scaling: { skill: 'C' } },
]
