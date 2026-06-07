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
        const base = skill.basePower + performer.getStatValue(skill.scalingStat) * skill.scalingMultiplier
        const weaponBonus = performer.getWeaponBonus ? performer.getWeaponBonus() : 0
        const total = (base + weaponBonus) * multiplier
        const isCrit = Math.random() < performer.getCritChance()
        const finalDamage = isCrit ? Math.floor(total * 1.5) : Math.floor(total)
        const actual = target.takeDamage(finalDamage)
        result = { type: 'attack', damage: actual, isCrit, multiplier }
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
        if (performer.usePotion && !performer.usePotion()) {
          result = { type: 'heal', healed: 0, error: 'No potions left' }
        } else {
          const total = Math.floor(skill.healAmount * multiplier)
          const actual = performer.heal(total)
          result = { type: 'heal', healed: actual, multiplier }
        }
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
