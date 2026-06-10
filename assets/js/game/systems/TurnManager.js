/**
 * Manages whose turn it is and stamina consumption.
 */
export default class TurnManager {
  constructor(player, enemy) {
    this.player = player
    this.enemy = enemy
    this.currentTurn = 'player'
    this.turnCount = 1
    this.battleOver = false
    this.winner = null
    this.onTurnChange = null
    this.onBattleEnd = null
  }

  getActiveCharacter() {
    return this.currentTurn === 'player' ? this.player : this.enemy
  }

  getInactiveCharacter() {
    return this.currentTurn === 'player' ? this.enemy : this.player
  }

  useSkill(skill, performer, target, challengeResult) {
    if (!performer.canUseSkill(skill)) {
      return null
    }

    performer.useStamina(skill.staminaCost)

    // Challenge multiplier: perfect=1.25, success=1.0, fail=0.5
    const multiplier = challengeResult === 'perfect' ? 1.25 : challengeResult === 'success' ? 1.0 : 0.5

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
        const rawDamage = isCrit ? Math.floor(total * 1.5) : Math.floor(total)

        // Perfect kanji (0 wrong strokes) bypasses 80% of enemy defense
        let effectiveDefense = target.getDefense()
        if (performer.lastKanjiWrongStrokes === 0) {
          effectiveDefense = Math.floor(effectiveDefense * 0.2)
        }

        // Dark Souls-like damage formula: atk * atk / (atk + def)
        let finalDamage
        if (effectiveDefense <= 0) {
          finalDamage = rawDamage
        } else {
          finalDamage = Math.floor(rawDamage * rawDamage / (rawDamage + effectiveDefense))
        }

        const actual = target.takeDamage(finalDamage)
        result = { type: 'attack', damage: actual, isCrit, multiplier, defenseBypassed: performer.lastKanjiWrongStrokes === 0 }
        break
      }
      case 'defence': {
        const base = skill.baseBlock + performer.getStatValue(skill.scalingStat) * skill.scalingMultiplier
        const shieldBonus = performer.getShieldBonus ? performer.getShieldBonus() : 0
        const total = Math.floor((base + shieldBonus) * multiplier)
        performer.addBlock(total)
        result = { type: 'defence', block: total, multiplier }
        break
      }
      case 'heal': {
        const total = Math.floor(skill.healAmount * multiplier)
        const actual = performer.heal(total)
        result = { type: 'heal', healed: actual, multiplier }
        break
      }
      default:
        result = { type: 'none' }
    }

    // Check win/lose
    if (!target.isAlive()) {
      this.battleOver = true
      this.winner = performer === this.player ? 'player' : 'enemy'
      if (this.onBattleEnd) this.onBattleEnd(this.winner)
    }

    return result
  }

  endTurn() {
    if (this.battleOver) return

    this.currentTurn = this.currentTurn === 'player' ? 'enemy' : 'player'

    if (this.currentTurn === 'player') {
      this.turnCount++
      this.player.resetForTurn()
      this.enemy.resetForTurn()
    }

    if (this.onTurnChange) this.onTurnChange(this.currentTurn)
  }

  canEndTurn() {
    return this.currentTurn === 'player'
  }
}
