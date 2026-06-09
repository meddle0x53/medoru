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
      defense: template.defense || 0,
      armor: template.armor,
      equippedSkills: [...ENEMY_SKILLS],
    })

    this.template = template
    this.aiType = template.ai
    this.nextAttackBonus = 0
  }

  chooseAction(usedBuffThisTurn = false) {
    const usable = this.equippedSkills.filter(s => this.canUseSkill(s))
    if (usable.length === 0) return null

    // Aggressive AI: prefers buffs first (once per turn), then attacks, then recover
    if (this.aiType === 'aggressive') {
      // Buffs have higher priority but only once per turn
      if (!usedBuffThisTurn) {
        const buff = usable.find(s => s.type === 'buff')
        if (buff) return buff
      }
      const attack = usable.find(s => s.type === 'attack')
      if (attack) return attack
      return usable[0]
    }

    return usable[Math.floor(Math.random() * usable.length)]
  }

  shouldContinueTurn(actionsTaken) {
    // Cap at 3 actions max per turn
    if (actionsTaken >= 3) return false
    if (this.stamina <= 0) return false
    // Always continue while we can afford an attack
    const canAttack = this.equippedSkills.some(s => s.type === 'attack' && this.canUseSkill(s))
    return canAttack
  }

  computeActionPlan() {
    // Simulate the turn to predict actions without mutating state
    let simulatedStamina = this.stamina
    let buffUsed = false
    const plan = []

    for (let i = 0; i < 3; i++) {
      const usable = this.equippedSkills.filter(s => simulatedStamina >= s.staminaCost)
      if (usable.length === 0) break

      let action = null
      if (this.aiType === 'aggressive') {
        if (!buffUsed) {
          const buff = usable.find(s => s.type === 'buff')
          if (buff) {
            action = buff
            buffUsed = true
          }
        }
        if (!action) {
          action = usable.find(s => s.type === 'attack')
        }
        if (!action) {
          action = usable[0]
        }
      } else {
        action = usable[Math.floor(Math.random() * usable.length)]
      }

      if (!action) break
      plan.push(action)
      simulatedStamina -= action.staminaCost
    }

    return plan
  }

  performAction(skill, target) {
    this.useStamina(skill.staminaCost)
    switch (skill.type) {
      case 'attack': {
        const base = skill.basePower + this.getStatValue(skill.scalingStat) * skill.scalingMultiplier
        const total = base + this.nextAttackBonus
        this.nextAttackBonus = 0

        // Miss chance based on target luck
        // Base: luck / 120
        // Readiness doubles miss chance (readiness = 1 → multiplier = 2)
        // Reaction challenge can double or halve the readiness effect
        const baseMissChance = (target.luck || 0) / 120
        const readinessMultiplier = 1 + (target.readiness || 0)
        const reactionMultiplier = target.reactionMultiplier || 1
        const missChance = baseMissChance * readinessMultiplier * reactionMultiplier
        if (Math.random() < missChance) {
          return { type: 'attack', damage: 0, isCrit: false, missed: true }
        }

        const isCrit = Math.random() < this.getCritChance()
        const finalDamage = isCrit ? Math.floor(total * 1.5) : Math.floor(total)
        const actual = target.takeDamage(finalDamage)
        return { type: 'attack', damage: actual, isCrit, missed: false }
      }
      case 'buff':
        if (skill.buffType === 'next_attack_bonus') {
          this.nextAttackBonus += skill.buffValue
        }
        if (skill.defenseBonus) {
          this.addDefense(skill.defenseBonus)
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
