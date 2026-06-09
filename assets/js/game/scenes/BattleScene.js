import { GAME_CONFIG, COLORS, FONTS } from '../config.js'
import Player from '../entities/Player.js'
import Enemy from '../entities/Enemy.js'
import TurnManager from '../systems/TurnManager.js'
import ChallengeSystem from '../systems/ChallengeSystem.js'
import KanjiDrawingSystem from '../systems/KanjiDrawingSystem.js'
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
    this.challengeSystem = new ChallengeSystem(userData?.kanji_list)

    // Kanji drawing for weapon powerups (Forward Slash uses 力)
    this.kanjiDrawing = new KanjiDrawingSystem(
      this,
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      320
    )

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
    this.createIntentionIcons()
    this.createChallengeOverlay()
    this.createReadinessOverlay()
    this.createItemMenu()
    this.createCombatLog()

    this.input.keyboard.on('keydown', this.handleKeyInput, this)

    // Hidden input for mobile touch keyboard during readiness challenge
    this.hiddenInput = document.createElement('input')
    this.hiddenInput.type = 'text'
    this.hiddenInput.style.position = 'absolute'
    this.hiddenInput.style.opacity = '0'
    this.hiddenInput.style.pointerEvents = 'none'
    this.hiddenInput.style.left = '-9999px'
    this.hiddenInput.autocomplete = 'off'
    this.hiddenInput.autocapitalize = 'off'
    this.hiddenInput.autocorrect = 'off'
    document.body.appendChild(this.hiddenInput)

    this.addCombatLog('Battle start! Defeat the Kasa-obake!')
    this.onTurnChange('player')
  }

  update(time, delta) {
    if (this.challengeActive && this.currentChallenge && !this.readinessChallengeActive && !this.reactionChallengeActive) {
      const elapsed = Date.now() - this.currentChallenge.startTime
      const pct = Math.max(0, 1 - elapsed / this.currentChallenge.timeLimit)
      this.challengeTimerBar.setScale(pct, 1)
      if (elapsed >= this.currentChallenge.timeLimit) {
        this.submitChallenge()
      }
    }

    if (this.readinessChallengeActive) {
      this.updateReadinessTimer()
    }

    if (this.reactionChallengeActive) {
      this.updateReactionTimer()
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
    this.textures.get('player_defeated').setFilter(Phaser.Textures.FilterMode.LINEAR)

    this.drawNameBg(300, 102)
    this.add.text(300, 95, this.player.name, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.add.text(300, 110, '戦士', { ...FONTS.kanji, fontSize: '14px' }).setOrigin(0.5)

    // Enemy — kasa-obake facing left toward hero
    this.enemySprite = this.add.sprite(690, 570, 'enemy_kasa_obake')
    this.enemySprite.setScale(0.30)
    this.enemySprite.setOrigin(0.5, 0.99)
    this.textures.get('enemy_kasa_obake').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('enemy_kasa_obake_attack').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('enemy_kasa_obake_defend').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('enemy_kasa_obake_buff').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('enemy_kasa_obake_defeated').setFilter(Phaser.Textures.FilterMode.LINEAR)

    this.drawNameBg(690, 102)
    this.add.text(690, 95, this.enemy.name, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.add.text(690, 110, this.enemy.nameJa, { ...FONTS.kanji, fontSize: '14px' }).setOrigin(0.5)
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

    this.skillButtons.push({ btn: this.createButton(120, 195, `${s1.name} (${s1.staminaCost})`, () => this.onSkillClick(s1), 160, 44, 0xc0392b, 0xe74c3c), skill: s1 })
    this.skillButtons.push({ btn: this.createButton(120, 247, `${s2.name} (${s2.staminaCost})`, () => this.onSkillClick(s2), 160, 44, 0x8b4513, 0xa0522d), skill: s2 })

    // Use Item button (replaces Heal Potion)
    const itemCost = 1
    this.itemButton = this.createButton(120, 299, `Use Item (${itemCost})`, () => this.onUseItemClick(), 160, 44, 0x27ae60, 0x2ecc71)

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
    // Light background so dark text is readable
    this.add.rectangle(x, y, w, h, 0xe0e0e0).setOrigin(0.5)
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
      bg, shadow, hitArea, text, redraw, color, hoverColor,
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

  createReadinessOverlay() {
    this.readinessOverlay = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    this.readinessOverlay.setDepth(100)
    this.readinessOverlay.setVisible(false)

    // Dark backdrop
    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.75).setOrigin(0.5)
    this.readinessOverlay.add(backdrop)

    // Panel
    const panel = this.add.rectangle(0, 0, 440, 280, COLORS.panelBg).setStrokeStyle(2, COLORS.warning)
    this.readinessOverlay.add(panel)

    // Title
    this.readinessTitle = this.add.text(0, -100, 'End Turn Challenge', { ...FONTS.title, fontSize: '20px', color: '#f39c12' }).setOrigin(0.5)
    this.readinessOverlay.add(this.readinessTitle)

    // Prompt
    this.readinessPrompt = this.add.text(0, -60, 'Type the reading of this word:', { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.readinessOverlay.add(this.readinessPrompt)

    // Word display (large Japanese text)
    this.readinessWord = this.add.text(0, -15, '', { ...FONTS.kanji, fontSize: '42px', color: '#ecf0f1' }).setOrigin(0.5)
    this.readinessOverlay.add(this.readinessWord)

    // Reading hint (small, shown after a few seconds on failure path)
    this.readinessHint = this.add.text(0, 25, '', { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.readinessOverlay.add(this.readinessHint)

    // Input display
    this.readinessInputText = this.add.text(0, 55, '', { ...FONTS.default, fontSize: '22px', color: '#f1c40f' }).setOrigin(0.5)
    this.readinessOverlay.add(this.readinessInputText)

    // Timer bar background
    const timerBg = this.add.rectangle(0, 95, 320, 12, COLORS.hpBg).setOrigin(0.5)
    this.readinessOverlay.add(timerBg)
    this.readinessTimerBar = this.add.rectangle(-160, 95, 320, 12, COLORS.warning).setOrigin(0, 0.5)
    this.readinessOverlay.add(this.readinessTimerBar)

    // Timer text
    this.readinessTimerText = this.add.text(0, 115, '10.0s', { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.readinessOverlay.add(this.readinessTimerText)
  }

  createItemMenu() {
    this.itemMenuOverlay = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    this.itemMenuOverlay.setDepth(100)
    this.itemMenuOverlay.setVisible(false)

    // Dark backdrop
    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.7).setOrigin(0.5)
    this.itemMenuOverlay.add(backdrop)

    // Panel
    const panel = this.add.rectangle(0, 0, 420, 320, COLORS.panelBg).setStrokeStyle(2, 0x27ae60)
    this.itemMenuOverlay.add(panel)

    // Title
    this.itemMenuTitle = this.add.text(0, -130, 'Select Item', { ...FONTS.title, fontSize: '20px', color: '#2ecc71' }).setOrigin(0.5)
    this.itemMenuOverlay.add(this.itemMenuTitle)

    // Item rows container
    this.itemMenuRows = []
    for (let i = 0; i < 5; i++) {
      const y = -80 + i * 50
      const rowBg = this.add.rectangle(0, y, 360, 44, 0x1a1a2e).setStrokeStyle(1, 0x7f8c8d).setOrigin(0.5)
      const icon = this.add.text(-150, y, '', { ...FONTS.default, fontSize: '18px' }).setOrigin(0.5)
      const name = this.add.text(-90, y, '', { ...FONTS.default, fontSize: '14px' }).setOrigin(0, 0.5)
      const desc = this.add.text(-90, y + 12, '', { ...FONTS.default, fontSize: '11px', color: '#7f8c8d' }).setOrigin(0, 0.5)
      const hitArea = this.add.rectangle(0, y, 360, 44, 0x000000, 0).setOrigin(0.5).setInteractive({ useHandCursor: true })

      this.itemMenuOverlay.add(rowBg)
      this.itemMenuOverlay.add(icon)
      this.itemMenuOverlay.add(name)
      this.itemMenuOverlay.add(desc)
      this.itemMenuOverlay.add(hitArea)

      this.itemMenuRows.push({ bg: rowBg, icon, name, desc, hitArea })
    }

    // Close button
    const closeBtn = this.createButton(0, 140, 'Cancel', () => this.hideItemMenu(), 120, 36, 0x7f8c8d, 0x95a5a6)
    this.itemMenuCloseBtn = closeBtn
    this.itemMenuOverlay.add(closeBtn.bg)
    this.itemMenuOverlay.add(closeBtn.shadow)
    this.itemMenuOverlay.add(closeBtn.hitArea)
    this.itemMenuOverlay.add(closeBtn.text)
  }

  showItemMenu() {
    const items = this.player.inventory || []
    if (items.length === 0) {
      this.addCombatLog('No items in inventory!')
      return
    }

    this.challengeActive = true
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    this.itemMenuRows.forEach((row, i) => {
      if (i < items.length) {
        const item = items[i]
        row.icon.setText(item.icon)
        row.name.setText(`${item.name} (${item.staminaCost} STA)`)
        row.desc.setText(item.description)
        row.bg.setVisible(true)
        row.icon.setVisible(true)
        row.name.setVisible(true)
        row.desc.setVisible(true)
        row.hitArea.setVisible(true)
        row.hitArea.setInteractive({ useHandCursor: true })
        row.hitArea.off('pointerdown')
        row.hitArea.on('pointerdown', () => this.onItemSelect(item))
        row.bg.setFillStyle(0x1a1a2e)
        row.hitArea.on('pointerover', () => row.bg.setFillStyle(0x27ae60))
        row.hitArea.on('pointerout', () => row.bg.setFillStyle(0x1a1a2e))
      } else {
        row.bg.setVisible(false)
        row.icon.setVisible(false)
        row.name.setVisible(false)
        row.desc.setVisible(false)
        row.hitArea.setVisible(false)
        row.hitArea.disableInteractive()
      }
    })

    this.itemMenuOverlay.setVisible(true)
  }

  hideItemMenu() {
    this.itemMenuOverlay.setVisible(false)
    this.challengeActive = false
    this.setSkillButtonsEnabled(true)
    this.endTurnBtn.setVisible(true)
  }

  onUseItemClick() {
    if (this.challengeActive) return
    if (this.turnManager.currentTurn !== 'player') return
    if (this.player.stamina < 1) {
      this.addCombatLog('Not enough stamina!')
      return
    }
    this.showItemMenu()
  }

  onItemSelect(item) {
    this.selectedItem = item
    this.hideItemMenu()
    this.player.useStamina(item.staminaCost)
    this.updateBars()
    this.startItemChallenge(item)
  }

  pickRandomKanjiForItem() {
    const kanjiList = this.player.kanjiList || []
    // Filter to kanji with stroke data
    const withStrokes = kanjiList.filter(k => k.stroke_data && k.stroke_data.strokes && k.stroke_data.strokes.length > 0)
    if (withStrokes.length > 0) {
      return withStrokes[Math.floor(Math.random() * withStrokes.length)]
    }
    // Fallback: use default kanji from game data
    const defaults = [
      { character: '力', meanings: ['Power', 'Strength'], on_readings: ['リョク', 'リキ'], kun_readings: ['ちから'], stroke_count: 2, stroke_data: getWindowGameData()?.weapon_kanji_strokes || { strokes: [] } },
      { character: '盾', meanings: ['Shield', 'Escutcheon'], on_readings: ['ジュン'], kun_readings: ['たて'], stroke_count: 9, stroke_data: getWindowGameData()?.shield_kanji_strokes || { strokes: [] } },
    ].filter(k => k.stroke_data.strokes && k.stroke_data.strokes.length > 0)
    if (defaults.length > 0) {
      return defaults[Math.floor(Math.random() * defaults.length)]
    }
    return null
  }

  startItemChallenge(item) {
    this.challengeActive = true
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    const kanji = this.pickRandomKanjiForItem()
    if (!kanji || !kanji.stroke_data || !kanji.stroke_data.strokes || kanji.stroke_data.strokes.length === 0) {
      // No kanji available — use base effect
      this.addCombatLog(`No kanji challenge — using base ${item.name} effect.`)
      this.executeItem(item, { completed: true, wrongStrokes: 999, timedOut: false })
      return
    }

    this.currentItemKanji = kanji
    // Allowed wrong strokes: max(floor(stroke_count / 2), 3)
    const strokeCount = kanji.stroke_count || kanji.stroke_data.strokes.length
    this.itemAllowedWrong = Math.max(Math.floor(strokeCount / 2), 3)

    // Build hint from meanings and readings (don't show the character!)
    const meanings = (kanji.meanings || []).slice(0, 2).join(', ')
    const kun = (kanji.kun_readings || []).join(', ')
    const on = (kanji.on_readings || []).join(', ')
    let hintParts = []
    if (meanings) hintParts.push(meanings)
    if (kun) hintParts.push(kun)
    if (on) hintParts.push(on)
    const hintText = hintParts.join(' | ')
    const hint = `Draw the kanji: ${hintText}`
    this.kanjiDrawing.start(kanji.stroke_data, hint, {
      onComplete: (result) => {
        this.challengeActive = false
        this.setSkillButtonsEnabled(true)
        this.endTurnBtn.setVisible(true)
        this.executeItem(item, result)
      },
      onWrongStroke: ({ count }) => {
        this.spawnFloatingText(
          GAME_CONFIG.width / 2,
          GAME_CONFIG.height / 2 - 180,
          `Wrong stroke! (${count}/${this.itemAllowedWrong} allowed)`,
          COLORS.danger
        )
      },
    })
  }

  executeItem(item, kanjiResult) {
    let modifier = 0
    const allowed = this.itemAllowedWrong || 3

    if (kanjiResult.completed) {
      if (kanjiResult.wrongStrokes <= allowed) {
        modifier = 2
        this.addCombatLog(`Perfect kanji! ${item.name} empowered! (+2)`)
      } else {
        modifier = 0
        this.addCombatLog(`Kanji drawn! ${item.name} used. (sloppy)`)
      }
    } else {
      modifier = -2
      this.addCombatLog(`Kanji failed! Weak ${item.name}. (-2)`)
    }

    this.player.setItemEffectModifier(modifier)

    if (item.type === 'heal') {
      const healAmount = this.player.getItemHealAmount(item.baseValue)
      const actual = this.player.heal(healAmount)
      this.flashPlayerSprite()
      this.addCombatLog(`${item.name} -> +${actual} HP!`)
      this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${actual}`, COLORS.success)
    } else if (item.type === 'damage') {
      const rawDamage = this.player.getItemDamage(item.baseValue)
      // Apply enemy defense
      const defense = this.enemy.getDefense()
      let finalDamage
      if (defense <= 0) {
        finalDamage = rawDamage
      } else {
        finalDamage = Math.floor(rawDamage * rawDamage / (rawDamage + defense))
      }
      finalDamage = Math.max(1, finalDamage - this.enemy.armor)
      const actual = this.enemy.takeDamage(finalDamage)
      // Enemy doesn't die from stone? No, takeDamage handles death
      // Check if enemy died
      if (!this.enemy.isAlive()) {
        this.turnManager.battleOver = true
        this.turnManager.winner = 'player'
        if (this.turnManager.onBattleEnd) this.turnManager.onBattleEnd('player')
      }
      this.setPlayerSprite('player_sword_shield') // placeholder until we have stone throw sprite
      this.addCombatLog(`${item.name} thrown! -> ${actual} damage!`)
      this.spawnFloatingText(this.enemySprite.x, this.enemySprite.y - 40, `-${actual}`, COLORS.danger)
      this.shakeSprite(this.enemySprite)
      this.time.delayedCall(600, () => this.setPlayerSprite('player_sword_shield'))
    }

    this.player.clearItemEffectModifier()
    this.updateBars()
    this.updateBlockText()
  }

  startReadinessChallenge() {
    const wordList = this.player.wordList
    if (!wordList || wordList.length === 0) {
      // No words available — skip challenge, readiness stays 0
      this.addCombatLog('No words to review. Stay focused!')
      this.turnManager.endTurn()
      return
    }

    this.readinessChallengeActive = true
    this.challengeActive = true
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    // Pick a random word
    const wordData = wordList[Math.floor(Math.random() * wordList.length)]
    this.currentReadinessWord = wordData
    this.readinessInput = ''
    this.readinessStartTime = Date.now()
    this.readinessTimeLimit = 10000 // 10 seconds

    // Alternate challenge type: reading or meaning
    const hasMeaning = wordData.meaning && wordData.meaning.trim().length > 0
    this.readinessChallengeType = hasMeaning && Math.random() < 0.5 ? 'meaning' : 'reading'

    // Reset UI state from any previous challenge
    this.readinessTitle.setText('End Turn Challenge')
    this.readinessTitle.setColor('#f39c12')
    this.readinessWord.setText(wordData.word)
    this.readinessWord.setColor('#ecf0f1')
    this.readinessWord.setScale(1)
    this.readinessWord.setAlpha(1)
    this.readinessWord.setY(-15)

    if (this.readinessChallengeType === 'meaning') {
      this.readinessPrompt.setText('Type the meaning of this word:')
      this.readinessHint.setText(wordData.reading || '')
    } else {
      this.readinessPrompt.setText('Type the reading of this word:')
      this.readinessHint.setText(wordData.meaning || '')
    }
    this.readinessPrompt.setColor('#ecf0f1')

    this.readinessInputText.setText('')
    this.readinessTimerBar.setScale(1, 1)
    this.readinessTimerText.setText('10.0s')
    this.readinessOverlay.setVisible(true)

    // Focus hidden input to trigger mobile keyboard
    if (this.hiddenInput) {
      this.hiddenInput.value = ''
      this.hiddenInput.focus()
    }
  }

  updateReadinessTimer() {
    if (!this.readinessChallengeActive) return
    const elapsed = Date.now() - this.readinessStartTime
    const remaining = Math.max(0, this.readinessTimeLimit - elapsed)
    const pct = remaining / this.readinessTimeLimit
    this.readinessTimerBar.setScale(pct, 1)
    this.readinessTimerText.setText((remaining / 1000).toFixed(1) + 's')

    if (remaining <= 0) {
      this.submitReadinessChallenge(true)
    }
  }

  submitReadinessChallenge(timedOut = false) {
    if (!this.readinessChallengeActive) return

    this.readinessChallengeActive = false
    this.challengeActive = false

    // Blur hidden input to hide mobile keyboard
    if (this.hiddenInput) {
      this.hiddenInput.blur()
    }

    const input = this.readinessInput.trim()
    const challengeType = this.readinessChallengeType || 'reading'
    const wordData = this.currentReadinessWord

    let isCorrect = false
    let correctAnswer = ''
    if (challengeType === 'meaning') {
      correctAnswer = (wordData?.meaning || '').trim()
      isCorrect = !timedOut && input.length > 0 && input.toLowerCase() === correctAnswer.toLowerCase()
    } else {
      correctAnswer = (wordData?.reading || '').trim()
      isCorrect = !timedOut && input.length > 0 && input.toLowerCase() === correctAnswer.toLowerCase()
    }

    if (isCorrect) {
      this.player.setReadiness(1)
      this._animateReadinessSuccess(challengeType, correctAnswer)
    } else {
      this.player.setReadiness(0)
      this._animateReadinessFailure(timedOut, challengeType, correctAnswer)
    }
  }

  _animateReadinessSuccess(challengeType, correctAnswer) {
    // Positive animation: word bounces up, flashes green, sparkles
    const word = this.readinessWord
    word.setColor('#2ecc71')

    this.tweens.add({
      targets: word,
      scaleX: 1.4,
      scaleY: 1.4,
      duration: 250,
      ease: 'Back.easeOut',
      yoyo: true,
      hold: 200,
    })

    this.tweens.add({
      targets: word,
      y: word.y - 30,
      duration: 400,
      ease: 'Quad.easeOut',
      yoyo: true,
      hold: 200,
    })

    // Sparkle particles around the word
    for (let i = 0; i < 8; i++) {
      const angle = (Math.PI * 2 * i) / 8
      const dist = 60
      const px = word.x + Math.cos(angle) * dist
      const py = word.y + Math.sin(angle) * dist
      const p = this.add.text(px, py, '✦', {
        fontFamily: FONTS.default.fontFamily,
        fontSize: '16px',
        color: '#2ecc71',
      }).setOrigin(0.5).setAlpha(0)
      this.readinessOverlay.add(p)

      this.tweens.add({
        targets: p,
        alpha: { from: 0, to: 1 },
        scaleX: { from: 0.5, to: 1.2 },
        scaleY: { from: 0.5, to: 1.2 },
        duration: 200,
        ease: 'Quad.easeOut',
        onComplete: () => {
          this.tweens.add({
            targets: p,
            alpha: 0,
            scaleX: 0,
            scaleY: 0,
            duration: 300,
            delay: 300,
            onComplete: () => p.destroy(),
          })
        },
      })
    }

    this.readinessPrompt.setText('Correct! Stay focused!')
    this.readinessPrompt.setColor('#2ecc71')

    this.time.delayedCall(900, () => {
      this.readinessOverlay.setVisible(false)
      word.setColor('#ecf0f1')
      word.setScale(1)
      this.readinessPrompt.setColor('#ecf0f1')
      this.addCombatLog('Readiness: Focused! (+5 DEF, enemy miss chance doubled)')
      this.spawnFloatingText(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 120, 'FOCUSED!', COLORS.success)
      this.turnManager.endTurn()
    })
  }

  _animateReadinessFailure(timedOut, challengeType, correctAnswer) {
    // Negative animation: word shakes, flashes red, drops
    const word = this.readinessWord
    word.setColor('#e74c3c')

    this.tweens.add({
      targets: word,
      x: { from: word.x - 8, to: word.x + 8 },
      duration: 60,
      repeat: 5,
      yoyo: true,
      ease: 'Linear',
    })

    this.tweens.add({
      targets: word,
      y: word.y + 20,
      alpha: 0.3,
      duration: 500,
      ease: 'Quad.easeIn',
    })

    // Show "X" marks
    for (let i = 0; i < 3; i++) {
      const ox = word.x + (i - 1) * 40
      const oy = word.y - 50
      const xMark = this.add.text(ox, oy, '✕', {
        fontFamily: FONTS.default.fontFamily,
        fontSize: '24px',
        color: '#e74c3c',
      }).setOrigin(0.5).setAlpha(0)
      this.readinessOverlay.add(xMark)

      this.tweens.add({
        targets: xMark,
        alpha: { from: 0, to: 1 },
        scaleX: { from: 0.3, to: 1 },
        scaleY: { from: 0.3, to: 1 },
        duration: 150,
        delay: i * 80,
        ease: 'Back.easeOut',
        onComplete: () => {
          this.tweens.add({
            targets: xMark,
            alpha: 0,
            duration: 300,
            delay: 400,
            onComplete: () => xMark.destroy(),
          })
        },
      })
    }

    const msg = timedOut ? "Time's up!" : 'Wrong!'
    const answerLabel = challengeType === 'meaning' ? 'The meaning was' : 'The reading was'
    this.readinessPrompt.setText(`${msg} ${answerLabel}: ${correctAnswer || '?'}`)
    this.readinessPrompt.setColor('#e74c3c')

    this.time.delayedCall(5000, () => {
      this.readinessOverlay.setVisible(false)
      word.setColor('#ecf0f1')
      word.setAlpha(1)
      word.setScale(1)
      this.readinessPrompt.setColor('#ecf0f1')
      const logMsg = timedOut ? "Time's up! Readiness: Distracted..." : 'Wrong! Readiness: Distracted...'
      this.addCombatLog(logMsg)
      if (correctAnswer) {
        const logLabel = challengeType === 'meaning' ? 'Correct meaning' : 'Correct reading'
        this.addCombatLog(`${logLabel}: ${correctAnswer}`)
      }
      this.turnManager.endTurn()
    })
  }

  // ---------- Reaction Challenge (during enemy attacks) ----------

  roll2d6() {
    return Math.floor(Math.random() * 6) + 1 + Math.floor(Math.random() * 6) + 1
  }

  async runReactionChallenge() {
    return new Promise((resolve) => {
      const wordList = this.player.wordList
      if (!wordList || wordList.length === 0) {
        resolve()
        return
      }

      this.reactionResolve = resolve
      this.reactionChallengeActive = true
      this.challengeActive = true

      // Pick a random word
      const wordData = wordList[Math.floor(Math.random() * wordList.length)]
      this.currentReactionWord = wordData
      this.reactionInput = ''
      this.reactionStartTime = Date.now()
      this.reactionTimeLimit = 5000 // 5 seconds — quick reaction!

      // Alternate challenge type
      const hasMeaning = wordData.meaning && wordData.meaning.trim().length > 0
      this.reactionChallengeType = hasMeaning && Math.random() < 0.5 ? 'meaning' : 'reading'

      // Urgent styling — reset everything from previous challenges
      this.readinessTitle.setText('REACTION!')
      this.readinessTitle.setColor('#e74c3c')
      this.readinessWord.setText(wordData.word)
      this.readinessWord.setColor('#ecf0f1')
      this.readinessWord.setScale(1)
      this.readinessWord.setAlpha(1)
      this.readinessWord.setY(-15)

      if (this.reactionChallengeType === 'meaning') {
        this.readinessPrompt.setText('Quick! Type the meaning:')
        this.readinessHint.setText(wordData.reading || '')
      } else {
        this.readinessPrompt.setText('Quick! Type the reading:')
        this.readinessHint.setText(wordData.meaning || '')
      }
      this.readinessPrompt.setColor('#f39c12')

      this.readinessInputText.setText('')
      this.readinessTimerBar.setScale(1, 1)
      this.readinessTimerText.setText('5.0s')
      this.readinessOverlay.setVisible(true)

      // Focus hidden input for mobile keyboard
      if (this.hiddenInput) {
        this.hiddenInput.value = ''
        this.hiddenInput.focus()
      }
    })
  }

  updateReactionTimer() {
    if (!this.reactionChallengeActive) return
    const elapsed = Date.now() - this.reactionStartTime
    const remaining = Math.max(0, this.reactionTimeLimit - elapsed)
    const pct = remaining / this.reactionTimeLimit
    this.readinessTimerBar.setScale(pct, 1)
    this.readinessTimerText.setText((remaining / 1000).toFixed(1) + 's')

    if (remaining <= 0) {
      this.submitReactionChallenge(true)
    }
  }

  submitReactionChallenge(timedOut = false) {
    if (!this.reactionChallengeActive) return

    this.reactionChallengeActive = false
    this.challengeActive = false

    if (this.hiddenInput) {
      this.hiddenInput.blur()
    }

    const input = this.reactionInput.trim()
    const challengeType = this.reactionChallengeType || 'reading'
    const wordData = this.currentReactionWord

    let isCorrect = false
    let correctAnswer = ''
    if (challengeType === 'meaning') {
      correctAnswer = (wordData?.meaning || '').trim()
      isCorrect = !timedOut && input.length > 0 && input.toLowerCase() === correctAnswer.toLowerCase()
    } else {
      correctAnswer = (wordData?.reading || '').trim()
      isCorrect = !timedOut && input.length > 0 && input.toLowerCase() === correctAnswer.toLowerCase()
    }

    if (isCorrect) {
      this.player.reactionMultiplier = 2
      this.readinessWord.setColor('#2ecc71')
      this.readinessPrompt.setText('PARRY!')
      this.readinessPrompt.setColor('#2ecc71')
      this.spawnFloatingText(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 100, 'PARRY!', COLORS.success)
    } else {
      this.player.reactionMultiplier = 0.5
      this.readinessWord.setColor('#e74c3c')
      this.readinessPrompt.setText('Failed...')
      this.readinessPrompt.setColor('#e74c3c')
      this.spawnFloatingText(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 100, 'FAILED!', COLORS.danger)
    }

    // Brief delay so the player sees the feedback before the attack lands
    this.time.delayedCall(400, () => {
      this.readinessOverlay.setVisible(false)
      this.readinessWord.setColor('#ecf0f1')
      this.readinessPrompt.setColor('#ecf0f1')

      if (this.reactionResolve) {
        this.reactionResolve()
        this.reactionResolve = null
      }
    })
  }

  createIntentionIcons() {
    // Intention icons above enemy — shows predicted action plan at start of enemy turn
    this.intentionContainer = this.add.container(690, 58)
    this.intentionContainer.setDepth(50)
    this.intentionContainer.setVisible(false)

    this.intentionIcons = []
    const iconSize = 22
    const spacing = 28

    for (let i = 0; i < 3; i++) {
      const x = (i - 1) * spacing
      const bg = this.add.circle(x, 0, iconSize / 2, 0x2c3e50).setOrigin(0.5)
      const icon = this.add.text(x, 0, '', {
        fontFamily: FONTS.default.fontFamily,
        fontSize: '14px',
        color: '#ecf0f1',
      }).setOrigin(0.5)
      this.intentionContainer.add(bg)
      this.intentionContainer.add(icon)
      this.intentionIcons.push({ bg, icon })
    }
  }

  showIntentionPlan(plan) {
    if (!plan || plan.length === 0) {
      this.intentionContainer.setVisible(false)
      return
    }

    const ICON_MAP = {
      buff: { char: '⬆', color: 0xf39c12 },      // orange
      attack: { char: '⚔', color: 0xe74c3c },     // red
      defence: { char: '🛡', color: 0x3498db },   // blue
      defense: { char: '🛡', color: 0x3498db },   // blue (alias)
      recover: { char: '↩', color: 0x2ecc71 },    // green
      curse: { char: '⬇', color: 0x9b59b6 },     // purple
      debuff: { char: '⬇', color: 0x9b59b6 },    // purple
    }

    this.intentionIcons.forEach((slot, i) => {
      if (i < plan.length) {
        const action = plan[i]
        const info = ICON_MAP[action.type] || { char: '?', color: 0x7f8c8d }
        slot.bg.setFillStyle(info.color)
        slot.icon.setText(info.char)
        slot.bg.setVisible(true)
        slot.icon.setVisible(true)
      } else {
        slot.bg.setVisible(false)
        slot.icon.setVisible(false)
      }
    })

    this.intentionContainer.setVisible(true)

    // Subtle pop-in animation
    this.tweens.add({
      targets: this.intentionContainer,
      scaleX: { from: 0.6, to: 1 },
      scaleY: { from: 0.6, to: 1 },
      alpha: { from: 0, to: 1 },
      duration: 250,
      ease: 'Back.easeOut',
    })
  }

  hideIntentionIcons() {
    this.intentionContainer.setVisible(false)
  }

  createCombatLog() {
    this.combatLogBg = this.add.graphics()
    this.combatLogText = this.add.text(GAME_CONFIG.width / 2, 180, '', {
      ...FONTS.default,
      fontSize: '14px',
      align: 'center',
      wordWrap: { width: 500 },
    }).setOrigin(0.5)
  }

  drawCombatLogBg() {
    const text = this.combatLogText.text
    if (!text) {
      this.combatLogBg.clear()
      return
    }
    const metrics = this.combatLogText.getBounds()
    const padX = 16
    const padY = 10
    const w = Math.max(metrics.width + padX * 2, 200)
    const h = metrics.height + padY * 2
    const x = GAME_CONFIG.width / 2
    const y = 180
    const radius = 12
    this.combatLogBg.clear()
    this.combatLogBg.fillStyle(0x2c3e50, 0.75)
    this.combatLogBg.fillRoundedRect(x - w / 2, y - h / 2, w, h, radius)
    this.combatLogBg.lineStyle(1.5, 0x7f8c8d, 0.4)
    this.combatLogBg.strokeRoundedRect(x - w / 2, y - h / 2, w, h, radius)
  }

  // ---------- Interaction ----------

  handleKeyInput(event) {
    if (!this.challengeActive) return

    // Prevent browser find/search from intercepting typed keys
    event.preventDefault()

    // Reaction challenge (during enemy turn) takes priority
    if (this.reactionChallengeActive) {
      if (event.key === 'Backspace') {
        this.reactionInput = this.reactionInput.slice(0, -1)
      } else if (event.key === 'Enter') {
        this.submitReactionChallenge()
        return
      } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey) {
        this.reactionInput += event.key
      }
      this.readinessInputText.setText(this.reactionInput)
      return
    }

    // Readiness challenge uses its own input state
    if (this.readinessChallengeActive) {
      if (event.key === 'Backspace') {
        this.readinessInput = this.readinessInput.slice(0, -1)
      } else if (event.key === 'Enter') {
        this.submitReadinessChallenge()
        return
      } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey) {
        this.readinessInput += event.key
      }
      this.readinessInputText.setText(this.readinessInput)
      return
    }

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

    // Start readiness word challenge before ending turn
    this.startReadinessChallenge()
  }

  startChallenge(skill) {
    // Setup Defence can only be used once per turn — check before disabling UI
    if (skill.id === 'setup_defence' && this.player.setupDefenceUsed) {
      this.addCombatLog('Setup Defence already used this turn!')
      return
    }

    this.challengeActive = true
    this.selectedSkill = skill
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    // Forward Slash uses kanji drawing instead of typing
    if (skill.id === 'forward_slash') {
      const userData = getWindowGameData()
      const strokeData = userData?.weapon_kanji_strokes || { strokes: [] }

      if (!strokeData.strokes || strokeData.strokes.length === 0) {
        // Fallback: no stroke data, just execute
        this.challengeActive = false
        this.executeSkill('success')
        return
      }

      const gameData = getWindowGameData()
      const userLevel = gameData?.level || 1
      const hint = userLevel >= 10
        ? this.player.weapon.moveHints.forward_slash.ja
        : this.player.weapon.moveHints.forward_slash.en
      this.kanjiDrawing.start(strokeData, hint, {
        onComplete: (result) => {
          this.challengeActive = false
          this.setSkillButtonsEnabled(true)
          this.endTurnBtn.setVisible(true)

          // Store kanji result for damage calculation
          this.player.setKanjiResult(result.wrongStrokes)

          // Apply kanji bonus based on drawing quality
          if (result.completed) {
            if (result.wrongStrokes >= 3) {
              this.player.setKanjiBonus(1)
              this.addCombatLog('Chikara drawn! (+1 power, sloppy)')
            } else {
              this.player.setKanjiBonus(2)
              this.addCombatLog('Chikara drawn perfectly! (+2 power)')
            }
            this.executeSkill('success')
          } else {
            this.player.setKanjiBonus(0)
            this.addCombatLog('Chikara failed! No power bonus.')
            this.executeSkill('fail')
          }
        },
        onWrongStroke: ({ count }) => {
          this.spawnFloatingText(
            GAME_CONFIG.width / 2,
            GAME_CONFIG.height / 2 - 180,
            `Wrong stroke! (${count})`,
            COLORS.danger
          )
        },
      })
      return
    }

    // Setup Defence uses kanji drawing for shield (盾)
    if (skill.id === 'setup_defence') {
      const userData = getWindowGameData()
      const strokeData = userData?.shield_kanji_strokes || { strokes: [] }

      if (!strokeData.strokes || strokeData.strokes.length === 0) {
        this.challengeActive = false
        this.player.setupDefenceUsed = true
        this.executeSkill('success')
        return
      }

      const gameData = getWindowGameData()
      const userLevel = gameData?.level || 1
      const hint = userLevel >= 10
        ? this.player.shield.moveHint.ja
        : this.player.shield.moveHint.en
      this.kanjiDrawing.start(strokeData, hint, {
        onComplete: (result) => {
          this.challengeActive = false
          this.setSkillButtonsEnabled(true)
          this.endTurnBtn.setVisible(true)
          this.player.setupDefenceUsed = true

          if (result.completed) {
            this.player.setShieldBonus(3)
            this.player.addDefense(3)
            this.addCombatLog('Tate drawn! Shield fortified! (+3 DEF for this turn)')
            this.executeSkill('success')
          } else {
            this.addCombatLog('Tate failed! Shield not fortified.')
            this.executeSkill('fail')
          }
        },
        onWrongStroke: ({ count }) => {
          this.spawnFloatingText(
            GAME_CONFIG.width / 2,
            GAME_CONFIG.height / 2 - 180,
            `Wrong stroke! (${count})`,
            COLORS.danger
          )
        },
      })
      return
    }

    // Heal Potion and other skills still use typing challenge
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
    this.player.clearKanjiBonus()

    const quality = challengeResult === 'perfect' ? 'Perfect!' : challengeResult === 'success' ? '' : 'Failed...'
    switch (result.type) {
      case 'attack': {
        this.setPlayerSprite('player_sword_slash')
        const critText = result.isCrit ? ' CRITICAL!' : ''
        const bypassText = result.defenseBypassed ? ' (Defense pierced!)' : ''
        this.addCombatLog(`${quality} ${this.selectedSkill.name}${critText} -> ${result.damage} damage!${bypassText}`)
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
      // Reset per-turn flags
      this.player.setupDefenceUsed = false
      this.player.clearShieldBonus()
      this.player.resetReadiness()
      // Show what the enemy will do on its upcoming turn
      const plan = this.enemy.computeActionPlan()
      this.showIntentionPlan(plan)
    } else {
      this.turnText.setText('ENEMY TURN')
      this.turnText.setColor(COLORS.danger)
      this.animateTurnChange()
      this.setSkillButtonsEnabled(false)
      this.endTurnBtn.setVisible(false)
      // Hide intention icons while the enemy acts them out
      this.hideIntentionIcons()
      await this.runEnemyTurn()
    }
  }

  async runEnemyTurn() {
    await this.delay(800)

    let usedBuffThisTurn = false
    let actionsTaken = 0

    while (this.turnManager.currentTurn === 'enemy' && !this.turnManager.battleOver) {
      const action = this.enemy.chooseAction(usedBuffThisTurn)
      if (!action) break

      if (action.type === 'buff') usedBuffThisTurn = true
      actionsTaken++

      // Before an attack, check for reaction challenge trigger
      if (action.type === 'attack') {
        const diceRoll = this.roll2d6()
        const triggerChance = (this.player.luck * 0.1 * diceRoll) / 100
        if (Math.random() < triggerChance) {
          this.addCombatLog('Reaction opportunity!')
          await this.runReactionChallenge()
        }
      }

      const result = this.enemy.performAction(action, this.player)

      // Reset reaction multiplier after the attack resolves
      const reactionMult = this.player.reactionMultiplier
      this.player.reactionMultiplier = 1

      this.updateBars()
      this.updateBlockText()

      switch (result.type) {
        case 'attack': {
          this.setEnemySprite('enemy_kasa_obake_attack')
          if (result.missed) {
            const reactionText = reactionMult !== 1 ? (reactionMult > 1 ? ' (PARRY!)' : ' (Reaction failed...)') : ''
            this.addCombatLog(`Kasa-obake uses ${action.name}... but missed!${reactionText}`)
            this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, 'MISS', COLORS.warning)
          } else {
            this.setPlayerSprite('player_shield_block')
            const critText = result.isCrit ? ' CRITICAL!' : ''
            const reactionText = reactionMult !== 1 ? (reactionMult > 1 ? ' (PARRY!)' : ' (Reaction failed...)') : ''
            this.addCombatLog(`Kasa-obake uses ${action.name}${critText}! You take ${result.damage} damage!${reactionText}`)
            this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `-${result.damage}`, COLORS.danger)
            this.shakeSprite(this.playerSprite)
          }
          this.time.delayedCall(800, () => {
            this.setPlayerSprite('player_sword_shield')
            this.setEnemySprite('enemy_kasa_obake')
          })
          break
        }
        case 'buff': {
          this.setEnemySprite('enemy_kasa_obake_buff')
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

      // Decide if enemy takes another action
      if (!this.enemy.shouldContinueTurn(actionsTaken)) break
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
      // Setup Defence can only be used once per turn
      const setupDefenceUsed = skill.id === 'setup_defence' && this.player.setupDefenceUsed

      if (enabled && this.player.canUseSkill(skill) && !setupDefenceUsed) {
        btn.redraw(btn.color)
        btn.hitArea.setInteractive({ useHandCursor: true })
        btn.text.setAlpha(1)
      } else {
        btn.redraw(COLORS.buttonDisabled)
        btn.hitArea.disableInteractive()
        btn.text.setAlpha(0.6)
      }
    })

    // Item button: enabled if player has stamina for items (cost 1)
    const itemStaminaCost = 1
    if (enabled && this.player.stamina >= itemStaminaCost) {
      this.itemButton.redraw(this.itemButton.color)
      this.itemButton.hitArea.setInteractive({ useHandCursor: true })
      this.itemButton.text.setAlpha(1)
    } else {
      this.itemButton.redraw(COLORS.buttonDisabled)
      this.itemButton.hitArea.disableInteractive()
      this.itemButton.text.setAlpha(0.6)
    }
  }

  addCombatLog(msg) {
    this.combatLogText.setText(msg)
    this.drawCombatLogBg()
    // Reset alpha animation
    this.combatLogText.setAlpha(1)
    this.combatLogBg.setAlpha(1)
    this.tweens.add({
      targets: [this.combatLogText, this.combatLogBg],
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
    if (isWin) {
      this.setEnemySprite('enemy_kasa_obake_defeated')
    } else {
      this.setPlayerSprite('player_defeated')
    }

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

  shutdown() {
    // Clean up hidden input element
    if (this.hiddenInput && this.hiddenInput.parentNode) {
      this.hiddenInput.parentNode.removeChild(this.hiddenInput)
      this.hiddenInput = null
    }
    if (this.kanjiDrawing) {
      this.kanjiDrawing.destroy()
    }
  }
}
