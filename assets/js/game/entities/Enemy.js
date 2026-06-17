import Character from './Character.js'
import { ENEMY_DEFINITIONS, getEnemyDefinition } from '../data/enemies/index.js'

const AI_PHASE_PRIORITY = {
  buff: 0,
  attack: 1,
  recover: 2,
}

function rollStat(min, max) {
  if (min >= max) return min
  return Math.floor(min + Math.random() * (max - min + 1))
}

export default class Enemy extends Character {
  constructor(definitionOrId = 'kasa_obake') {
    const definition = typeof definitionOrId === 'string'
      ? getEnemyDefinition(definitionOrId)
      : definitionOrId

    if (!definition) {
      throw new Error(`Unknown enemy: ${definitionOrId}`)
    }

    super({
      name: definition.name,
      nameJa: definition.nameJa,
      maxHp: rollStat(definition.stats.hp.min, definition.stats.hp.max),
      maxStamina: rollStat(definition.stats.stamina.min, definition.stats.stamina.max),
      strength: rollStat(definition.stats.strength.min, definition.stats.strength.max),
      skill: rollStat(definition.stats.skill.min, definition.stats.skill.max),
      mana: rollStat(definition.stats.mana.min, definition.stats.mana.max),
      luck: rollStat(definition.stats.luck.min, definition.stats.luck.max),
      defense: rollStat(definition.stats.defense.min, definition.stats.defense.max),
      armor: rollStat(definition.stats.armor.min, definition.stats.armor.max),
      equippedSkills: [],
    })

    this.definition = definition
    this.abilities = (definition.abilities || []).map(a => ({ ...a }))
    this.aiProfile = 'aggressive'
    this.nextAttackBonus = 0
    this.usesThisTurn = new Map()
    this.resetAbilityUses()
  }

  resetAbilityUses() {
    this.usesThisTurn.clear()
    for (const ability of this.abilities) {
      this.usesThisTurn.set(ability.id, 0)
    }
  }

  resetForTurn() {
    super.resetForTurn()
    this.resetAbilityUses()
  }

  getAbilityUses(ability) {
    return this.usesThisTurn.get(ability.id) || 0
  }

  incrementAbilityUses(ability) {
    this.usesThisTurn.set(ability.id, this.getAbilityUses(ability) + 1)
  }

  canUseAbility(ability) {
    if (!ability) return false
    if (this.stamina < ability.staminaCost) return false
    const max = ability.maxUsesPerTurn
    if (max != null && this.getAbilityUses(ability) >= max) return false
    return true
  }

  chooseAction(usedBuffThisTurn = false) {
    const usable = this.abilities.filter(a => this.canUseAbility(a))
    if (usable.length === 0) return null

    // Aggressive AI: buff first (only if not used this turn), then attacks,
    // then everything else. Within a phase, pick by aiWeight descending.
    const sorted = usable.slice().sort((a, b) => {
      const phaseA = AI_PHASE_PRIORITY[a.type] ?? 99
      const phaseB = AI_PHASE_PRIORITY[b.type] ?? 99
      if (phaseA !== phaseB) return phaseA - phaseB
      return (b.aiWeight || 0) - (a.aiWeight || 0)
    })

    if (usedBuffThisTurn) {
      return sorted.find(a => a.type !== 'buff') || sorted[0]
    }

    return sorted[0]
  }

  shouldContinueTurn(actionsTaken) {
    if (actionsTaken >= 5) return false
    if (this.stamina <= 0) return false
    return this.abilities.some(a =>
      a.type === 'attack' && this.canUseAbility(a)
    )
  }

  computeActionPlan() {
    let simulatedStamina = this.stamina
    const uses = new Map()
    for (const ability of this.abilities) {
      uses.set(ability.id, 0)
    }

    const canUse = (ability) => {
      if (simulatedStamina < ability.staminaCost) return false
      const max = ability.maxUsesPerTurn
      if (max != null && (uses.get(ability.id) || 0) >= max) return false
      return true
    }

    let buffUsed = false
    const plan = []

    for (let i = 0; i < 5; i++) {
      const usable = this.abilities.filter(a => canUse(a))
      if (usable.length === 0) break

      const sorted = usable.slice().sort((a, b) => {
        const phaseA = AI_PHASE_PRIORITY[a.type] ?? 99
        const phaseB = AI_PHASE_PRIORITY[b.type] ?? 99
        if (phaseA !== phaseB) return phaseA - phaseB
        return (b.aiWeight || 0) - (a.aiWeight || 0)
      })

      const action = buffUsed
        ? sorted.find(a => a.type !== 'buff') || sorted[0]
        : sorted[0]

      if (!action) break
      plan.push(action)
      simulatedStamina -= action.staminaCost
      uses.set(action.id, (uses.get(action.id) || 0) + 1)
      if (action.type === 'buff') buffUsed = true
    }

    return plan
  }

  performAction(ability, target, context = {}) {
    this.useStamina(ability.staminaCost)
    this.incrementAbilityUses(ability)

    switch (ability.type) {
      case 'attack': {
        const base = ability.basePower + this.getStatValue(ability.scalingStat) * ability.scalingMultiplier
        // Consume the queued next-attack bonus, if any.
        this.consumeBuff('next_attack_bonus')
        const total = base + this.nextAttackBonus
        this.nextAttackBonus = 0

        const baseMissChance = (target.luck || 0) / 120
        const readinessMultiplier = 1 + (target.readiness || 0)
        const reactionMultiplier = target.reactionMultiplier || 1
        const missChance = baseMissChance * readinessMultiplier * reactionMultiplier
        if (Math.random() < missChance) {
          return { type: 'attack', damage: 0, isCrit: false, missed: true }
        }

        const isCrit = Math.random() < this.getCritChance()
        let finalDamage = isCrit ? Math.floor(total * 1.5) : Math.floor(total)
        if (context.damageMultiplier != null) {
          finalDamage = Math.floor(finalDamage * context.damageMultiplier)
        }
        const actual = target.takeDamage(finalDamage)
        return { type: 'attack', damage: actual, isCrit, missed: false }
      }
      case 'buff':
        if (ability.buffType === 'next_attack_bonus') {
          this.nextAttackBonus += ability.buffValue || 0
        }
        if (ability.defenseBonus) {
          this.addDefense(ability.defenseBonus)
        }
        this.addBuff({ type: ability.buffType, value: ability.buffValue || 0 })
        return { type: 'buff', buffType: ability.buffType, value: ability.buffValue || 0 }
      case 'recover':
        const recovered = ability.staminaRecover || 0
        this.recoverStamina(recovered)
        return { type: 'recover', stamina: recovered }
      default:
        return { type: 'none' }
    }
  }
}
