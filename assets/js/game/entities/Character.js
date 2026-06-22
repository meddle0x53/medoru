import { getEffect, rollDuration, rollMadnessOutcome, EFFECT_CATEGORIES } from '../systems/EffectRegistry.js'

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
    this.baseDefense = config.defense || 0
    this.tempDefense = 0
    this.block = 0
    this.buffs = []

    // Structured status effects (burn, poison, weak, guards, etc.)
    this.activeEffects = []

    // Ability infusions applied this battle: abilityId -> { value, mana }
    this.infusedAbilities = new Map()

    // Consecutive same-element hits received (for progressive effect chances)
    this.elementStreaks = {}

    // Optional combat log callback for status-effect messages
    this.onCombatLog = null

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

  takeDamage(rawAttack) {
    // Dark Souls-like defense formula: atk * atk / (atk + def)
    // Use getTotalDefense if available (Player with shield), otherwise getDefense
    const defense = this.getTotalDefense ? this.getTotalDefense() : this.getDefense()
    let damage
    if (defense <= 0) {
      damage = rawAttack
    } else {
      damage = rawAttack * rawAttack / (rawAttack + defense)
    }
    damage = Math.floor(damage)

    // Block absorbs damage first
    if (this.block > 0) {
      const absorbed = Math.min(this.block, damage)
      this.block -= absorbed
      damage -= absorbed
    }
    // Armor reduces remaining damage
    damage = Math.max(1, damage - this.armor)

    // Trigger effects that respond to incoming damage (e.g. bleed, blunt)
    const { bleedBonus, bluntMultiplier } = this.onIncomingDamage(rawAttack)
    damage = Math.floor(damage * bluntMultiplier) + bleedBonus

    this.hp = Math.max(0, this.hp - damage)
    return damage
  }

  log(msg) {
    if (this.onCombatLog) this.onCombatLog(msg)
  }

  onIncomingDamage(rawAttack) {
    if (rawAttack <= 0) return { bleedBonus: 0, bluntMultiplier: 1 }

    let bleedBonus = 0
    let bluntMultiplier = 1

    const bleed = this.activeEffects.find(e => e.effectId === 'bleed')
    if (bleed) {
      const effect = getEffect('bleed')
      const multiplier = effect?.trigger?.damage?.multiplier ?? 0.10
      const bonus = Math.floor(this.maxHp * multiplier)
      if (bonus > 0) {
        this.removeEffect('bleed')
        this.log(`${this.name || 'The enemy'}'s Bleed triggers for ${bonus} bonus damage!`)
        bleedBonus = bonus
      }
    }

    const blunt = this.activeEffects.find(e => e.effectId === 'blunt')
    if (blunt) {
      const effect = getEffect('blunt')
      const multiplier = effect?.incomingDamageMultiplier ?? 2.0
      this.removeEffect('blunt')
      this.log(`${this.name || 'The enemy'}'s Blunt doubles the damage!`)
      bluntMultiplier = multiplier
    }

    return { bleedBonus, bluntMultiplier }
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

  // ---------- Ability Infusions ----------

  setAbilityInfusion(abilityId, value, mana, potency = 1, extraEffects = []) {
    this.infusedAbilities.set(abilityId, { value, mana, potency, extraEffects: extraEffects || [] })
  }

  getAbilityInfusion(abilityId) {
    return this.infusedAbilities.get(abilityId) || null
  }

  clearAbilityInfusion(abilityId) {
    this.infusedAbilities.delete(abilityId)
  }

  clearAllAbilityInfusions() {
    this.infusedAbilities.clear()
  }

  // ---------- Status Effects ----------

  applyEffect(effectId, options = {}) {
    const effect = getEffect(effectId)
    if (!effect) return null

    const duration = options.duration ?? rollDuration(effect)
    const existingIdx = this.activeEffects.findIndex(e => e.effectId === effectId)

    if (existingIdx >= 0) {
      const existing = this.activeEffects[existingIdx]
      const rule = effect.stackRule
      if (rule === 'refresh') {
        existing.remainingTurns = Math.max(existing.remainingTurns, duration)
        existing.snapshot = options.snapshot ?? existing.snapshot
        return existing
      }
      // 'replace' or default: overwrite
      this.activeEffects.splice(existingIdx, 1)
    }

    const entry = {
      effectId,
      sourceElement: options.sourceElement || null,
      remainingTurns: duration,
      snapshot: options.snapshot ?? null,
    }

    if (effect.tick && effect.tick.damage && effect.tick.damage.spread && entry.snapshot) {
      const total = Math.floor(entry.snapshot * (effect.tick.damage.multiplier ?? 1))
      entry.spreadPerTurn = Math.max(1, Math.floor(total / Math.max(1, duration)))
    }

    this.activeEffects.push(entry)

    if (effect.onApply === 'rollMadnessOutcome') {
      const outcome = rollMadnessOutcome()
      if (outcome.type === 'effect') {
        const applied = this.applyEffect(outcome.effectId, { duration: rollDuration(getEffect(outcome.effectId)) })
        if (applied) {
          this.log(`${this.name || 'The enemy'} is driven mad by ${getEffect(outcome.effectId)?.name || outcome.effectId}!`)
        }
      } else if (outcome.type === 'stamina_halved') {
        this.applyEffect('stamina_crash', { duration: 1 })
        this.log(`${this.name || 'The enemy'}'s stamina crashes from madness!`)
      }
    }

    return entry
  }

  removeEffect(effectId) {
    const before = this.activeEffects.length
    this.activeEffects = this.activeEffects.filter(e => e.effectId !== effectId)
    return this.activeEffects.length < before
  }

  removeEffects(effectIds) {
    if (!effectIds || effectIds.length === 0) return false
    const before = this.activeEffects.length
    this.activeEffects = this.activeEffects.filter(e => !effectIds.includes(e.effectId))
    return this.activeEffects.length < before
  }

  clearActiveEffects() {
    this.activeEffects = []
  }

  getActiveEffectIds() {
    return this.activeEffects.map(e => e.effectId)
  }

  getEffectEntry(effectId) {
    return this.activeEffects.find(e => e.effectId === effectId) || null
  }

  tickEffectsAtTurnStart() {
    const events = []
    for (const entry of this.activeEffects) {
      const effect = getEffect(entry.effectId)
      if (!effect || !effect.tick || !effect.tick.damage) continue

      const multiplier = effect.tick.damage.multiplier ?? 1
      let damage = 0
      if (effect.tick.damage.spread) {
        damage = entry.spreadPerTurn || Math.max(1, Math.floor((entry.snapshot || 0) * multiplier / Math.max(1, entry.remainingTurns)))
      } else if (effect.tick.damage.source === 'snapshot') {
        damage = Math.floor((entry.snapshot || 0) * multiplier)
      } else if (effect.tick.damage.source === 'targetMaxHp') {
        damage = Math.floor(this.maxHp * multiplier)
      }
      if (damage > 0) {
        events.push({ effectId: entry.effectId, target: this, damage })
      }
    }
    return events
  }

  decrementEffectDurations() {
    const expired = []
    for (const entry of this.activeEffects) {
      const effect = getEffect(entry.effectId)
      // One-off effects persist until triggered; they do not expire by time.
      if (effect?.category === EFFECT_CATEGORIES.ONE_OFF) continue
      entry.remainingTurns -= 1
      if (entry.remainingTurns <= 0) {
        expired.push({ effectId: entry.effectId })
      }
    }
    this.activeEffects = this.activeEffects.filter(e => {
      const effect = getEffect(e.effectId)
      if (effect?.category === EFFECT_CATEGORIES.ONE_OFF) return true
      return e.remainingTurns > 0
    })
    return expired
  }

  getOutgoingDamageMultiplier() {
    let multiplier = 1
    for (const entry of this.activeEffects) {
      const effect = getEffect(entry.effectId)
      if (effect && effect.outgoingDamageMultiplier != null) {
        multiplier *= effect.outgoingDamageMultiplier
      }
    }
    return multiplier
  }

  getIncomingDamageMultiplier() {
    let multiplier = 1
    for (const entry of this.activeEffects) {
      const effect = getEffect(entry.effectId)
      // One-off effects like blunt are handled in takeDamage() and consumed there.
      if (effect?.category === EFFECT_CATEGORIES.ONE_OFF) continue
      if (effect && effect.incomingDamageMultiplier != null) {
        multiplier *= effect.incomingDamageMultiplier
      }
    }
    return multiplier
  }

  getStaminaMultiplier() {
    let multiplier = 1
    for (const entry of this.activeEffects) {
      const effect = getEffect(entry.effectId)
      if (effect && effect.staminaMultiplier != null) {
        multiplier *= effect.staminaMultiplier
      }
    }
    return multiplier
  }

  // ---------- Element Streak Tracking ----------

  getElementStreak(element) {
    if (!element) return 1
    return this.elementStreaks[element] || 1
  }

  incrementElementStreak(element) {
    if (!element) return 1
    // Reset streaks for all other elements
    for (const key of Object.keys(this.elementStreaks)) {
      if (key !== element) {
        this.elementStreaks[key] = 0
      }
    }
    this.elementStreaks[element] = (this.elementStreaks[element] || 0) + 1
    return this.elementStreaks[element]
  }

  resetElementStreak(element) {
    if (!element) return
    this.elementStreaks[element] = 0
  }

  resetForTurn() {
    this.stamina = Math.floor(this.maxStamina * this.getStaminaMultiplier())
    this.parrySetup = false
    this.parryKanjiQuality = null
    this.tempDefense = 0
    // Block decays at start of new round if we want, but for MVP keep it
  }

  getDefense() {
    return this.baseDefense + this.tempDefense
  }

  addDefense(amount) {
    this.tempDefense += amount
  }

  getCritChance() {
    let base = Math.min(0.25, this.luck * 0.05)
    if (typeof this.getCharmEffects === 'function') {
      const charmEffects = this.getCharmEffects()
      if (charmEffects && charmEffects.critChance) {
        base += charmEffects.critChance
      }
    }
    return Math.min(0.50, base)
  }

  getStatValue(statName) {
    let base = this[statName] || 0
    // If the concrete class has charm effects (Player), add them in.
    if (typeof this.getCharmEffects === 'function') {
      const charmEffects = this.getCharmEffects()
      if (charmEffects && charmEffects[statName]) {
        base += charmEffects[statName]
      }
    }
    return base
  }
}
