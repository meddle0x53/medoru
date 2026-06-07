import Character from './Character.js'
import { PLAYER_SKILLS } from '../data/skills.js'

export default class Player extends Character {
  constructor(userData = {}) {
    const level = userData.level || 1
    const weaponBonus = 2 // Basic sword

    super({
      name: userData.name || 'Warrior',
      nameJa: '戦士',
      maxHp: 80 + level * 10,
      maxStamina: 8 + Math.floor(level / 3),
      strength: 4 + level,
      skill: 2 + Math.floor(level / 2),
      mana: level,
      luck: 2 + Math.floor(level / 4),
      capacity: 3,
      armor: 1, // Leather armor
      equippedSkills: [...PLAYER_SKILLS],
      weapon: { name: 'Basic Sword', bonus: weaponBonus },
      armorItem: { name: 'Leather Armor', bonus: 1 },
      shield: null,
    })

    this.level = level
    this.potionUsesLeft = 3
    this.userData = userData
  }

  usePotion() {
    if (this.potionUsesLeft > 0) {
      this.potionUsesLeft--
      return true
    }
    return false
  }

  getWeaponBonus() {
    return this.weapon ? this.weapon.bonus : 0
  }

  getShieldBonus() {
    return this.shield ? this.shield.bonus : 0
  }
}
