/**
 * Enemy definitions for MVP.
 */
export const ENEMIES = {
  oni: {
    id: 'oni',
    name: 'Kasa-obake',
    nameJa: '傘おばけ',
    description: 'A possessed umbrella spirit.',
    color: 0xe74c3c,
    size: 80,
    stats: {
      maxHp: 80,
      maxStamina: 8,
      strength: 4,
      skill: 2,
      luck: 1,
    },
    defense: 5,
    armor: 2,
    ai: 'aggressive',
  },
}

export const DEFAULT_KANJI_POOL = [
  { character: '刀', readings: ['かたな', 'とう', 'katana', 'tou'] },
  { character: '盾', readings: ['たて', 'tate', 'shield'] },
  { character: '薬', readings: ['くすり', 'kusuri', 'medicine'] },
  { character: '火', readings: ['ひ', 'か', 'hi', 'ka', 'fire'] },
  { character: '水', readings: ['みず', 'すい', 'mizu', 'sui', 'water'] },
  { character: '木', readings: ['き', 'もく', 'ki', 'moku', 'tree'] },
  { character: '金', readings: ['かね', 'きん', 'kane', 'kin', 'gold'] },
  { character: '土', readings: ['つち', 'ど', 'tsuchi', 'do', 'earth'] },
  { character: '人', readings: ['ひと', 'じん', 'nin', 'hito', 'person'] },
  { character: '力', readings: ['ちから', 'りょく', 'chikara', 'ryoku', 'power'] },
]
