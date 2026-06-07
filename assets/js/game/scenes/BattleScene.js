import { GAME_CONFIG, COLORS, FONTS } from '../config.js'
import Player from '../entities/Player.js'
import Enemy from '../entities/Enemy.js'
import TurnManager from '../systems/TurnManager.js'
import ChallengeSystem from '../systems/ChallengeSystem.js'
import { getWindowGameData, sendRunResult } from '../api.js'

export default class BattleScene extends Phaser.Scene {
  constructor() {
    super({ key: 'BattleScene' })
  }

  create() {
    const userData = getWindowGameData()
    this.player = new Player(userData)
    this.enemy = new Enemy('oni')
    this.turnManager = new TurnManager(this.player, this.enemy)
    this.challengeSystem = new ChallengeSystem(userData?.kanjiList)

    this.turnManager.onTurnChange = (turn) => this.onTurnChange(turn)
    this.turnManager.onBattleEnd = (winner) => this.onBattleEnd(winner)

    this.challengeActive = false
    this.selectedSkill = null
    this.typedInput = ''
    this.currentChallenge = null
    this.particles = []

    this.createBackground()
    this.createCharacters()
    this.createUI()
    this.createChallengeOverlay()
    this.createCombatLog()

    this.input.keyboard.on('keydown', this.handleKeyInput, this)

    this.addCombatLog('Battle start! Defeat the Lesser Oni!')
    this.onTurnChange('player')
  }

  update(time, delta) {
    if (this.challengeActive && this.currentChallenge) {
      const elapsed = Date.now() - this.currentChallenge.startTime
      const pct = Math.max(0, 1 - elapsed / this.currentChallenge.timeLimit)
      this.challengeTimerBar.setScale(pct, 1)
      if (elapsed >= this.currentChallenge.timeLimit) {
        this.submitChallenge()
      }
    }

    // Floating particles
    this.particles = this.particles.filter(p => {
      p.y -= p.speed * (delta / 1000)
      p.life -= delta
      p.alpha = Math.max(0, p.life / 500)
      p.text.setAlpha(p.alpha)
      p.text.setY(p.y)
      if (p.life <= 0) {
        p.text.destroy()
        return false
      }
      return true
    })
  }

  // ---------- Graphics creation ----------

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, GAME_CONFIG.backgroundColor)
    // Ground line
    this.add.line(0, 0, 0, 400, GAME_CONFIG.width, 400, 0x0f3460, 0.5).setOrigin(0, 0)
  }

  createCharacters() {
    // Player — tall rectangle (64×128), feet on ground line at y=400
    this.playerSprite = this.add.rectangle(200, 336, 64, 128, COLORS.player)
    this.add.text(200, 280, this.player.name, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.add.text(200, 296, '戦士', { ...FONTS.kanji, fontSize: '14px' }).setOrigin(0.5)

    // Enemy — tall rectangle (80×112), feet on ground line at y=400
    this.enemySprite = this.add.rectangle(760, 344, 80, 112, COLORS.enemy)
    this.add.text(760, 288, this.enemy.name, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.add.text(760, 304, this.enemy.nameJa, { ...FONTS.kanji, fontSize: '14px' }).setOrigin(0.5)
  }

  createUI() {
    // Turn indicator
    this.turnText = this.add.text(GAME_CONFIG.width / 2, 30, 'YOUR TURN', {
      ...FONTS.title,
      fontSize: '18px',
    }).setOrigin(0.5)

    // Player bars (left top)
    this.createBar(120, 70, 'playerHp', COLORS.hp, this.player.hp, this.player.maxHp)
    this.createBar(120, 90, 'playerStamina', COLORS.stamina, this.player.stamina, this.player.maxStamina)
    this.playerHpText = this.add.text(120, 70, `${this.player.hp}/${this.player.maxHp}`, { ...FONTS.default, fontSize: '12px' }).setOrigin(0.5)
    this.playerStaminaText = this.add.text(120, 90, `${this.player.stamina}/${this.player.maxStamina}`, { ...FONTS.default, fontSize: '12px' }).setOrigin(0.5)

    // Enemy bars (right top)
    this.createBar(GAME_CONFIG.width - 120, 70, 'enemyHp', COLORS.hp, this.enemy.hp, this.enemy.maxHp)
    this.createBar(GAME_CONFIG.width - 120, 90, 'enemyStamina', COLORS.stamina, this.enemy.stamina, this.enemy.maxStamina)
    this.enemyHpText = this.add.text(GAME_CONFIG.width - 120, 70, `${this.enemy.hp}/${this.enemy.maxHp}`, { ...FONTS.default, fontSize: '12px' }).setOrigin(0.5)
    this.enemyStaminaText = this.add.text(GAME_CONFIG.width - 120, 90, `${this.enemy.stamina}/${this.enemy.maxStamina}`, { ...FONTS.default, fontSize: '12px' }).setOrigin(0.5)

    // Skill buttons
    this.skillButtons = []
    this.player.equippedSkills.forEach((skill, i) => {
      const btn = this.createButton(300 + i * 160, 490, skill.name, () => this.onSkillClick(skill))
      this.skillButtons.push({ btn, skill })
    })

    // End turn button
    this.endTurnBtn = this.createButton(GAME_CONFIG.width / 2, 530, 'End Turn', () => this.onEndTurn())

    // Block indicators
    this.playerBlockText = this.add.text(200, 260, '', { ...FONTS.default, fontSize: '12px', color: '#3498db' }).setOrigin(0.5)
    this.enemyBlockText = this.add.text(760, 268, '', { ...FONTS.default, fontSize: '12px', color: '#3498db' }).setOrigin(0.5)
  }

  createBar(x, y, key, color, value, max) {
    const w = 120
    const h = 14
    this.add.rectangle(x, y, w, h, COLORS.hpBg).setOrigin(0.5)
    const bar = this.add.rectangle(x - w / 2, y, (value / max) * w, h, color).setOrigin(0, 0.5)
    this[key + 'Bar'] = bar
    this[key + 'Max'] = max
    this[key + 'Width'] = w
    this[key + 'X'] = x - w / 2
  }

  createButton(x, y, label, onClick) {
    const w = 140
    const h = 36
    const bg = this.add.rectangle(x, y, w, h, COLORS.button).setInteractive({ useHandCursor: true })
    const text = this.add.text(x, y, label, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)

    bg.on('pointerover', () => bg.setFillStyle(COLORS.buttonHover))
    bg.on('pointerout', () => bg.setFillStyle(COLORS.button))
    bg.on('pointerdown', onClick)

    return { bg, text, width: w, height: h, setVisible: (v) => { bg.setVisible(v); text.setVisible(v) }, setInteractive: (v) => { v ? bg.setInteractive() : bg.disableInteractive() } }
  }

  createChallengeOverlay() {
    this.challengeOverlay = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    this.challengeOverlay.setDepth(100)
    this.challengeOverlay.setVisible(false)

    // Dark backdrop
    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.7).setOrigin(0.5)
    this.challengeOverlay.add(backdrop)

    // Panel
    const panel = this.add.rectangle(0, 0, 400, 240, COLORS.panelBg).setStrokeStyle(2, COLORS.button)
    this.challengeOverlay.add(panel)

    // Kanji display
    this.challengeKanji = this.add.text(0, -50, '', FONTS.kanji)
    this.challengeOverlay.add(this.challengeKanji)

    // Prompt
    this.challengePrompt = this.add.text(0, 10, '', { ...FONTS.default, fontSize: '16px' })
    this.challengeOverlay.add(this.challengePrompt)

    // Input display
    this.challengeInput = this.add.text(0, 50, '', { ...FONTS.default, fontSize: '20px', color: '#f1c40f' })
    this.challengeOverlay.add(this.challengeInput)

    // Timer bar background
    this.add.rectangle(0, 100, 300, 12, COLORS.hpBg).setOrigin(0.5)
    this.challengeTimerBar = this.add.rectangle(-150, 100, 300, 12, COLORS.warning).setOrigin(0, 0.5)
    this.challengeOverlay.add(this.challengeTimerBar)
  }

  createCombatLog() {
    this.combatLogText = this.add.text(GAME_CONFIG.width / 2, 180, '', {
      ...FONTS.default,
      fontSize: '14px',
      align: 'center',
      wordWrap: { width: 500 },
    }).setOrigin(0.5)
  }

  // ---------- Interaction ----------

  handleKeyInput(event) {
    if (!this.challengeActive) return

    // Prevent browser find/search from intercepting typed keys
    event.preventDefault()

    if (event.key === 'Backspace') {
      this.typedInput = this.typedInput.slice(0, -1)
    } else if (event.key === 'Enter') {
      this.submitChallenge()
      return
    } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey) {
      this.typedInput += event.key
    }
    this.challengeInput.setText(this.typedInput)
  }

  onSkillClick(skill) {
    if (this.challengeActive) return
    if (this.turnManager.currentTurn !== 'player') return
    if (!this.player.canUseSkill(skill)) {
      this.addCombatLog('Not enough stamina!')
      return
    }

    this.selectedSkill = skill
    this.startChallenge(skill)
  }

  onEndTurn() {
    if (this.challengeActive) return
    if (this.turnManager.currentTurn !== 'player') return
    this.turnManager.endTurn()
  }

  startChallenge(skill) {
    this.challengeActive = true
    this.typedInput = ''
    this.currentChallenge = this.challengeSystem.getChallengeForSkill(skill)
    if (!this.currentChallenge) {
      this.challengeActive = false
      this.executeSkill('success')
      return
    }

    this.challengeKanji.setText(this.currentChallenge.kanji)
    this.challengePrompt.setText(this.currentChallenge.prompt)
    this.challengeInput.setText('')
    this.challengeOverlay.setVisible(true)
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)
  }

  submitChallenge() {
    if (!this.challengeActive) return
    const result = this.challengeSystem.evaluate(this.typedInput, this.currentChallenge)
    this.challengeActive = false
    this.challengeOverlay.setVisible(false)
    this.setSkillButtonsEnabled(true)
    this.endTurnBtn.setVisible(true)
    this.executeSkill(result.result)
  }

  executeSkill(challengeResult) {
    const result = this.turnManager.useSkill(
      this.selectedSkill,
      this.player,
      this.enemy,
      challengeResult
    )

    if (!result) {
      this.addCombatLog('Skill failed!')
      return
    }

    this.updateBars()
    this.updateBlockText()

    const quality = challengeResult === 'perfect' ? 'Perfect!' : challengeResult === 'success' ? '' : 'Failed...'
    switch (result.type) {
      case 'attack': {
        const critText = result.isCrit ? ' CRITICAL!' : ''
        this.addCombatLog(`${quality} ${this.selectedSkill.name}${critText} -> ${result.damage} damage!`)
        this.spawnFloatingText(this.enemySprite.x, this.enemySprite.y - 40, `-${result.damage}`, COLORS.danger)
        this.shakeSprite(this.enemySprite)
        break
      }
      case 'defence': {
        this.addCombatLog(`${quality} ${this.selectedSkill.name} -> +${result.block} block!`)
        this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${result.block} Block`, 0x3498db)
        break
      }
      case 'heal': {
        if (result.error) {
          this.addCombatLog(result.error)
        } else {
          this.addCombatLog(`${quality} ${this.selectedSkill.name} -> +${result.healed} HP!`)
          this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${result.healed}`, COLORS.success)
        }
        break
      }
    }
  }

  // ---------- Enemy AI ----------

  async onTurnChange(turn) {
    this.updateBars()
    this.updateBlockText()

    if (turn === 'player') {
      this.turnText.setText('YOUR TURN')
      this.turnText.setColor(COLORS.text)
      this.setSkillButtonsEnabled(true)
      this.endTurnBtn.setVisible(true)
    } else {
      this.turnText.setText('ENEMY TURN')
      this.turnText.setColor(COLORS.danger)
      this.setSkillButtonsEnabled(false)
      this.endTurnBtn.setVisible(false)
      await this.runEnemyTurn()
    }
  }

  async runEnemyTurn() {
    await this.delay(800)

    while (this.turnManager.currentTurn === 'enemy' && !this.turnManager.battleOver) {
      const action = this.enemy.chooseAction()
      if (!action) break

      const result = this.enemy.performAction(action, this.player)
      this.updateBars()
      this.updateBlockText()

      switch (result.type) {
        case 'attack': {
          const critText = result.isCrit ? ' CRITICAL!' : ''
          this.addCombatLog(`Oni uses ${action.name}${critText}! You take ${result.damage} damage!`)
          this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `-${result.damage}`, COLORS.danger)
          this.shakeSprite(this.playerSprite)
          break
        }
        case 'buff': {
          this.addCombatLog(`Oni uses ${action.name}! Its next attack will be stronger!`)
          break
        }
        case 'recover': {
          this.addCombatLog(`Oni rests and recovers ${result.stamina} stamina.`)
          break
        }
      }

      await this.delay(1000)
    }

    if (!this.turnManager.battleOver) {
      this.turnManager.endTurn()
    }
  }

  // ---------- UI Updates ----------

  updateBars() {
    this.updateBar('playerHp', this.player.hp, this.player.maxHp)
    this.updateBar('playerStamina', this.player.stamina, this.player.maxStamina)
    this.updateBar('enemyHp', this.enemy.hp, this.enemy.maxHp)
    this.updateBar('enemyStamina', this.enemy.stamina, this.enemy.maxStamina)

    this.playerHpText.setText(`${this.player.hp}/${this.player.maxHp}`)
    this.playerStaminaText.setText(`${this.player.stamina}/${this.player.maxStamina}`)
    this.enemyHpText.setText(`${this.enemy.hp}/${this.enemy.maxHp}`)
    this.enemyStaminaText.setText(`${this.enemy.stamina}/${this.enemy.maxStamina}`)
  }

  updateBar(key, value, max) {
    const bar = this[key + 'Bar']
    if (!bar) return
    const pct = Math.max(0, value / max)
    bar.setScale(pct, 1)
    if (key === 'playerHp' && pct <= 0.25) bar.setFillStyle(COLORS.danger)
    else if (key === 'playerHp') bar.setFillStyle(COLORS.hp)
    if (key === 'enemyHp' && pct <= 0.25) bar.setFillStyle(COLORS.danger)
    else if (key === 'enemyHp') bar.setFillStyle(COLORS.hp)
  }

  updateBlockText() {
    this.playerBlockText.setText(this.player.block > 0 ? `Block: ${this.player.block}` : '')
    this.enemyBlockText.setText(this.enemy.block > 0 ? `Block: ${this.enemy.block}` : '')
  }

  setSkillButtonsEnabled(enabled) {
    this.skillButtons.forEach(({ btn, skill }) => {
      if (enabled && this.player.canUseSkill(skill)) {
        btn.bg.setFillStyle(COLORS.button)
        btn.bg.setInteractive({ useHandCursor: true })
        btn.text.setAlpha(1)
      } else {
        btn.bg.setFillStyle(COLORS.buttonDisabled)
        btn.bg.disableInteractive()
        btn.text.setAlpha(0.6)
      }
    })
  }

  addCombatLog(msg) {
    this.combatLogText.setText(msg)
    // Reset alpha animation
    this.combatLogText.setAlpha(1)
    this.tweens.add({
      targets: this.combatLogText,
      alpha: 0.6,
      duration: 2000,
      ease: 'Linear',
    })
  }

  spawnFloatingText(x, y, text, color) {
    const t = this.add.text(x, y, text, {
      fontFamily: FONTS.default.fontFamily,
      fontSize: '20px',
      fontStyle: 'bold',
      color: typeof color === 'number' ? '#' + color.toString(16).padStart(6, '0') : color,
    }).setOrigin(0.5)

    this.particles.push({ text: t, x, y, life: 1000, speed: 40 })
  }

  shakeSprite(sprite) {
    this.tweens.add({
      targets: sprite,
      x: sprite.x + (sprite.x < GAME_CONFIG.width / 2 ? -10 : 10),
      duration: 50,
      yoyo: true,
      repeat: 3,
    })
  }

  // ---------- Battle End ----------

  onBattleEnd(winner) {
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)
    this.challengeOverlay.setVisible(false)
    this.challengeActive = false

    const isWin = winner === 'player'
    const title = isWin ? 'VICTORY!' : 'DEFEAT...'
    const color = isWin ? COLORS.success : COLORS.danger

    // Overlay
    const overlay = this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.6).setDepth(200)
    const panel = this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, 400, 200, COLORS.panelBg).setDepth(200).setStrokeStyle(2, color)
    const titleText = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 40, title, {
      ...FONTS.title,
      fontSize: '32px',
      color: '#' + color.toString(16).padStart(6, '0'),
    }).setOrigin(0.5).setDepth(200)

    const subText = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 10, isWin ? 'You defeated the Lesser Oni!' : 'The Oni was too strong...', {
      ...FONTS.default,
      fontSize: '16px',
    }).setOrigin(0.5).setDepth(200)

    const restartBtn = this.createButton(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 60, 'Play Again', () => {
      this.scene.restart()
    })
    restartBtn.bg.setDepth(200)
    restartBtn.text.setDepth(200)

    // Send result to server
    sendRunResult({
      winner,
      playerHp: this.player.hp,
      enemyHp: this.enemy.hp,
      turnCount: this.turnManager.turnCount,
      timestamp: new Date().toISOString(),
    })
  }

  delay(ms) {
    return new Promise(resolve => this.time.delayedCall(ms, resolve))
  }
}
