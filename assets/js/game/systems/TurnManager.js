import { getEffect, resolveElementVsDefence, ELEMENTS, effectExists, rollDuration } from './EffectRegistry.js'
import { applyAbilityEffects } from './StatusEffectSystem.js'

const GUARD_FOR_ELEMENT = {
  [ELEMENTS.FIRE]: 'fire_guard',
  [ELEMENTS.WATER]: 'water_guard',
  [ELEMENTS.WIND]: 'wind_guard',
  [ELEMENTS.EARTH]: 'earth_guard',
  [ELEMENTS.VOID]: 'void_guard',
}

/**
 * Manages whose turn it is and stamina consumption.
 */
export default class TurnManager {
  constructor(player, enemies, options = {}) {
    this.player = player
    this.enemies = Array.isArray(enemies) ? enemies : [enemies]
    this.currentTurn = 'player'
    this.turnCount = 1
    this.battleOver = false
    this.winner = null
    this.onTurnChange = null
    this.onBattleEnd = null
    this.onCombatLog = options.onCombatLog || null
  }

  getAliveEnemies() {
    return this.enemies.filter(e => e.isAlive())
  }

  getActiveCharacter() {
    return this.currentTurn === 'player' ? this.player : this.enemies[0]
  }

  getInactiveCharacter() {
    return this.currentTurn === 'player' ? this.enemies[0] : this.player
  }

  log(msg) {
    if (this.onCombatLog) this.onCombatLog(msg)
  }

  checkBattleOver(performer) {
    if (this.battleOver) return true

    if (performer === this.player) {
      if (this.getAliveEnemies().length === 0) {
        this.battleOver = true
        this.winner = 'player'
        if (this.onBattleEnd) this.onBattleEnd(this.winner)
        return true
      }
    } else {
      if (!this.player.isAlive()) {
        this.battleOver = true
        this.winner = 'enemy'
        if (this.onBattleEnd) this.onBattleEnd(this.winner)
        return true
      }
    }

    return false
  }

  _decrementDurations(character) {
    const expired = character.decrementEffectDurations()
    for (const event of expired) {
      const effect = getEffect(event.effectId)
      if (effect) {
        this.log(`${character.name || 'The enemy'}'s ${effect.name} wore off.`)
      }
    }
  }

  _tickEffects(character) {
    const ticks = character.tickEffectsAtTurnStart()
    for (const event of ticks) {
      const effect = getEffect(event.effectId)
      if (!effect) continue
      const actual = event.target.takeDamage(event.damage)
      this.log(`${event.target.name || 'The enemy'} takes ${actual} ${effect.name.toLowerCase()} damage.`)
      this.checkBattleOver(event.target)
    }
  }

  _resetSideForTurn(side) {
    if (side === 'player') {
      this.player.resetForTurn()
    } else {
      for (const enemy of this.getAliveEnemies()) {
        enemy.resetForTurn()
      }
    }
  }

  useSkill(skill, performer, target, challengeResult) {
    if (!performer.canUseSkill(skill)) {
      return null
    }

    performer.useStamina(skill.staminaCost)

    // Challenge multiplier: perfect=1.25, success=1.0, fail=0.5
    const multiplier = challengeResult === 'perfect' ? 1.25 : challengeResult === 'success' ? 1.0 : 0.5

    // Resolve any pending infusion for this ability.
    const infusion = performer.getAbilityInfusion?.(skill.id)
    if (infusion) {
      performer.clearAbilityInfusion(skill.id)
    }

    const STATUS_INFUSIONS = ['frost', 'bleed', 'poison']
    const isEffectInfusion = infusion && STATUS_INFUSIONS.includes(infusion.value)
    const isElementInfusion = infusion && !isEffectInfusion && Object.values(ELEMENTS).includes(infusion.value)
    const infusedElement = isElementInfusion ? infusion.value : skill.element
    const potency = infusion?.potency || 1
    const infusedDamageMultiplier = isElementInfusion
      ? Math.min(3.0, 1 + (infusion.mana || 0) / 20 + (potency - 1))
      : 1.0
    const infusedEffectChanceMultiplier = isElementInfusion
      ? Math.min(2.0, 1 + (infusion.mana || 0) / 40 + (potency - 1))
      : 1.0

    let result = null

    switch (skill.type) {
      case 'attack': {
        let total
        if (performer.calculateWeaponDamage) {
          // Player: use weapon damage calculation (Dark Souls scaling)
          // Pass skill for action-specific modifiers (e.g. Heavy Slash)
          total = performer.calculateWeaponDamage(skill) * multiplier
        } else {
          // Enemy: use fixed base power + stat scaling
          const base = skill.basePower + performer.getStatValue(skill.scalingStat) * skill.scalingMultiplier
          const weaponBonus = performer.getWeaponBonus ? performer.getWeaponBonus() : 0
          total = (base + weaponBonus) * multiplier
        }
        const isCrit = Math.random() < performer.getCritChance()
        let rawDamage = isCrit ? Math.floor(total * 1.5) : Math.floor(total)

        // Perfect kanji (0 wrong strokes) bypasses 80% of enemy defense
        let effectiveDefense = target.getDefense()
        if (performer.lastKanjiWrongStrokes === 0) {
          effectiveDefense = Math.floor(effectiveDefense * 0.2)
        }

        // Sword buff bonus damage (0-5 based on kanji quality)
        const swordBuff = performer.buffs.find(b => b.type === 'sword_damage_bonus')
        if (swordBuff && skill.equipmentType === 'weapon') {
          const bonus = performer.lastKanjiWrongStrokes === 0 ? 5 : performer.lastKanjiWrongStrokes <= 2 ? 3 : 1
          rawDamage += bonus
        }

        // Status-effect outgoing damage multiplier (weak / power_up)
        rawDamage = Math.floor(rawDamage * performer.getOutgoingDamageMultiplier())

        // Infused element damage bonus
        rawDamage = Math.floor(rawDamage * infusedDamageMultiplier)

        // Element-vs-defence resolution
        if (infusedElement) {
          const interaction = resolveElementVsDefence(infusedElement, target.getActiveEffectIds())
          if (interaction.removeGuards.length > 0) target.removeEffects(interaction.removeGuards)
          if (interaction.cureEffects.length > 0) target.removeEffects(interaction.cureEffects)
          if (interaction.blocked) {
            this.log(`${target.name || 'The enemy'} nullifies the ${infusedElement} attack!`)
            this.checkBattleOver(performer)
            return { type: 'attack', damage: 0, isCrit, multiplier, blocked: true, infusion: infusion ? { value: infusion.value } : undefined }
          }
        }

        // Dark Souls-like damage formula: atk * atk / (atk + def)
        let finalDamage
        if (effectiveDefense <= 0) {
          finalDamage = rawDamage
        } else {
          finalDamage = Math.floor(rawDamage * rawDamage / (rawDamage + effectiveDefense))
        }

        // Status-effect incoming damage multiplier (frost / vulnerability)
        finalDamage = Math.floor(finalDamage * target.getIncomingDamageMultiplier())

        const actual = target.takeDamage(finalDamage)

        // Berserk lifesteal on sword attacks
        const berserk = performer.buffs.find(b => b.type === 'berserk_lifesteal')
        let lifesteal = 0
        if (berserk && skill.equipmentType === 'weapon' && actual > 0) {
          const ratio = performer.lastKanjiWrongStrokes === 0 ? 0.5 : 0.25
          lifesteal = Math.floor(actual * ratio)
          if (lifesteal > 0) performer.heal(lifesteal)
        }

        result = { type: 'attack', damage: actual, isCrit, multiplier, defenseBypassed: performer.lastKanjiWrongStrokes === 0, lifesteal }
        if (infusion) result.infusion = { value: infusion.value, potency }

        if (infusedElement === 'fire' && actual > 0) {
          const emberEffect = getEffect('ember')
          const emberDuration = emberEffect ? rollDuration(emberEffect) : 3
          performer.applyEffect('ember', { snapshot: actual, duration: emberDuration })
          this.log(`${performer.name || 'The attacker'} suffers ember recoil!`)
        }

        if (infusedElement) {
          const consecutiveHits = target.incrementElementStreak(infusedElement)
          const applied = applyAbilityEffects(skill, performer, target, { initialDamage: actual }, (msg) => this.log(msg), consecutiveHits, infusedEffectChanceMultiplier)
          if (applied.length > 0) target.resetElementStreak(infusedElement)
        }
        if (isEffectInfusion) {
          this.applyInfusedEffect(infusion, target, actual)
        }
        break
      }
      case 'defence': {
        const base = skill.baseBlock + performer.getStatValue(skill.scalingStat) * skill.scalingMultiplier
        const shieldBonus = performer.getShieldBonus ? performer.getShieldBonus() : 0
        const total = Math.floor((base + shieldBonus) * multiplier)
        performer.addBlock(total)
        result = { type: 'defence', block: total, multiplier }
        if (isElementInfusion) {
          const guardId = GUARD_FOR_ELEMENT[infusion.value]
          if (guardId) {
            const guardEffect = getEffect(guardId)
            const duration = guardEffect ? rollDuration(guardEffect) : 2
            performer.applyEffect(guardId, { duration })
            this.log(`${performer.name || 'You'} gain ${guardEffect?.name || guardId}!`)
          }
          result.infusion = { value: infusion.value }
        }
        break
      }
      case 'heal': {
        const total = Math.floor(skill.healAmount * multiplier)
        const actual = performer.heal(total)
        result = { type: 'heal', healed: actual, multiplier }
        break
      }
      case 'buff': {
        if (skill.buffType === 'max_readiness') {
          performer.setReadiness(1)
        } else {
          performer.addBuff({ type: skill.buffType, value: 0 })
        }
        result = { type: 'buff', buffType: skill.buffType, multiplier }
        break
      }
      case 'infuse': {
        // Infuse abilities are resolved by the UI before reaching TurnManager.
        result = { type: 'infuse', multiplier }
        break
      }
      case 'attack_defence': {
        let total
        if (performer.calculateWeaponDamage) {
          total = performer.calculateWeaponDamage(skill) * multiplier
        } else {
          const base = skill.basePower + performer.getStatValue(skill.scalingStat) * skill.scalingMultiplier
          total = base * multiplier
        }
        const isCrit = Math.random() < performer.getCritChance()
        let rawDamage = isCrit ? Math.floor(total * 1.5) : Math.floor(total)
        rawDamage = Math.floor(rawDamage * performer.getOutgoingDamageMultiplier())

        // Infused element damage bonus
        rawDamage = Math.floor(rawDamage * infusedDamageMultiplier)

        let effectiveDefense = target.getDefense()
        if (performer.lastKanjiWrongStrokes === 0) {
          effectiveDefense = Math.floor(effectiveDefense * 0.2)
        }

        if (infusedElement) {
          const interaction = resolveElementVsDefence(infusedElement, target.getActiveEffectIds())
          if (interaction.removeGuards.length > 0) target.removeEffects(interaction.removeGuards)
          if (interaction.cureEffects.length > 0) target.removeEffects(interaction.cureEffects)
          if (interaction.blocked) {
            this.log(`${target.name || 'The enemy'} nullifies the ${infusedElement} attack!`)
            this.checkBattleOver(performer)
            return { type: 'attack_defence', damage: 0, block: 0, isCrit, multiplier, blocked: true, infusion: infusion ? { value: infusion.value } : undefined }
          }
        }

        let finalDamage
        if (effectiveDefense <= 0) {
          finalDamage = rawDamage
        } else {
          finalDamage = Math.floor(rawDamage * rawDamage / (rawDamage + effectiveDefense))
        }
        finalDamage = Math.floor(finalDamage * target.getIncomingDamageMultiplier())
        const actual = target.takeDamage(finalDamage)

        // Add partial block
        const blockBase = (skill.baseBlock || 0) + performer.getStatValue(skill.scalingBlockStat || 'skill') * (skill.scalingBlockMultiplier || 0)
        const blockTotal = Math.floor((blockBase + (performer.getShieldBonus ? performer.getShieldBonus() : 0)) * multiplier)
        if (blockTotal > 0) performer.addBlock(blockTotal)

        result = { type: 'attack_defence', damage: actual, block: blockTotal, isCrit, multiplier, defenseBypassed: performer.lastKanjiWrongStrokes === 0 }
        if (infusion) result.infusion = { value: infusion.value, potency }

        if (infusedElement === 'fire' && actual > 0) {
          const emberEffect = getEffect('ember')
          const emberDuration = emberEffect ? rollDuration(emberEffect) : 3
          performer.applyEffect('ember', { snapshot: actual, duration: emberDuration })
          this.log(`${performer.name || 'The attacker'} suffers ember recoil!`)
        }

        if (infusedElement) {
          const consecutiveHits = target.incrementElementStreak(infusedElement)
          const applied = applyAbilityEffects(skill, performer, target, { initialDamage: actual }, (msg) => this.log(msg), consecutiveHits, infusedEffectChanceMultiplier)
          if (applied.length > 0) target.resetElementStreak(infusedElement)
        }
        if (isEffectInfusion) {
          this.applyInfusedEffect(infusion, target, actual)
        }
        break
      }
      default:
        result = { type: 'none' }
    }

    // Check win/lose
    this.checkBattleOver(performer)

    return result
  }

  applyInfusedEffect(infusion, target, initialDamage) {
    const effect = getEffect(infusion.value)
    if (!effect) return
    const potency = infusion?.potency || 1
    const chance = Math.min(0.95, 0.25 + (infusion.mana || 0) * 0.015 + (potency - 1) * 0.2)
    if (Math.random() >= chance) return
    const options = {}
    if (effect.tick && effect.tick.damage && effect.tick.damage.source === 'snapshot') {
      options.snapshot = initialDamage
    }
    const duration = rollDuration(effect)
    if (duration) options.duration = duration
    const entry = target.applyEffect(infusion.value, options)
    if (entry) {
      this.log(`${target.name || 'The enemy'} is ${effect.name} (${entry.remainingTurns} turns).`)
    }
  }

  endTurn() {
    if (this.battleOver) return

    // 1. Expire effects for the side whose turn just ended.
    if (this.currentTurn === 'player') {
      this._decrementDurations(this.player)
    } else {
      for (const enemy of this.getAliveEnemies()) {
        this._decrementDurations(enemy)
      }
    }

    // 2. Switch turn.
    this.currentTurn = this.currentTurn === 'player' ? 'enemy' : 'player'

    // 3. Tick effects and reset stamina for the side whose turn is starting.
    if (this.currentTurn === 'player') {
      this.turnCount++
      this._tickEffects(this.player)
      if (this.battleOver) return
      this._resetSideForTurn('player')
      // Refill enemy stamina so the intention plan and next enemy turn use full stamina.
      for (const enemy of this.getAliveEnemies()) {
        enemy.resetForTurn()
      }
    } else {
      for (const enemy of this.getAliveEnemies()) {
        this._tickEffects(enemy)
        if (this.battleOver) return
      }
      this._resetSideForTurn('enemy')
    }

    if (this.onTurnChange) this.onTurnChange(this.currentTurn)
  }

  canEndTurn() {
    return this.currentTurn === 'player'
  }
}
