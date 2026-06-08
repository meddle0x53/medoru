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

    this.addCombatLog('Battle start! Defeat the Kasa-obake!')
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
    // Background image — scale to cover the 960x540 canvas
    const bg = this.add.image(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, 'battle_background')
    const scaleX = GAME_CONFIG.width / bg.width
    const scaleY = GAME_CONFIG.height / bg.height
    bg.setScale(Math.max(scaleX, scaleY))

    // Ground line (subtle, for visual reference)
    this.add.line(0, 0, 0, 580, GAME_CONFIG.width, 580, 0x0f3460, 0.5).setOrigin(0, 0)
  }

  createCharacters() {
    // Player sprite — default battle stance (sword + shield)
    this.playerSprite = this.add.sprite(300, 580, 'player_sword_shield')
    this.playerSprite.setScale(0.30)
    this.playerSprite.setOrigin(0.5, 0.99) // Anchor near bottom so feet stay on ground
    // Feet on ground line (set via origin)
    // Smooth scaling for anime-style renders
    this.textures.get('player_sword_shield').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('player_sword_slash').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('player_shield_block').setFilter(Phaser.Textures.FilterMode.LINEAR)

    this.drawNameBg(300, 102)
    this.add.text(300, 95, this.player.name, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.add.text(300, 110, '戦士', { ...FONTS.kanji, fontSize: '14px' }).setOrigin(0.5)

    // Enemy — kasa-obake facing left toward hero
    this.enemySprite = this.add.sprite(720, 570, 'enemy_kasa_obake')
    this.enemySprite.setScale(0.30)
    this.enemySprite.setOrigin(0.5, 0.99)
    this.textures.get('enemy_kasa_obake').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('enemy_kasa_obake_attack').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('enemy_kasa_obake_defend').setFilter(Phaser.Textures.FilterMode.LINEAR)

    this.drawNameBg(720, 102)
    this.add.text(720, 95, this.enemy.name, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.add.text(720, 110, this.enemy.nameJa, { ...FONTS.kanji, fontSize: '14px' }).setOrigin(0.5)
  }

  setPlayerSprite(key) {
    this.playerSprite.setTexture(key)
  }

  setEnemySprite(key) {
    this.enemySprite.setTexture(key)
  }

  flashPlayerSprite() {
    this.tweens.add({
      targets: this.playerSprite,
      alpha: 0.5,
      duration: 100,
      yoyo: true,
      repeat: 1,
    })
  }

  createUI() {
    // Turn indicator with rounded background
    this.turnTextBg = this.add.graphics()
    this.drawTurnTextBg()
    this.turnText = this.add.text(GAME_CONFIG.width / 2, 30, 'YOUR TURN', {
      ...FONTS.title,
      fontSize: '18px',
    }).setOrigin(0.5)

    // Player bars (left top)
    this.createBar(300, 500, 'playerHp', COLORS.hp, this.player.hp, this.player.maxHp)
    this.createBar(300, 517, 'playerStamina', COLORS.stamina, this.player.stamina, this.player.maxStamina)
    this.playerHpText = this.add.text(300, 500, `${this.player.hp}/${this.player.maxHp}`, { ...FONTS.default, fontSize: '12px', color: '#1a1a2e' }).setOrigin(0.5)
    this.playerStaminaText = this.add.text(300, 517, `${this.player.stamina}/${this.player.maxStamina}`, { ...FONTS.default, fontSize: '12px', color: '#1a1a2e' }).setOrigin(0.5)

    // Enemy bars (right top)
    this.createBar(720, 500, 'enemyHp', COLORS.hp, this.enemy.hp, this.enemy.maxHp)
    this.createBar(720, 517, 'enemyStamina', COLORS.stamina, this.enemy.stamina, this.enemy.maxStamina)
    this.enemyHpText = this.add.text(720, 500, `${this.enemy.hp}/${this.enemy.maxHp}`, { ...FONTS.default, fontSize: '12px', color: '#1a1a2e' }).setOrigin(0.5)
    this.enemyStaminaText = this.add.text(720, 517, `${this.enemy.stamina}/${this.enemy.maxStamina}`, { ...FONTS.default, fontSize: '12px', color: '#1a1a2e' }).setOrigin(0.5)

    // Action panel — modern rounded glass panel behind hero sprite
    this.actionPanel = this.createModernPanel(120, 273, 180, 240, 16)

    this.skillButtons = []
    const s1 = this.player.equippedSkills[0] // Forward Slash
    const s2 = this.player.equippedSkills[1] // Setup Defence
    const s3 = this.player.equippedSkills[2] // Heal Potion

    this.skillButtons.push({ btn: this.createButton(120, 195, `${s1.name} (${s1.staminaCost})`, () => this.onSkillClick(s1), 160, 44, 0xc0392b, 0xe74c3c), skill: s1 })
    this.skillButtons.push({ btn: this.createButton(120, 247, `${s2.name} (${s2.staminaCost})`, () => this.onSkillClick(s2), 160, 44, 0x8b4513, 0xa0522d), skill: s2 })
    this.skillButtons.push({ btn: this.createButton(120, 299, `${s3.name} (${s3.staminaCost})`, () => this.onSkillClick(s3), 160, 44, 0x27ae60, 0x2ecc71), skill: s3 })

    // Fourth button — Switch Action (blue, does nothing for now)
    this.switchActionBtn = this.createButton(120, 351, 'Switch Action (1)', () => {}, 160, 44, 0x2980b9, 0x3498db)

    // End turn button inside the panel
    this.endTurnBtn = this.createButton(120, 475, 'End Turn', () => this.onEndTurn(), 160, 44, 0xe67e22, 0xf39c12)

    // Block indicators
    this.playerBlockText = this.add.text(300, 485, '', { ...FONTS.default, fontSize: '12px', color: '#3498db' }).setOrigin(0.5)
    this.enemyBlockText = this.add.text(720, 485, '', { ...FONTS.default, fontSize: '12px', color: '#3498db' }).setOrigin(0.5)
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

  drawNameBg(x, y) {
    const w = 180
    const h = 44
    const radius = 22
    const g = this.add.graphics()
    g.fillStyle(0x2c3e50, 0.75)
    g.fillRoundedRect(x - w / 2, y - h / 2, w, h, radius)
    g.lineStyle(1.5, 0x7f8c8d, 0.4)
    g.strokeRoundedRect(x - w / 2, y - h / 2, w, h, radius)
    return g
  }

  drawTurnTextBg() {
    const w = 220
    const h = 36
    const x = GAME_CONFIG.width / 2
    const y = 30
    const radius = 18
    this.turnTextBg.clear()
    this.turnTextBg.fillStyle(0x2c3e50, 0.75)
    this.turnTextBg.fillRoundedRect(x - w / 2, y - h / 2, w, h, radius)
    this.turnTextBg.lineStyle(1.5, 0x7f8c8d, 0.4)
    this.turnTextBg.strokeRoundedRect(x - w / 2, y - h / 2, w, h, radius)
  }

  animateTurnChange() {
    this.tweens.add({
      targets: [this.turnTextBg, this.turnText],
      scaleX: 1.15,
      scaleY: 1.15,
      duration: 150,
      yoyo: true,
      ease: 'Quad.easeOut',
    })
  }

  createModernPanel(x, y, w, h, radius) {
    const g = this.add.graphics()
    // Drop shadow
    g.fillStyle(0x000000, 0.25)
    g.fillRoundedRect(x - w / 2 + 3, y - h / 2 + 4, w, h, radius)
    // Fill
    g.fillStyle(0x1a1a2e, 0.92)
    g.fillRoundedRect(x - w / 2, y - h / 2, w, h, radius)
    // Border glow
    g.lineStyle(1.5, 0x3498db, 0.35)
    g.strokeRoundedRect(x - w / 2, y - h / 2, w, h, radius)
    // Top highlight
    g.lineStyle(1, 0xffffff, 0.08)
    g.lineBetween(x - w / 2 + radius, y - h / 2 + 1, x + w / 2 - radius, y - h / 2 + 1)
    return g
  }

  createButton(x, y, label, onClick, w = 140, h = 36, color = COLORS.button, hoverColor = COLORS.buttonHover) {
    const radius = Math.min(h / 2, 10)

    // Shadow
    const shadow = this.add.graphics()
    shadow.fillStyle(0x000000, 0.2)
    shadow.fillRoundedRect(x - w / 2 + 1, y - h / 2 + 2, w, h, radius)

    // Background
    const bg = this.add.graphics()
    const redraw = (c) => {
      bg.clear()
      bg.fillStyle(c, 1)
      bg.fillRoundedRect(x - w / 2, y - h / 2, w, h, radius)
      // Subtle top highlight
      bg.lineStyle(1, 0xffffff, 0.1)
      bg.lineBetween(x - w / 2 + radius, y - h / 2 + 1, x + w / 2 - radius, y - h / 2 + 1)
    }
    redraw(color)

    // Invisible hit area for interaction
    const hitArea = this.add.rectangle(x, y, w, h, 0x000000, 0).setInteractive({ useHandCursor: true })

    const text = this.add.text(x, y, label, { ...FONTS.default, fontSize: '15px' }).setOrigin(0.5)

    hitArea.on('pointerover', () => {
      redraw(hoverColor)
      text.setScale(1.04)
    })
    hitArea.on('pointerout', () => {
      redraw(color)
      text.setScale(1)
    })
    hitArea.on('pointerdown', onClick)

    return {
      bg, shadow, hitArea, text, redraw,
      width: w, height: h,
      setVisible: (v) => { bg.setVisible(v); shadow.setVisible(v); hitArea.setVisible(v); text.setVisible(v) },
      setInteractive: (v) => { v ? hitArea.setInteractive({ useHandCursor: true }) : hitArea.disableInteractive() }
    }
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
    const timerBg = this.add.rectangle(0, 100, 300, 12, COLORS.hpBg).setOrigin(0.5)
    this.challengeOverlay.add(timerBg)
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
        this.setPlayerSprite('player_sword_slash')
        const critText = result.isCrit ? ' CRITICAL!' : ''
        this.addCombatLog(`${quality} ${this.selectedSkill.name}${critText} -> ${result.damage} damage!`)
        this.spawnFloatingText(this.enemySprite.x, this.enemySprite.y - 40, `-${result.damage}`, COLORS.danger)
        this.shakeSprite(this.enemySprite)
        this.time.delayedCall(600, () => this.setPlayerSprite('player_sword_shield'))
        break
      }
      case 'defence': {
        this.setPlayerSprite('player_shield_block')
        this.addCombatLog(`${quality} ${this.selectedSkill.name} -> +${result.block} block!`)
        this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${result.block} Block`, 0x3498db)
        this.time.delayedCall(600, () => this.setPlayerSprite('player_sword_shield'))
        break
      }
      case 'heal': {
        this.flashPlayerSprite()
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
      this.animateTurnChange()
      this.setSkillButtonsEnabled(true)
      this.endTurnBtn.setVisible(true)
    } else {
      this.turnText.setText('ENEMY TURN')
      this.turnText.setColor(COLORS.danger)
      this.animateTurnChange()
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
          this.setEnemySprite('enemy_kasa_obake_attack')
          this.setPlayerSprite('player_shield_block')
          const critText = result.isCrit ? ' CRITICAL!' : ''
          this.addCombatLog(`Kasa-obake uses ${action.name}${critText}! You take ${result.damage} damage!`)
          this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `-${result.damage}`, COLORS.danger)
          this.shakeSprite(this.playerSprite)
          this.time.delayedCall(800, () => {
            this.setPlayerSprite('player_sword_shield')
            this.setEnemySprite('enemy_kasa_obake')
          })
          break
        }
        case 'buff': {
          this.setEnemySprite('enemy_kasa_obake_defend')
          this.addCombatLog(`Kasa-obake uses ${action.name}! Its next attack will be stronger!`)
          this.time.delayedCall(800, () => this.setEnemySprite('enemy_kasa_obake'))
          break
        }
        case 'recover': {
          this.addCombatLog(`Kasa-obake rests and recovers ${result.stamina} stamina.`)
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
        btn.redraw(COLORS.button)
        btn.hitArea.setInteractive({ useHandCursor: true })
        btn.text.setAlpha(1)
      } else {
        btn.redraw(COLORS.buttonDisabled)
        btn.hitArea.disableInteractive()
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

    const subText = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 10, isWin ? 'You defeated the Kasa-obake!' : 'The Kasa-obake was too strong...', {
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
