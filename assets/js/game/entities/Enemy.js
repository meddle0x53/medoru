import Character from './Character.js'
import { ENEMY_DEFINITIONS, getEnemyDefinition } from '../data/enemies/index.js'
import { getEffect, resolveElementVsDefence, rollDuration } from '../systems/EffectRegistry.js'
import { applyAbilityEffects } from '../systems/StatusEffectSystem.js'
import { getInfusionBaseEffect, getElementForInfusion } from '../data/infusionReactions.js'

const AI_PHASE_PRIORITY = {
  buff: 0,
  debuff: 0,
  summon: 0,
  transform: 0,
  attack: 1,
  heal: 2,
  recover: 3,
}

const SETUP_ACTION_TYPES = new Set(['buff', 'debuff', 'summon', 'transform'])

// Weighted-random pick from a list of abilities using aiWeight. Deterministic
// sorted[0] selection would permanently shadow a lower-weight setup ability
// in the same tier (e.g. tanuki transformation vs summon), so the opening
// setup action is rolled instead.
function pickWeightedRandomAction(abilities) {
  if (abilities.length === 1) return abilities[0]
  const total = abilities.reduce((sum, a) => sum + (a.aiWeight || 0), 0)
  if (total <= 0) return abilities[0]
  let roll = Math.random() * total
  for (const a of abilities) {
    roll -= (a.aiWeight || 0)
    if (roll <= 0) return a
  }
  return abilities[abilities.length - 1]
}

const NG_PLUS_ABILITY_NUMERIC_KEYS = new Set([
  'basePower', 'buffValue', 'defenseBonus', 'healValue', 'damage', 'power',
])

function scaleAbilityFields(ability, ngMult) {
  if (ngMult === 1 || !ability) return
  for (const key of Object.keys(ability)) {
    if (NG_PLUS_ABILITY_NUMERIC_KEYS.has(key) && typeof ability[key] === 'number') {
      ability[key] = Math.ceil(ability[key] * ngMult)
    }
  }
}

function rollStat(min, max) {
  if (min >= max) return min
  return Math.floor(min + Math.random() * (max - min + 1))
}

export default class Enemy extends Character {
  constructor(definitionOrId = 'kasa_obake', options = {}) {
    const definition = typeof definitionOrId === 'string'
      ? getEnemyDefinition(definitionOrId)
      : definitionOrId

    if (!definition) {
      throw new Error(`Unknown enemy: ${definitionOrId}`)
    }

    const ngMult = options.ngPlusMultiplier || 1
    const scale = (v) => (ngMult === 1 ? v : Math.ceil(v * ngMult))

    super({
      name: definition.name,
      nameJa: definition.nameJa,
      maxHp: scale(rollStat(definition.stats.hp.min, definition.stats.hp.max)),
      maxStamina: scale(rollStat(definition.stats.stamina.min, definition.stats.stamina.max)),
      strength: scale(rollStat(definition.stats.strength.min, definition.stats.strength.max)),
      skill: scale(rollStat(definition.stats.skill.min, definition.stats.skill.max)),
      mana: scale(rollStat(definition.stats.mana.min, definition.stats.mana.max)),
      luck: scale(rollStat(definition.stats.luck.min, definition.stats.luck.max)),
      defense: scale(rollStat(definition.stats.defense.min, definition.stats.defense.max)),
      armor: scale(rollStat(definition.stats.armor.min, definition.stats.armor.max)),
      equippedSkills: [],
    })

    this.definition = definition
    this.originalId = definition.id
    this.phases = definition.phases || []
    this.phaseIndex = 0
    this.phaseModifiers = {}
    this.phaseAbilityOverrides = {}
    this.currentSprites = { ...(definition.sprites || {}) }
    this.currentName = definition.name
    this.currentNameJa = definition.nameJa
    this.aiProfile = 'aggressive'
    this.nextAttackBonus = 0
    this.usesThisTurn = new Map()
    this.justEnteredPhase = false
    this.enemyTurnCount = 0
    this.ngPlusMultiplier = ngMult

    // Default to the full ability list; phase logic will refine it when phases exist.
    this.abilities = (definition.abilities || []).map(a => {
      const copy = { ...a }
      scaleAbilityFields(copy, ngMult)
      return copy
    })

    this.applyPhase(0, () => {})
    this.resetAbilityUses()
  }

  // ---------- Phases ----------

  getHpRatio() {
    return this.hp / Math.max(1, this.maxHp)
  }

  getPhaseIndexForHp(ratio) {
    if (!this.phases || this.phases.length === 0) return 0
    let index = 0
    for (let i = 0; i < this.phases.length; i++) {
      if (ratio <= this.phases[i].hpThreshold) {
        index = i
      }
    }
    return index
  }

  checkPhaseTransition(log = () => {}) {
    if (!this.phases || this.phases.length === 0) return false
    const ratio = this.getHpRatio()
    const targetIndex = this.getPhaseIndexForHp(ratio)
    if (targetIndex !== this.phaseIndex) {
      return this.applyPhase(targetIndex, log)
    }
    return false
  }

  applyPhase(index, log = () => {}) {
    if (!this.phases || index < 0 || index >= this.phases.length) {
      this.phaseIndex = 0
      return false
    }
    const changed = this.phaseIndex !== index
    this.phaseIndex = index
    const phase = this.phases[index]

    // Merge sprites, falling back to the previous phase's sprites.
    if (phase.sprites) {
      this.currentSprites = { ...this.currentSprites, ...phase.sprites }
    }

    // Rebuild ability list from the original definition, applying phase filters and overrides.
    this.recalcAbilitiesForPhase(phase)

    // Store modifiers and per-ability overrides for combat resolution.
    this.phaseModifiers = { ...(phase.modifiers || {}) }
    this.phaseAbilityOverrides = { ...(phase.abilityOverrides || {}) }

    if (changed) {
      this.justEnteredPhase = true
      if (phase.announce) log(phase.announce)
      if (phase.modifiers?.gainStaticCharge) {
        this.applyComboState('static_charge', 'phase_transition')
        log(`${this.name || 'The enemy'} builds a static charge!`)
      }
    }
    return changed
  }

  recalcAbilitiesForPhase(phase) {
    const all = (this.definition.abilities || [])
    const filter = phase.abilityFilter || {}

    this.abilities = all
      .map(a => ({ ...a }))
      .filter(a => {
        const minPhase = a.minPhaseIndex
        if (typeof minPhase === 'number' && this.phaseIndex < minPhase) return false
        const maxPhase = a.maxPhaseIndex
        if (typeof maxPhase === 'number' && this.phaseIndex > maxPhase) return false
        if (filter.only && filter.only.length > 0 && !filter.only.includes(a.id)) return false
        if (filter.exclude && filter.exclude.includes(a.id)) return false
        return true
      })

    // Apply phase-specific ability overrides (e.g. double basic-attack damage).
    for (const ability of this.abilities) {
      const overrides = this.phaseAbilityOverrides[ability.id]
      if (overrides) {
        Object.assign(ability, overrides)
      }
      scaleAbilityFields(ability, this.ngPlusMultiplier)
    }
  }

  getCurrentSprites() {
    return this.currentSprites
  }

  getAbilityContext(ability) {
    const context = {
      valueOverrides: {},
      chanceOverrides: {},
      effectChanceMultiplier: 1,
    }
    if (!ability) return context

    const overrides = this.phaseAbilityOverrides[ability.id]
    if (overrides) {
      if (overrides.damageMultiplier != null) {
        context.valueOverrides.damageMultiplier = overrides.damageMultiplier
      }
      if (overrides.effectChanceMultiplier != null) {
        context.effectChanceMultiplier = overrides.effectChanceMultiplier
      }
      for (const [key, value] of Object.entries(overrides)) {
        if (key.endsWith('Chance') && typeof value === 'number') {
          context.chanceOverrides[key.replace(/Chance$/, '')] = value
        }
      }
    }
    return context
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
    if (ability.allowedEnemyTurns && !ability.allowedEnemyTurns.includes(this.enemyTurnCount)) return false
    return true
  }

  chooseAction(usedBuffThisTurn = false) {
    const usable = this.abilities.filter(a => this.canUseAbility(a))
    if (usable.length === 0) return null

    // On the first action after a phase change, prefer an ability that just became available.
    if (this.justEnteredPhase && !usedBuffThisTurn) {
      const newAbility = usable.find(a => a.minPhaseIndex === this.phaseIndex)
      if (newAbility) {
        this.justEnteredPhase = false
        return newAbility
      }
      this.justEnteredPhase = false
    }

    const sorted = usable.slice().sort((a, b) => {
      const phaseA = AI_PHASE_PRIORITY[a.type] ?? 99
      const phaseB = AI_PHASE_PRIORITY[b.type] ?? 99
      if (phaseA !== phaseB) return phaseA - phaseB
      return (b.aiWeight || 0) - (a.aiWeight || 0)
    })

    if (usedBuffThisTurn) {
      return sorted.find(a => !SETUP_ACTION_TYPES.has(a.type)) || sorted[0]
    }

    if (SETUP_ACTION_TYPES.has(sorted[0].type)) {
      const setupTier = []
      for (const a of sorted) {
        if (!SETUP_ACTION_TYPES.has(a.type)) break
        setupTier.push(a)
      }
      return pickWeightedRandomAction(setupTier)
    }

    return sorted[0]
  }

  shouldContinueTurn(actionsTaken) {
    if (actionsTaken >= 5) return false
    if (this.stamina <= 0) return false
    return this.abilities.some(a => this.canUseAbility(a))
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

      let action
      if (buffUsed) {
        action = sorted.find(a => !SETUP_ACTION_TYPES.has(a.type)) || sorted[0]
      } else if (SETUP_ACTION_TYPES.has(sorted[0].type)) {
        const setupTier = []
        for (const a of sorted) {
          if (!SETUP_ACTION_TYPES.has(a.type)) break
          setupTier.push(a)
        }
        action = pickWeightedRandomAction(setupTier)
      } else {
        action = sorted[0]
      }

      if (!action) break
      plan.push(action)
      simulatedStamina -= action.staminaCost
      uses.set(action.id, (uses.get(action.id) || 0) + 1)
      if (SETUP_ACTION_TYPES.has(action.type)) buffUsed = true
    }

    return plan
  }

  tryFreeAction(target, log = () => {}) {
    const chance = this.phaseModifiers?.freeActionChance ?? 0
    const actionId = this.phaseModifiers?.freeActionId
    if (!chance || !actionId) return null
    if (Math.random() >= chance) return null
    const ability = this.abilities.find(a => a.id === actionId)
    if (!ability || !this.canUseAbility(ability)) return null
    log(`${this.name || 'The enemy'} discharges ${ability.name}!`)
    return this.performAction(ability, target, { isFreeAction: true }, log)
  }

  resolveDamageMultiplier(ability, context) {
    let multiplier = ability.damageMultiplier || 1
    if (context.valueOverrides && context.valueOverrides.damageMultiplier != null) {
      multiplier = context.valueOverrides.damageMultiplier
    }
    if (context.damageMultiplier != null) {
      multiplier *= context.damageMultiplier
    }
    // Phase-wide basic-attack damage bonus.
    if (ability.isBasicAttack && this.phaseModifiers.basicAttackDamageMultiplier != null) {
      multiplier *= this.phaseModifiers.basicAttackDamageMultiplier
    }
    return multiplier
  }

  performAction(ability, target, context = {}, log = () => {}) {
    this.useStamina(ability.staminaCost)
    this.incrementAbilityUses(ability)

    switch (ability.type) {
      case 'attack': {
        const declaredElement = ability.element
        const effectiveElement = getElementForInfusion(declaredElement) || declaredElement

        const base = ability.basePower + (this.getStatValue(ability.scalingStat) || 0) * (ability.scalingMultiplier || 0)
        this.consumeBuff('next_attack_bonus')
        const total = base + this.nextAttackBonus
        this.nextAttackBonus = 0

        const baseMissChance = target.getMissChanceFor(this)
        const eyeOfHeaven = this.getEffectEntry('eye_of_heaven')
        const readinessMultiplier = 1 + (target.readiness || 0)
        const reactionMultiplier = target.reactionMultiplier || 1
        const dashMiss = target.turnMissChance || 0
        let missChance = Math.min(1, baseMissChance * readinessMultiplier * reactionMultiplier + dashMiss)
        if (eyeOfHeaven) missChance = 0
        if (Math.random() < missChance) {
          return { type: 'attack', damage: 0, isCrit: false, missed: true }
        }

        const isCrit = Math.random() < (this.getCritChance() + (eyeOfHeaven ? 0.5 : 0))
        let finalDamage = isCrit ? Math.floor(total * 1.5) : Math.floor(total)
        finalDamage = Math.floor(finalDamage * this.getOutgoingDamageMultiplier())

        if (effectiveElement) {
          const interaction = resolveElementVsDefence(effectiveElement, target.getActiveEffectIds())
          if (interaction.removeGuards.length > 0) target.removeEffects(interaction.removeGuards)
          if (interaction.cureEffects.length > 0) target.removeEffects(interaction.cureEffects)
          if (interaction.blocked) {
            return { type: 'attack', damage: 0, isCrit, missed: false, blocked: true }
          }
        }

        finalDamage = Math.floor(finalDamage * target.getIncomingDamageMultiplier())
        const damageMultiplier = this.resolveDamageMultiplier(ability, context)
        if (damageMultiplier !== 1) {
          finalDamage = Math.floor(finalDamage * damageMultiplier)
        }

        // Static Charge: Raijū phase-2 passive boosts the next lightning ability.
        if (ability.isLightning && this.hasComboState('static_charge')) {
          finalDamage = Math.floor(finalDamage * 1.25)
          this.consumeComboState('static_charge')
          log('Static Charge discharges!')
        }

        // Consume a target effect for a damage payoff (e.g. Heaven Splitter on Electrified).
        if (ability.consumesEffect && target.consumeEffectIfPresent(ability.consumesEffect.effectId)) {
          finalDamage = Math.floor(finalDamage * ability.consumesEffect.damageMultiplier)
          if (ability.consumesEffect.log) log(ability.consumesEffect.log)
        }

        const actual = target.takeDamage(finalDamage)

        if (effectiveElement === 'fire' && actual > 0) {
          const emberEffect = getEffect('ember')
          const emberDuration = emberEffect ? rollDuration(emberEffect) : 3
          this.applyEffect('ember', { snapshot: actual, duration: emberDuration })
          log(`${this.name || 'The enemy'} suffers ember recoil!`)
        }

        if (ability.effects && ability.effects.length > 0) {
          const consecutiveHits = effectiveElement ? target.incrementElementStreak(effectiveElement) : 1
          const applied = applyAbilityEffects(ability, this, target, { initialDamage: actual, chanceOverrides: context.chanceOverrides }, log, consecutiveHits, context.effectChanceMultiplier || 1)
          if (applied.length > 0 && effectiveElement) target.resetElementStreak(effectiveElement)
        }

        if (declaredElement) {
          const baseEffect = getInfusionBaseEffect(declaredElement)
          if (baseEffect) {
            const effects = baseEffect.effects || [{ effectId: baseEffect.effectId, chance: baseEffect.chance }]
            for (const fx of effects) {
              const effect = getEffect(fx.effectId)
              if (!effect) continue
              if (Math.random() >= (fx.chance || 0.5)) continue
              const options = {}
              if (effect.tick && effect.tick.damage && effect.tick.damage.source === 'snapshot') {
                options.snapshot = actual
              }
              const duration = rollDuration(effect)
              if (duration) options.duration = duration
              const entry = target.applyEffect(fx.effectId, options)
              if (entry) log(`${target.name || 'You'} is ${effect.name} (${entry.remainingTurns} turns).`)
            }
          }
        }
        return { type: 'attack', damage: actual, isCrit, missed: false }
      }
      case 'debuff':
      case 'buff': {
        if (ability.type === 'debuff') {
          const declaredElement = ability.element
          const effectiveElement = getElementForInfusion(declaredElement) || declaredElement

          const base = ability.basePower + (this.getStatValue(ability.scalingStat) || 0) * (ability.scalingMultiplier || 0)
          this.consumeBuff('next_attack_bonus')
          const total = base + this.nextAttackBonus
          this.nextAttackBonus = 0

          const baseMissChance = target.getMissChanceFor(this)
          const eyeOfHeaven = this.getEffectEntry('eye_of_heaven')
          const readinessMultiplier = 1 + (target.readiness || 0)
          const reactionMultiplier = target.reactionMultiplier || 1
          let missChance = baseMissChance * readinessMultiplier * reactionMultiplier
          if (eyeOfHeaven) missChance = 0
          if (Math.random() < missChance) {
            return { type: 'debuff', damage: 0, isCrit: false, missed: true }
          }

          const isCrit = Math.random() < (this.getCritChance() + (eyeOfHeaven ? 0.5 : 0))
          let finalDamage = isCrit ? Math.floor(total * 1.5) : Math.floor(total)
          finalDamage = Math.floor(finalDamage * this.getOutgoingDamageMultiplier())

          if (effectiveElement) {
            const interaction = resolveElementVsDefence(effectiveElement, target.getActiveEffectIds())
            if (interaction.removeGuards.length > 0) target.removeEffects(interaction.removeGuards)
            if (interaction.cureEffects.length > 0) target.removeEffects(interaction.cureEffects)
            if (interaction.blocked) {
              return { type: 'debuff', damage: 0, isCrit, missed: false, blocked: true }
            }
          }

          finalDamage = Math.floor(finalDamage * target.getIncomingDamageMultiplier())
          const damageMultiplier = this.resolveDamageMultiplier(ability, context)
          if (damageMultiplier !== 1) {
            finalDamage = Math.floor(finalDamage * damageMultiplier)
          }

          if (ability.isLightning && this.hasComboState('static_charge')) {
            finalDamage = Math.floor(finalDamage * 1.25)
            this.consumeComboState('static_charge')
            log('Static Charge discharges!')
          }

          if (ability.consumesEffect && target.consumeEffectIfPresent(ability.consumesEffect.effectId)) {
            finalDamage = Math.floor(finalDamage * ability.consumesEffect.damageMultiplier)
            if (ability.consumesEffect.log) log(ability.consumesEffect.log)
          }

          const actual = target.takeDamage(finalDamage)

          if (ability.effects && ability.effects.length > 0) {
            const consecutiveHits = effectiveElement ? target.incrementElementStreak(effectiveElement) : 1
            const applied = applyAbilityEffects(ability, this, target, { initialDamage: actual, chanceOverrides: context.chanceOverrides }, log, consecutiveHits, context.effectChanceMultiplier || 1)
            if (applied.length > 0 && effectiveElement) target.resetElementStreak(effectiveElement)
          }

          return { type: 'debuff', damage: actual, isCrit, missed: false }
        }

        if (ability.buffType === 'next_attack_bonus') {
          this.nextAttackBonus += ability.buffValue || 0
        }
        if (ability.defenseBonus) {
          this.addDefense(ability.defenseBonus)
        }

        if (ability.buffType === 'evasion') {
          const evasionValue = (context.valueOverrides && context.valueOverrides.evasion != null)
            ? context.valueOverrides.evasion
            : (ability.buffValue || 0)
          this.addBuff({ type: 'evasion', value: evasionValue })
          log(`${this.name || 'The enemy'}'s evasion rises!`)
          return { type: 'buff', buffType: 'evasion', value: evasionValue }
        }

        this.addBuff({ type: ability.buffType, value: ability.buffValue || 0 })
        if (ability.effects && ability.effects.length > 0) {
          applyAbilityEffects(ability, this, target, { chanceOverrides: context.chanceOverrides }, log, 1, context.effectChanceMultiplier || 1)
        }
        return { type: 'buff', buffType: ability.buffType, value: ability.buffValue || 0 }
      }
      case 'recover': {
        const recovered = ability.staminaRecover || 0
        this.recoverStamina(recovered)
        return { type: 'recover', stamina: recovered }
      }
      case 'heal': {
        let healed = 0
        if (ability.healPercent) {
          healed = Math.floor(this.maxHp * ability.healPercent)
        } else if (ability.healAmount) {
          healed = ability.healAmount
        }
        healed = this.heal(healed)

        let staminaRecovered = 0
        if (ability.staminaRecover) {
          staminaRecovered = this.recoverStamina(ability.staminaRecover)
        }

        const cleansed = []
        if (ability.cleanseEffects && ability.cleanseEffects.length > 0) {
          for (const effectId of ability.cleanseEffects) {
            if (this.removeEffect(effectId)) cleansed.push(effectId)
          }
        }

        let buff = null
        if (ability.buffEffect) {
          const fx = ability.buffEffect
          const duration = fx.duration ? rollDuration({ duration: fx.duration }) : rollDuration(getEffect(fx.effectId)) || 2
          const entry = this.applyEffect(fx.effectId, { duration })
          if (entry) {
            buff = { effectId: fx.effectId, remainingTurns: entry.remainingTurns }
          }
        }

        return { type: 'heal', healed, staminaRecovered, cleansed, buff }
      }
      case 'summon': {
        const baseChance = ability.summonChance != null ? ability.summonChance : 1
        const bonus = this.phaseModifiers.summonChanceBonus || 0
        const chance = Math.min(1, baseChance + bonus)
        const failed = Math.random() >= chance
        return {
          type: 'summon',
          failed,
          summonIds: ability.summonIds || [],
          summonCount: ability.summonCount || 1,
          summonHpMultiplier: ability.summonHpMultiplier != null ? ability.summonHpMultiplier : 0.35,
        }
      }
      case 'transform': {
        const pool = ability.transformPoolIds || ability.transformPool || []
        let transformDef = null
        if (pool.length > 0) {
          const id = pool[Math.floor(Math.random() * pool.length)]
          transformDef = typeof id === 'string' ? getEnemyDefinition(id) : id
        }
        return { type: 'transform', transformDef, keepHpRatio: ability.keepHpRatio !== false }
      }
      default:
        return { type: 'none' }
    }
  }
}
