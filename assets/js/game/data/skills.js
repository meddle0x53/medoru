/**
 * Fixed skill definitions for MVP.
 * Each skill has a kanji challenge associated with it.
 */
export const PLAYER_SKILLS = [
  {
    id: 'forward_slash',
    name: 'Forward Slash',
    nameJa: '斬撃',
    description: 'A swift sword strike. Costs 3 stamina.',
    staminaCost: 3,
    type: 'attack',
    basePower: 8,
    scalingStat: 'strength',
    scalingMultiplier: 1.0,
    // Challenge: user must type the reading of this kanji
    challenge: {
      kanji: '刀',
      readings: ['かたな', 'とう', 'katana', 'tou'],
      prompt: 'Type the reading of 刀',
      timeLimit: 5000, // ms
    },
  },
  {
    id: 'setup_defence',
    name: 'Setup Defence',
    nameJa: '防御',
    description: 'Raise your guard. Costs 2 stamina.',
    staminaCost: 2,
    type: 'defence',
    baseBlock: 5,
    scalingStat: 'skill',
    scalingMultiplier: 0.8,
    challenge: {
      kanji: '盾',
      readings: ['たて', 'tate', 'shield'],
      prompt: 'Type the reading of 盾',
      timeLimit: 5000,
    },
  },
  {
    id: 'heal_potion',
    name: 'Heal Potion',
    nameJa: '治療薬',
    description: 'Drink a healing potion. Costs 1 stamina. 3 uses per battle.',
    staminaCost: 1,
    type: 'heal',
    healAmount: 15,
    maxUses: 3,
    challenge: {
      kanji: '薬',
      readings: ['くすり', 'kusuri', 'medicine'],
      prompt: 'Type the reading of 薬',
      timeLimit: 4000,
    },
  },
]

export const ENEMY_SKILLS = [
  {
    id: 'claw_strike',
    name: 'Claw Strike',
    staminaCost: 3,
    type: 'attack',
    basePower: 10,
    scalingStat: 'strength',
    scalingMultiplier: 1.0,
  },
  {
    id: 'intimidate',
    name: 'Intimidate',
    staminaCost: 2,
    type: 'buff',
    buffType: 'next_attack_bonus',
    buffValue: 4,
    defenseBonus: 10,
  },
  {
    id: 'wait',
    name: 'Wait',
    staminaCost: 1,
    type: 'recover',
    staminaRecover: 3,
  },
]
