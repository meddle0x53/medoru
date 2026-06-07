/**
 * Base Character class for Player and Enemy.
 */
export default class Character {
  constructor(config) {
    this.name = config.name
    this.nameJa = config.nameJa || ''
    this.maxHp = config.maxHp || 100
    this.hp = this.maxHp
    this.maxStamina = config.maxStamina || 10
    this.stamina = this.maxStamina
    this.strength = config.strength || 5
    this.skill = config.skill || 3
    this.mana = config.mana || 0
    this.luck = config.luck || 2
    this.capacity = config.capacity || 3

    this.armor = config.armor || 0
    this.block = 0
    this.buffs = []

    this.equippedSkills = config.equippedSkills || []
    this.weapon = config.weapon || null
    this.armorItem = config.armorItem || null
    this.shield = config.shield || null
  }

  isAlive() {
    return this.hp > 0
  }

  canUseSkill(skill) {
    return this.stamina >= skill.staminaCost
  }

  useStamina(amount) {
    this.stamina = Math.max(0, this.stamina - amount)
  }

  recoverStamina(amount) {
    this.stamina = Math.min(this.maxStamina, this.stamina + amount)
  }

  takeDamage(rawDamage) {
    // Block absorbs damage first
    let damage = rawDamage
    if (this.block > 0) {
      const absorbed = Math.min(this.block, damage)
      this.block -= absorbed
      damage -= absorbed
    }
    // Armor reduces remaining damage
    damage = Math.max(1, damage - this.armor)
    this.hp = Math.max(0, this.hp - damage)
    return damage
  }

  heal(amount) {
    const actualHeal = Math.min(amount, this.maxHp - this.hp)
    this.hp += actualHeal
    return actualHeal
  }

  addBlock(amount) {
    this.block += amount
  }

  addBuff(buff) {
    this.buffs.push(buff)
  }

  consumeBuff(type) {
    const idx = this.buffs.findIndex(b => b.type === type)
    if (idx >= 0) {
      const buff = this.buffs[idx]
      this.buffs.splice(idx, 1)
      return buff
    }
    return null
  }

  resetForTurn() {
    this.stamina = this.maxStamina
    // Block decays at start of new round if we want, but for MVP keep it
  }

  getCritChance() {
    return Math.min(0.25, this.luck * 0.05)
  }

  getStatValue(statName) {
    return this[statName] || 0
  }
}
