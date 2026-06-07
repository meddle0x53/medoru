import Character from './Character.js'
import { ENEMIES } from '../data/enemies.js'
import { ENEMY_SKILLS } from '../data/skills.js'

export default class Enemy extends Character {
  constructor(enemyKey = 'oni') {
    const template = ENEMIES[enemyKey]
    super({
      name: template.name,
      nameJa: template.nameJa,
      maxHp: template.stats.maxHp,
      maxStamina: template.stats.maxStamina,
      strength: template.stats.strength,
      skill: template.stats.skill,
      luck: template.stats.luck,
      armor: template.armor,
      equippedSkills: [...ENEMY_SKILLS],
    })

    this.template = template
    this.aiType = template.ai
    this.nextAttackBonus = 0
  }

  chooseAction() {
    const usable = this.equippedSkills.filter(s => this.canUseSkill(s))
    if (usable.length === 0) return null

    // Aggressive AI: prefers attacks, then buffs, then recover
    if (this.aiType === 'aggressive') {
      const attack = usable.find(s => s.type === 'attack')
      if (attack) return attack
      const buff = usable.find(s => s.type === 'buff')
      if (buff) return buff
      return usable[0]
    }

    return usable[Math.floor(Math.random() * usable.length)]
  }

  performAction(skill, target) {
    this.useStamina(skill.staminaCost)
    switch (skill.type) {
      case 'attack': {
        const base = skill.basePower + this.getStatValue(skill.scalingStat) * skill.scalingMultiplier
        const total = base + this.nextAttackBonus
        this.nextAttackBonus = 0
        const isCrit = Math.random() < this.getCritChance()
        const finalDamage = isCrit ? Math.floor(total * 1.5) : Math.floor(total)
        const actual = target.takeDamage(finalDamage)
        return { type: 'attack', damage: actual, isCrit }
      }
      case 'buff':
        if (skill.buffType === 'next_attack_bonus') {
          this.nextAttackBonus += skill.buffValue
        }
        this.addBuff({ type: skill.buffType, value: skill.buffValue })
        return { type: 'buff', buffType: skill.buffType, value: skill.buffValue }
      case 'recover':
        const recovered = skill.staminaRecover || 0
        this.recoverStamina(recovered)
        return { type: 'recover', stamina: recovered }
      default:
        return { type: 'none' }
    }
  }
}
