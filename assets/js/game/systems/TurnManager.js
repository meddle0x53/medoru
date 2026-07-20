import { getEffect, resolveElementVsDefence, rollDuration } from './EffectRegistry.js'
import { applyAbilityEffects } from './StatusEffectSystem.js'
import { getInfusionBaseEffect, getElementForInfusion, getGuardForInfusion } from '../data/infusionReactions.js'
import { getEffectiveScaling, SCALING_MULTIPLIERS, getStatFactor } from '../entities/Player.js'

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

  _getSkillValue(performer) {
    const raw = performer.getStatValue ? performer.getStatValue('skill') : (performer.skill || 0)
    return Math.min(Math.max(0, raw), 99)
  }

  _calculateSwordBuffBonus(performer, skill) {
    const swordBuff = performer.buffs.find(b => b.type === 'sword_damage_bonus')
    if (!swordBuff || skill.equipmentType !== 'weapon') return 0
    const wrongStrokes = typeof swordBuff.wrongStrokes === 'number' ? swordBuff.wrongStrokes : performer.lastKanjiWrongStrokes
    if (wrongStrokes >= 4) return 0

    const skillValue = this._getSkillValue(performer)
    const first = Math.min(skillValue, 40)
    const second = Math.max(0, Math.min(skillValue, 60) - 40)
    const third = Math.max(0, Math.min(skillValue, 80) - 60)
    const fourth = Math.max(0, skillValue - 80)

    if (wrongStrokes === 0) {
      return Math.floor(first + second / 2 + third / 3 + fourth / 4)
    }
    // 1-3 wrong strokes
    return Math.floor(first / 2 + second / 3 + third / 4 + fourth / 5)
  }

  _getStatValue(performer, stat) {
    const raw = performer.getStatValue ? performer.getStatValue(stat) : (performer[stat] || 0)
    return Math.min(Math.max(0, raw), 99)
  }

  _parseQualityBracket(key) {
    const match = String(key).match(/^(\d+)(?:-(\d+|\+))?$/)
    if (!match) return null
    const min = parseInt(match[1], 10)
    const max = match[2] === '+' ? Infinity : parseInt(match[2], 10)
    return { min, max: isNaN(max) ? min : max }
  }

  _resolveBuffDuration(config, performer, wrongStrokes = 99) {
    const duration = config?.duration
    if (!duration) return null

    const baseTurns = duration.baseTurns ?? 1
    const bonusTurns = duration.bonusTurns ?? 0
    const modifiers = duration.qualityModifiers || { default: 1 }

    let modifier = modifiers.default ?? 1
    for (const [key, value] of Object.entries(modifiers)) {
      if (key === 'default') continue
      const bracket = this._parseQualityBracket(key)
      if (bracket && wrongStrokes >= bracket.min && wrongStrokes <= bracket.max) {
        modifier = value
        break
      }
    }

    if (baseTurns <= 0 || modifier === 0) return 0

    const statName = duration.scalesWith || 'luck'
    const statValue = this._getStatValue(performer, statName)

    let baseChance = 0
    const table = duration.chanceTable || []
    for (const threshold of table) {
      if (threshold.max !== undefined && statValue > threshold.max) continue
      if (threshold.min !== undefined && statValue < threshold.min) continue
      baseChance = threshold.chance ?? 0
      break
    }

    const chance = baseChance * modifier
    return Math.random() < chance ? baseTurns + bonusTurns : baseTurns
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

    const isEffectInfusion = infusion && !getElementForInfusion(infusion.value) && getEffect(infusion.value)
    const isElementInfusion = infusion && !isEffectInfusion
    const infusedElement = isElementInfusion ? getElementForInfusion(infusion.value) : skill.element
    const potency = infusion?.potency || 1
    const baseEffect = isElementInfusion ? getInfusionBaseEffect(infusion.value) : null
    const comboDamageMultiplier = baseEffect?.damageMultiplier || 0
    const infusedDamageMultiplier = isElementInfusion
      ? Math.min(3.0, 1 + (infusion.mana || 0) / 20 + (potency - 1) + comboDamageMultiplier)
      : 1.0
    const elementalEffectChanceMultiplier = isElementInfusion
      ? Math.min(2.0, 1 + (infusion.mana || 0) / 40 + (potency - 1))
      : infusedElement
        ? Math.min(2.0, 1 + (performer.mana || 0) / 40)
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

        // Sword buff bonus damage (scales with skill and sharpen quality)
        const swordBuffBonus = this._calculateSwordBuffBonus(performer, skill)
        if (swordBuffBonus > 0) {
          rawDamage += swordBuffBonus
          this.log(`Sharpened blade adds ${swordBuffBonus} damage!`)
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

        const missChance = target.getMissChanceFor(performer)
        if (Math.random() < missChance) {
          this.log(`${target.name || 'The enemy'} evades the attack!`)
          return { type: 'attack', damage: 0, isCrit, multiplier, missed: true, blocked: false, defenseBypassed: performer.lastKanjiWrongStrokes === 0, lifesteal: 0, infusion: infusion ? { value: infusion.value, potency } : undefined }
        }

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
          this.applyEmberRecoil(performer, actual, challengeResult)
        }

        if (infusedElement) {
          const consecutiveHits = target.incrementElementStreak(infusedElement)
          const effectCtx = { initialDamage: actual }
          if (performer.pendingEffectChanceOverrides) {
            effectCtx.chanceOverrides = performer.pendingEffectChanceOverrides
          }
          const applied = applyAbilityEffects(skill, performer, target, effectCtx, (msg) => this.log(msg), consecutiveHits, elementalEffectChanceMultiplier)
          delete performer.pendingEffectChanceOverrides
          if (applied.length > 0) target.resetElementStreak(infusedElement)
        }
        if (isEffectInfusion) {
          this.applyInfusedEffect(infusion, target, actual)
        }
        if (baseEffect) {
          this.applyInfusedBaseEffects(baseEffect, target, actual, potency, elementalEffectChanceMultiplier)
        }
        if (infusion?.extraEffects?.length) {
          for (const extra of infusion.extraEffects) {
            this.applyInfusedEffect({ value: extra, mana: infusion.mana, potency: infusion.potency || 1 }, target, actual)
          }
        }
        if (!infusion && infusedElement) {
          const baseEffect = getInfusionBaseEffect(infusedElement)
          if (baseEffect) this.applyInfusedBaseEffects(baseEffect, target, actual, 1, elementalEffectChanceMultiplier)
        }
        break
      }
      case 'defence': {
        let base = skill.baseBlock || 0
        let scaling = 0
        // Shield-based defence skills scale with the shield's effective scaling schedule
        // (charms can change which stats the shield scales with).
        if (skill.equipmentType === 'shield' && performer.shield) {
          const shield = performer.shield
          const shieldBase = shield.baseDefense || 0
          for (const [stat, grade] of Object.entries(getEffectiveScaling(shield))) {
            const gradeMultiplier = SCALING_MULTIPLIERS[grade] || 0
            const statValue = performer.getStatValue(stat)
            const factor = getStatFactor(statValue)
            scaling += shieldBase * gradeMultiplier * factor
          }
        } else if (skill.scalingStat && skill.scalingMultiplier) {
          scaling = performer.getStatValue(skill.scalingStat) * skill.scalingMultiplier
        }
        const shieldBonus = performer.getShieldBonus ? performer.getShieldBonus() : 0
        const total = Math.floor((base + scaling + shieldBonus) * multiplier)
        performer.addBlock(total)
        result = { type: 'defence', block: total, multiplier }
        if (isElementInfusion) {
          const guardId = getGuardForInfusion(infusion.value)
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
          const wrongStrokes = typeof performer.lastKanjiWrongStrokes === 'number'
            ? performer.lastKanjiWrongStrokes
            : 99
          const remainingTurns = this._resolveBuffDuration(skill.config, performer, wrongStrokes)
          if (remainingTurns === null) {
            // No duration configured: legacy infinite buff.
            performer.addBuff({ type: skill.buffType, value: 0, wrongStrokes })
          } else if (remainingTurns > 0) {
            performer.addBuff({
              type: skill.buffType,
              value: 0,
              wrongStrokes,
              remainingTurns,
              appliedThisTurn: true,
            })
          }
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

        // Sword buff bonus damage (scales with skill and sharpen quality)
        const swordBuffBonus = this._calculateSwordBuffBonus(performer, skill)
        if (swordBuffBonus > 0) {
          rawDamage += swordBuffBonus
          this.log(`Sharpened blade adds ${swordBuffBonus} damage!`)
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

        const missChance = target.getMissChanceFor(performer)
        if (Math.random() < missChance) {
          this.log(`${target.name || 'The enemy'} evades the attack!`)
          return { type: 'attack_defence', damage: 0, block: 0, isCrit, multiplier, missed: true, blocked: false, defenseBypassed: performer.lastKanjiWrongStrokes === 0, infusion: infusion ? { value: infusion.value, potency } : undefined }
        }

        const actual = target.takeDamage(finalDamage)

        // Add partial block
        let blockTotal = 0
        if (skill.config?.setupDefenceBlock) {
          blockTotal = Math.floor(performer.computeSetupDefenceAmount(skill, multiplier))
        } else {
          const blockBase = (skill.baseBlock || 0) + performer.getStatValue(skill.scalingBlockStat || 'skill') * (skill.scalingBlockMultiplier || 0)
          blockTotal = Math.floor((blockBase + (performer.getShieldBonus ? performer.getShieldBonus() : 0)) * multiplier)
        }
        if (blockTotal > 0) performer.addBlock(blockTotal)

        result = { type: 'attack_defence', damage: actual, block: blockTotal, isCrit, multiplier, defenseBypassed: performer.lastKanjiWrongStrokes === 0 }
        if (infusion) result.infusion = { value: infusion.value, potency }

        if (infusedElement === 'fire' && actual > 0) {
          this.applyEmberRecoil(performer, actual, challengeResult)
        }

        if (infusedElement) {
          const consecutiveHits = target.incrementElementStreak(infusedElement)
          const applied = applyAbilityEffects(skill, performer, target, { initialDamage: actual }, (msg) => this.log(msg), consecutiveHits, elementalEffectChanceMultiplier)
          if (applied.length > 0) target.resetElementStreak(infusedElement)
        }
        if (isEffectInfusion) {
          this.applyInfusedEffect(infusion, target, actual)
        }
        if (baseEffect) {
          this.applyInfusedBaseEffects(baseEffect, target, actual, potency, elementalEffectChanceMultiplier)
        }
        if (infusion?.extraEffects?.length) {
          for (const extra of infusion.extraEffects) {
            this.applyInfusedEffect({ value: extra, mana: infusion.mana, potency: infusion.potency || 1 }, target, actual)
          }
        }
        if (!infusion && infusedElement) {
          const baseEffect = getInfusionBaseEffect(infusedElement)
          if (baseEffect) this.applyInfusedBaseEffects(baseEffect, target, actual, 1, elementalEffectChanceMultiplier)
        }
        break
      }
      case 'focus': {
        // Readiness is applied during the kanji challenge phase in BattleScene.
        result = { type: 'focus' }
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

  applyInfusedBaseEffects(baseEffect, target, initialDamage, potency = 1, chanceMultiplier = 1) {
    const effects = baseEffect.effects || [{ effectId: baseEffect.effectId, chance: baseEffect.chance }]
    for (const fx of effects) {
      const effect = getEffect(fx.effectId)
      if (!effect) continue
      const chance = Math.min(1, (fx.chance || 0.5) * Math.min(1.5, potency) * (chanceMultiplier || 1))
      if (Math.random() >= chance) continue
      const options = {}
      if (effect.tick && effect.tick.damage && effect.tick.damage.source === 'snapshot') {
        options.snapshot = initialDamage
      }
      const duration = rollDuration(effect)
      if (duration) options.duration = duration
      const entry = target.applyEffect(fx.effectId, options)
      if (entry) {
        this.log(`${target.name || 'The enemy'} is ${effect.name} (${entry.remainingTurns} turns).`)
      }
    }
  }

  applyEmberRecoil(performer, initialDamage, challengeResult) {
    const mana = performer.mana || 0
    let chance = 0.6 - mana * 0.03
    if (challengeResult === 'perfect') chance -= 0.3
    else if (challengeResult === 'success') chance -= 0.1
    chance = Math.max(0.05, chance)

    if (Math.random() >= chance) {
      this.log(`${performer.name || 'The attacker'} channels the fire safely.`)
      return
    }

    const emberEffect = getEffect('ember')
    const duration = emberEffect ? rollDuration(emberEffect) : 3
    performer.applyEffect('ember', { snapshot: initialDamage, duration })
    this.log(`${performer.name || 'The attacker'} suffers ember recoil!`)
  }

  endTurn() {
    if (this.battleOver) return

    // 1. Expire effects for the side whose turn just ended.
    if (this.currentTurn === 'player') {
      this._decrementDurations(this.player)
      const expiredBuffs = this.player.decrementBuffDurations()
      if (expiredBuffs.some(b => b.type === 'sword_damage_bonus')) {
        this.log(`Sharpened blade wears off.`)
      }
    } else {
      for (const enemy of this.getAliveEnemies()) {
        this._decrementDurations(enemy)
        enemy.decrementBuffDurations()
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
