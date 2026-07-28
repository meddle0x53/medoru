import { GAME_CONFIG, COLORS, FONTS } from '../config.js'
import { getEffect, EFFECT_CATEGORIES } from '../systems/EffectRegistry.js'
import Player from '../entities/Player.js'
import Enemy from '../entities/Enemy.js'
import TurnManager from '../systems/TurnManager.js'
import SocketProcSystem from '../systems/SocketProcSystem.js'
import ChallengeSystem from '../systems/ChallengeSystem.js'
import KanjiDrawingSystem from '../systems/KanjiDrawingSystem.js'
import WordChallengeSystem from '../systems/WordChallengeSystem.js'
import WeaponKanjiChallengeSystem from '../systems/WeaponKanjiChallengeSystem.js'
import { getActionTypeColor, getAbilityRarityColor, ALL_ACTIONS } from '../data/actions.js'
import { getHeroPose, HERO_DEFAULT_POSE } from '../data/heroPoses.js'
import { TILE_TYPES } from '../data/tileTypes.js'
import { getCharmById } from '../data/charms.js'
import { getSocketCharmById } from '../data/socketCharms.js'
import { getMapDefinition } from '../data/maps/index.js'

import { INFUSION_ICONS, resolveInfusionReaction, getElementForInfusion } from '../data/infusionReactions.js'

const STATUS_EFFECT_ICONS = {
  burn: '🔥',
  poison: '☠️',
  weak: '🌀',
  bleed: '🩸',
  blunt: '🪨',
  frost: '❄️',
  madness: '👁️',
  stamina_crash: '⚡',
  ember: '♨️',
  power_up: '💪',
  blind: '🌫️',
  fire_guard: '🛡️🔥',
  water_guard: '🛡️💧',
  wind_guard: '🛡️🌪',
  earth_guard: '🛡️🪨',
  void_guard: '🛡️🌑',
}

import { getWindowGameData, sendRunResult } from '../api.js'
import { ENEMY_DEFINITIONS, pickEnemyForTile, getEnemyDefinition } from '../data/enemies/index.js'
import { buildEnemyChallenge, filterChallengeWords } from '../systems/EnemyChallengePicker.js'
import EnemyAbilityChallengeSystem from '../systems/EnemyAbilityChallengeSystem.js'
import { setupHighDPIWorld } from '../highDpi.js'

export default class BattleScene extends Phaser.Scene {
  constructor() {
    super({ key: 'BattleScene' })
  }

  init(data) {
    this.tile = data.tile || null
    this.mapIndex = data.mapIndex ?? 0
  }

  create() {
    setupHighDPIWorld(this)
    const userData = getWindowGameData()
    const passedPlayer = this.scene.settings.data?.player
    this.player = passedPlayer || new Player(userData)
    this.player.buffs = [] // clear any lingering battle buffs from previous fight
    this.player.clearActiveEffects() // clear status effects from previous fight
    this.player.resetStanceMultipliers() // stance multipliers last one battle only
    this.player.resetDashBonus() // dash reflex bonus lasts one battle only
    this.player.resetTurnMissChance() // miss chance is per player turn
    this.player.resetBerserkLifesteal() // berserk lifesteal stacks one battle only
    this.player.resetForTurn() // start every battle with full stamina and clean per-turn state
    this.player.block = 0 // block from previous battle must not carry over
    this.player.tempDefense = 0 // setup defence from previous battle must not carry over
    this.player.clearAllAbilityInfusions() // infusions last for one battle only
    this.player.onCombatLog = (msg) => this.addCombatLog(msg)
    this.essenceGainedThisBattle = 0
    this.normalBattleEssenceAwarded = false
    this.enemies = this.createEnemiesForTile()
    for (const enemy of this.enemies) {
      enemy.onCombatLog = (msg) => this.addCombatLog(msg)
    }
    // Backwards-compatible alias for code not yet converted to the array.
    this.enemy = this.enemies[0]
    this.turnManager = new TurnManager(this.player, this.enemies, {
      onCombatLog: (msg) => this.addCombatLog(msg),
    })
    this.socketProcSystem = new SocketProcSystem(this.player)
    this.weaponKanjiChallenge = new WeaponKanjiChallengeSystem(this)
    this.challengeSystem = new ChallengeSystem(userData?.kanji_list)

    // Kanji drawing for weapon powerups (Forward Slash uses 力)
    this.kanjiDrawing = new KanjiDrawingSystem(
      this,
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      320,
      { offsetXPercent: -0.039 }
    )
    this.kanjiDrawing.setFocusKanjiData(this.player.loadout.focusKanjiData)

    this.turnManager.onTurnChange = (turn) => this.onTurnChange(turn)
    this.turnManager.onBattleEnd = (winner) => this.onBattleEnd(winner)

    this.challengeActive = false
    this.selectedSkill = null
    this.selectedTarget = null
    this.typedInput = ''
    this.currentChallenge = null
    this.particles = []

    this.targetingMode = false
    this.targetingCallback = null
    this.targetingPrompt = null
    this.targetingCancelBtn = null
    this.targetingHighlights = []

    this.pendingInfusion = null
    this.infusionPrompt = null
    this.infusionCancelBtn = null

    this.createBackground()
    this.createCharacters()
    this.createUI()
    this.createIntentionIcons()
    this.createChallengeOverlay()
    this.createWordChallenge()
    this.createItemMenu()
    this.createSwitchActionDialog()
    this.createCombatLog()

    this.input.keyboard.on('keydown', this.handleKeyInput, this)

    // Hidden input for mobile touch keyboard during word challenges
    this.hiddenInput = document.createElement('input')
    this.hiddenInput.type = 'text'
    this.hiddenInput.style.position = 'fixed'
    this.hiddenInput.style.opacity = '0'
    this.hiddenInput.style.pointerEvents = 'none'
    this.hiddenInput.style.bottom = '0px'
    this.hiddenInput.style.left = '0px'
    this.hiddenInput.style.width = '1px'
    this.hiddenInput.style.height = '1px'
    this.hiddenInput.style.border = 'none'
    this.hiddenInput.style.padding = '0'
    this.hiddenInput.style.margin = '0'
    this.hiddenInput.autocomplete = 'off'
    this.hiddenInput.autocapitalize = 'off'
    this.hiddenInput.autocorrect = 'off'
    this.hiddenInput.inputMode = 'text'
    document.body.appendChild(this.hiddenInput)

    // Keep overlay visible when mobile keyboard opens
    this._onVisualViewportResize = () => {
      if (this.wordChallengeActive) {
        window.scrollTo(0, 0)
        document.body.scrollTop = 0
        document.documentElement.scrollTop = 0
      }
    }
    if (window.visualViewport) {
      window.visualViewport.addEventListener('resize', this._onVisualViewportResize)
    }

    const enemyName = this.enemy.name || 'the enemy'
    const countText = this.enemies.length > 1 ? ` (${this.enemies.length})` : ''
    this.addCombatLog(`Battle start! Defeat ${enemyName}${countText}!`)
    this.socketProcSystem.trigger('on_battle_start', { scene: this })
    this.onTurnChange('player')
  }

  createEnemiesForTile() {
    let count = this.tile?.testFightCount
    if (count == null) {
      count = this.tile?.type === TILE_TYPES.MINI_BOSS ? 1 : this.determineEnemyCount()
    }
    const multiplier = count === 3 ? 0.5 : count === 2 ? 0.65 : 1.0

    const enemies = []
    for (let i = 0; i < count; i++) {
      const definition = this.tile?.enemyId
        ? getEnemyDefinition(this.tile.enemyId)
        : pickEnemyForTile(this.tile, this.mapIndex)
      const enemy = new Enemy(definition)
      if (multiplier !== 1.0) {
        enemy.maxHp = Math.max(1, Math.floor(enemy.maxHp * multiplier))
        enemy.hp = enemy.maxHp
      }
      enemies.push(enemy)
    }
    return enemies
  }

  determineEnemyCount() {
    const col = this.tile?.col ?? 1
    const mapIndex = this.mapIndex ?? 0

    // Clamp to the encounter columns; col 0 (home) and col 10 (boss) use late weights.
    const phaseCol = col >= 1 && col <= 9 ? col : 7

    // Map 1 (Japanese Fields) — gentler introduction.
    const map1 = {
      three: phaseCol >= 7 ? 0.20 : phaseCol >= 4 ? 0.08 : 0,
      two:   phaseCol >= 7 ? 0.50 : phaseCol >= 4 ? 0.15 : 0,
    }

    // Map 2+ — tougher.
    const map2 = {
      three: phaseCol >= 7 ? 0.50 : phaseCol >= 4 ? 0.25 : 0.10,
      two:   phaseCol >= 7 ? 0.75 : phaseCol >= 4 ? 0.50 : 0.20,
    }

    const chances = mapIndex >= 1 ? map2 : map1

    if (Math.random() < chances.three) return 3
    if (Math.random() < chances.two) return 2
    return 1
  }

  update(time, delta) {
    if (this.challengeActive && this.currentChallenge && !this.wordChallengeActive) {
      const elapsed = Date.now() - this.currentChallenge.startTime
      const pct = Math.max(0, 1 - elapsed / this.currentChallenge.timeLimit)
      this.challengeTimerBar.setScale(pct, 1)
      if (elapsed >= this.currentChallenge.timeLimit) {
        this.submitChallenge()
      }
    }

    // Charm overlays bob gently above the hero's head
    if (this.charmOverlays) {
      this.charmOverlays.forEach((overlay) => {
        const bob = Math.sin((time * 0.003) + overlay.bobPhase) * 3
        overlay.container.setPosition(overlay.baseX, overlay.baseY + bob)
      })
    }

    // Player status orb tracks the hero's head
    this.updatePlayerStatusButtonPosition(time)

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

  startKanjiDrawingChallenge(strokeData, hint, callbacks, kanjiData = null, drawingOptions = {}) {
    const wrappedCallbacks = { ...callbacks }
    wrappedCallbacks.onStart = (actualKanjiData) => {
      if (callbacks.onStart) callbacks.onStart(actualKanjiData)
      if (actualKanjiData) {
        const allKanji = getWindowGameData()?.all_kanji || []
        const full = allKanji.find(k => k.character === actualKanjiData.character) || actualKanjiData
        const meanings = (full.meanings || []).slice(0, 2).join(', ')
        const on = (full.on_readings || []).slice(0, 2).join(', ')
        const kun = (full.kun_readings || []).slice(0, 2).join(', ')
        this.addCombatLog(`Draw the kanji for ${meanings || '?'}, read ON: ${on || '-'}/KUN: ${kun || '-'}`)
      }
    }
    this.kanjiDrawing.start(strokeData, hint, wrappedCallbacks, kanjiData, drawingOptions)
  }

  /**
   * Resolve a parry-related kanji draw using the parry ability's kanji pool.
   * Follows the same rules as Forward Slash: 10% skip, 20% focus override,
   * stroke-tier fail threshold (half the strokes, rounded up), perfect/sloppy/fail.
   */
  resolveParryKanjiChallenge(skill, callbacks, hintPrefix = '') {
    const pool = skill.kanjiPool || ['受', '防', '守', '盾', '護', '弾', '反']

    // 10% chance to bypass the drawing challenge entirely.
    if (Math.random() < 0.1) {
      if (callbacks.onComplete) callbacks.onComplete({ quality: 'sloppy', skipped: true })
      return
    }

    let selectedKanjiData = null

    // 20% chance to use the current focus kanji instead of the pool.
    const focusKanjiData = this.player.loadout.focusKanjiData
    if (focusKanjiData && Math.random() < 0.2 && focusKanjiData.stroke_data?.strokes?.length > 0) {
      selectedKanjiData = focusKanjiData
    }

    if (!selectedKanjiData) {
      const allKanji = getWindowGameData()?.all_kanji || []
      const poolCandidates = pool
        .map(char => {
          const fromList = this.player.kanjiList.find(k => k.character === char)
          if (fromList?.stroke_data?.strokes?.length > 0) return fromList
          const fromAll = allKanji.find(k => k.character === char)
          if (fromAll?.stroke_data?.strokes?.length > 0) return fromAll
          return null
        })
        .filter(Boolean)
      if (poolCandidates.length > 0) {
        selectedKanjiData = poolCandidates[Math.floor(Math.random() * poolCandidates.length)]
      }
    }

    if (!selectedKanjiData || !selectedKanjiData.stroke_data?.strokes?.length) {
      if (callbacks.onComplete) callbacks.onComplete({ quality: 'sloppy', skipped: true })
      return
    }

    const strokeData = selectedKanjiData.stroke_data
    const totalStrokes = strokeData.strokes.length
    const failThreshold = Math.ceil(totalStrokes / 2)
    const hint = hintPrefix || 'Parry challenge!'

    this.startKanjiDrawingChallenge(strokeData, hint, {
      onComplete: (result) => {
        let quality = 'fail'
        if (result.completed && result.wrongStrokes < failThreshold) {
          quality = result.wrongStrokes === 0 ? 'perfect' : 'sloppy'
        }
        if (callbacks.onComplete) callbacks.onComplete({ quality, result, selectedKanjiData, totalStrokes, failThreshold })
      },
      onWrongStroke: callbacks.onWrongStroke || (() => {}),
    }, selectedKanjiData, { allowFocusOverride: false })
  }

  createCharacters() {
    // Player sprite — default battle stance (sword + shield)
    const startPose = getHeroPose(HERO_DEFAULT_POSE)
    this.playerSprite = this.add.sprite(300 + startPose.x, 580 + startPose.y, startPose.textureKey)
    this.playerSprite.setScale(0.30)
    this.playerSprite.setOrigin(0.5, 0.99) // Anchor near bottom so feet stay on ground
    // Feet on ground line (set via origin)
    // Smooth scaling for anime-style renders
    this.textures.get('player_sword_shield').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('player_sword_slash').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('player_heavy_slash').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('player_shield_block').setFilter(Phaser.Textures.FilterMode.LINEAR)
    this.textures.get('player_defeated').setFilter(Phaser.Textures.FilterMode.LINEAR)

    this.drawNameBg(300, 102)
    this.add.text(300, 95, this.player.name, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.add.text(300, 110, '戦士', { ...FONTS.kanji, fontSize: '14px' }).setOrigin(0.5)

    // Charm overlays: small luminous kanji floating above the hero's head
    this.createCharmOverlays()

    // Green status orb above the hero: shows temporary defence / block / buffs
    this.createPlayerStatusButton()

    // Enemies rendered in a horizontal row on the right; scale down when there are more.
    this.enemyDisplays = this.enemies.map((enemy, i) => this.createEnemyDisplay(enemy, i, this.enemies.length))
    // Backwards-compatible alias for code paths still using the single enemy sprite.
    this.enemySprite = this.enemyDisplays[0]?.sprite || null
  }

  createEnemyDisplay(enemy, index, total) {
    const layout = enemy.definition.layout[String(total)]?.[index] || { x: 690, y: 570, scale: 0.30 }
    const { x, y, scale } = layout

    // Create the display object first so callbacks can reference it.
    const display = { enemy, x }

    // Ensure all of this enemy's sprites are rendered smoothly.
    const spriteKeys = Object.values(enemy.definition.sprites).filter(Boolean)
    for (const key of spriteKeys) {
      if (this.textures.exists(key)) {
        this.textures.get(key).setFilter(Phaser.Textures.FilterMode.LINEAR)
      }
    }

    const defaultKey = enemy.definition.sprites.default
    display.sprite = this.add.sprite(x, y, defaultKey)
    display.sprite.setScale(scale)
    display.sprite.setOrigin(0.5, 0.99)
    display.sprite.setInteractive({ useHandCursor: false })
    if (enemy.definition.tint) {
      display.sprite.setTint(parseInt(enemy.definition.tint, 16))
    }
    display.sprite.on('pointerdown', () => this.onEnemySpriteClick(display))

    const nameTagWidth = total === 3 ? 130 : total === 2 ? 150 : 180
    const nameFontSize = total === 3 ? '12px' : '14px'
    display.nameBg = this.drawNameBg(x, 102, nameTagWidth)
    display.nameText = this.add.text(x, 95, enemy.name, { ...FONTS.default, fontSize: nameFontSize }).setOrigin(0.5)
    display.jaText = this.add.text(x, 110, enemy.nameJa, { ...FONTS.kanji, fontSize: nameFontSize }).setOrigin(0.5)

    // Per-enemy HP/stamina bars
    const barW = 100
    const barH = 12
    const hpY = 500
    const staminaY = 517
    display.hpBg = this.add.rectangle(x, hpY, barW, barH, 0xe0e0e0).setOrigin(0.5)
    display.hpBar = this.add.rectangle(x - barW / 2, hpY, barW, barH, COLORS.hp).setOrigin(0, 0.5)
    display.staminaBg = this.add.rectangle(x, staminaY, barW, barH, 0xe0e0e0).setOrigin(0.5)
    display.staminaBar = this.add.rectangle(x - barW / 2, staminaY, barW, barH, COLORS.stamina).setOrigin(0, 0.5)

    display.hpText = this.add.text(x, hpY, `${enemy.hp}/${enemy.maxHp}`, { ...FONTS.default, fontSize: '11px', color: '#1a1a2e' }).setOrigin(0.5)
    display.staminaText = this.add.text(x, staminaY, `${enemy.stamina}/${enemy.maxStamina}`, { ...FONTS.default, fontSize: '11px', color: '#1a1a2e' }).setOrigin(0.5)
    display.blockText = this.add.text(x, 485, '', { ...FONTS.default, fontSize: '11px', color: '#3498db' }).setOrigin(0.5)

    // Intention button: red "!" circle that opens a detailed intention bubble
    display.intentionBtn = this.add.container(x, 150).setDepth(50).setVisible(false)
    const intentionBtnBg = this.add.circle(0, 0, 14, 0x8b0000).setStrokeStyle(2, 0xe74c3c)
    const intentionBtnIcon = this.add.text(0, 0, '!', {
      fontFamily: FONTS.default.fontFamily,
      fontSize: '18px',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5)
    display.intentionBtn.add([intentionBtnBg, intentionBtnIcon])
    const intentionBtnHit = this.add.circle(0, 0, 18, 0x000000, 0)
      .setInteractive({ useHandCursor: true })
    display.intentionBtn.add(intentionBtnHit)
    intentionBtnHit.on('pointerdown', () => this.toggleIntentionBubble(display))

    // Status effect icons above this enemy
    display.statusContainer = this.add.container(x, y - display.sprite.displayHeight * 0.95)
    display.statusContainer.setDepth(60)
    display.statusContainer.setVisible(false)

    display.baseScale = scale
    display.intentionBubble = null

    return display
  }

  setPlayerPose(poseKey) {
    const pose = getHeroPose(poseKey)
    this.playerSprite.setTexture(pose.textureKey)
    this.playerSprite.setPosition(300 + pose.x, 580 + pose.y)
    // Keep charm overlays tracking the head position after pose change
    this.updateCharmOverlayPositions()
  }

  // ---------- Charm Visuals ----------

  createCharmOverlays() {
    this.charmOverlays = []
    const charms = this.player.getEquippedCharms()

    charms.forEach((charm, index) => {
      const overlay = this.createSingleCharmOverlay(charm, index, charms.length)
      this.charmOverlays.push(overlay)
    })

    this.updateCharmOverlayPositions()
  }

  createSingleCharmOverlay(charm, index, total) {
    const colorHex = '#' + charm.color.toString(16).padStart(6, '0')
    const container = this.add.container(0, 0)

    // Glow: multiple blurred backing layers to simulate luminance
    const glowLayers = 3
    for (let i = glowLayers; i > 0; i--) {
      const glow = this.add.text(0, 0, charm.kanji, {
        fontFamily: FONTS.kanji.fontFamily,
        fontSize: '20px',
        color: colorHex,
        stroke: colorHex,
        strokeThickness: i * 2,
      }).setOrigin(0.5)
      glow.setAlpha(0.35)
      container.add(glow)
    }

    // Core kanji
    const core = this.add.text(0, 0, charm.kanji, {
      fontFamily: FONTS.kanji.fontFamily,
      fontSize: '20px',
      color: '#ffffff',
      stroke: colorHex,
      strokeThickness: 2,
    }).setOrigin(0.5)
    container.add(core)

    return { container, charm, index, total, baseX: 0, baseY: 0, bobPhase: index * 1.2 }
  }

  updateCharmOverlayPositions() {
    if (!this.charmOverlays || !this.playerSprite) return

    const baseX = this.playerSprite.x
    // Position above the hero's head; tune this if sprites have different head heights
    const baseY = this.playerSprite.y - (this.playerSprite.height * 0.30 * 0.95)

    const spacing = 26
    const total = this.charmOverlays.length
    const startX = baseX - ((total - 1) * spacing) / 2

    this.charmOverlays.forEach((overlay, index) => {
      overlay.baseX = startX + index * spacing
      overlay.baseY = baseY
    })
  }

  // Refresh overlays when charms change (e.g. UI equip/unequip)
  refreshCharmOverlays() {
    if (this.charmOverlays) {
      this.charmOverlays.forEach(({ container }) => container.destroy())
    }
    this.charmOverlays = []
    this.createCharmOverlays()
  }

  // ---------- Player Status Orb (defence / block / buffs) ----------

  createPlayerStatusButton() {
    const btn = this.add.container(0, 0).setDepth(66).setVisible(false)

    const bg = this.add.circle(0, 0, 14, 0x1e8449).setStrokeStyle(2, 0x145a32)
    const text = this.add.text(0, 0, '', {
      ...FONTS.default,
      fontSize: '11px',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5)

    btn.add([bg, text])

    const hit = this.add.circle(0, 0, 18, 0x000000, 0)
      .setInteractive({ useHandCursor: true })
    btn.add(hit)
    hit.on('pointerdown', () => this.togglePlayerStatusBubble())

    this.playerStatusBtn = btn
    this.playerStatusValueText = text
    this.updatePlayerStatusButton()
  }

  updatePlayerStatusButton() {
    if (!this.playerStatusBtn) return

    const tempDef = this.player.tempDefense || 0
    const block = this.player.block || 0
    const hasBuffs = (this.player.buffs?.length > 0) || (this.player.activeEffects?.length > 0)
    const parryCharges = this.player.parryCharges?.length || 0
    const visible = tempDef > 0 || block > 0 || hasBuffs || parryCharges > 0

    this.playerStatusBtn.setVisible(visible)
    if (!visible) {
      this.closePlayerStatusBubble()
      return
    }

    let value
    if (parryCharges > 0) {
      value = parryCharges
    } else if (tempDef > 0) {
      value = tempDef
    } else {
      value = block
    }
    this.playerStatusValueText.setText(String(value))
    this.playerStatusValueText.setFontSize(value >= 100 ? '9px' : '11px')
  }

  updatePlayerStatusButtonPosition(time) {
    if (!this.playerStatusBtn || !this.playerSprite) return

    // Position right below the hero's name tag, matching the enemy intention-button level.
    const baseX = this.playerSprite.x
    const baseY = 150
    const bob = Math.sin(time * 0.003) * 2
    this.playerStatusBtn.setPosition(baseX, baseY + bob)
  }

  togglePlayerStatusBubble() {
    if (this.playerStatusBubble && this.playerStatusBubble.active) {
      this.closePlayerStatusBubble()
    } else {
      this.openPlayerStatusBubble()
    }
  }

  openPlayerStatusBubble() {
    this.closePlayerStatusBubble()

    const rows = []
    const tempDef = this.player.tempDefense || 0
    const block = this.player.block || 0
    const armor = this.player.armor || 0
    const readiness = this.player.readiness || 0

    if (tempDef > 0) rows.push({ label: 'Defence', value: tempDef, color: '#2ecc71' })
    if (block > 0) rows.push({ label: 'Block', value: block, color: '#3498db' })
    if (armor > 0) rows.push({ label: 'Armor', value: armor, color: '#f39c12' })
    rows.push({ label: 'Readiness', value: `${Math.round(readiness * 100)}%`, color: '#9b59b6' })

    const outgoingStance = this.player.stanceOutgoingMultiplier || 1
    const incomingStance = this.player.stanceIncomingMultiplier || 1
    if (outgoingStance !== 1 || incomingStance !== 1) {
      rows.push({
        label: 'Stance',
        value: `x${outgoingStance.toFixed(2)} / x${incomingStance.toFixed(2)}`,
        color: '#e67e22',
      })
    }

    const dashBonus = this.player.dashBonusPerAbility || 0
    if (dashBonus > 0) {
      rows.push({
        label: 'Dash',
        value: `+${(dashBonus * 100).toFixed(0)}% / ability`,
        color: '#2ecc71',
      })
    }
    const turnMiss = this.player.turnMissChance || 0
    if (turnMiss > 0) {
      rows.push({
        label: 'Enemy miss',
        value: `${(turnMiss * 100).toFixed(0)}%`,
        color: '#2ecc71',
      })
    }

    const berserkPercent = this.player.berserkLifestealPercent || 0
    if (berserkPercent > 0) {
      rows.push({
        label: 'Berserk',
        value: `${berserkPercent.toFixed(0)}% lifesteal`,
        color: '#f1c40f',
      })
    }

    for (const buff of this.player.buffs || []) {
      rows.push({ label: 'Buff', value: buff.type, color: '#9b59b6' })
    }
    for (const effect of this.player.activeEffects || []) {
      const name = getEffect(effect.effectId)?.name || effect.effectId
      rows.push({ label: 'Effect', value: name, color: '#e74c3c' })
    }

    const parryCharges = this.player.parryCharges || []
    if (parryCharges.length > 0) {
      const labels = parryCharges.map(q => q === 'perfect' ? 'P' : q === 'sloppy' ? 'S' : 'W')
      rows.push({ label: 'Parry', value: `${parryCharges.length} [${labels.join(',')}]`, color: '#9b59b6' })
    }

    if (rows.length === 0) return

    const width = 180
    const rowHeight = 22
    const padding = 14
    const height = padding * 2 + 18 + rows.length * rowHeight
    const x = this.playerStatusBtn.x
    const y = this.playerStatusBtn.y - height / 2 - 20

    const container = this.add.container(x, y).setDepth(70)

    const bg = this.add.graphics()
    bg.fillStyle(0x1a1a2e, 0.96)
    bg.lineStyle(2, 0x1e8449, 0.9)
    bg.fillRoundedRect(-width / 2, -height / 2, width, height, 12)
    bg.strokeRoundedRect(-width / 2, -height / 2, width, height, 12)
    container.add(bg)

    const title = this.add.text(0, -height / 2 + 16, 'Status', {
      ...FONTS.default,
      fontSize: '12px',
      color: '#1e8449',
      fontStyle: 'bold',
    }).setOrigin(0.5)
    container.add(title)

    rows.forEach((row, i) => {
      const rowY = -height / 2 + 34 + i * rowHeight
      const label = this.add.text(-width / 2 + 12, rowY, `${row.label}:`, {
        ...FONTS.default,
        fontSize: '12px',
        color: '#bdc3c7',
      }).setOrigin(0, 0.5)
      const value = this.add.text(width / 2 - 12, rowY, String(row.value), {
        ...FONTS.default,
        fontSize: '12px',
        color: row.color,
        fontStyle: 'bold',
      }).setOrigin(1, 0.5)
      container.add([label, value])
    })

    this.playerStatusBubble = container

    this.playerStatusBubbleBackdrop = this.add.rectangle(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      GAME_CONFIG.width,
      GAME_CONFIG.height,
      0x000000,
      0.01
    )
      .setDepth(60)
      .setInteractive()
    this.playerStatusBubbleBackdrop.on('pointerdown', () => this.closePlayerStatusBubble())
  }

  closePlayerStatusBubble() {
    if (this.playerStatusBubble) {
      this.playerStatusBubble.destroy()
      this.playerStatusBubble = null
    }
    if (this.playerStatusBubbleBackdrop) {
      this.playerStatusBubbleBackdrop.destroy()
      this.playerStatusBubbleBackdrop = null
    }
  }

  setEnemySprite(key, enemy = null) {
    const display = enemy
      ? this.enemyDisplays.find(d => d.enemy === enemy)
      : this.enemyDisplays[0]
    if (display?.sprite) {
      display.sprite.setTexture(key)
    }
  }

  getEnemySpriteKey(enemy, pose) {
    const current = typeof enemy.getCurrentSprites === 'function'
      ? enemy.getCurrentSprites()
      : null
    const sprites = current || enemy.definition.sprites || {}
    return sprites[pose] || sprites.default || enemy.definition.sprites.default
  }

  refreshEnemyDisplay(display) {
    if (!display || !display.enemy) return
    const enemy = display.enemy
    display.nameText.setText(enemy.name)
    display.jaText.setText(enemy.nameJa)
    const key = this.getEnemySpriteKey(enemy, 'default')
    if (display.sprite.texture.key !== key) {
      display.sprite.setTexture(key)
    }
    if (enemy.definition.tint) {
      display.sprite.setTint(parseInt(enemy.definition.tint, 16))
    } else {
      display.sprite.clearTint()
    }
  }

  createSummonedEnemies(result) {
    const enemies = []
    for (let i = 0; i < (result.summonCount || 1); i++) {
      const pool = result.summonIds || []
      const id = pool[Math.floor(Math.random() * pool.length)]
      const def = getEnemyDefinition(id)
      if (!def) continue
      const enemy = new Enemy(def)
      if (result.summonHpMultiplier != null) {
        enemy.maxHp = Math.max(1, Math.floor(enemy.maxHp * result.summonHpMultiplier))
        enemy.hp = enemy.maxHp
      }
      enemies.push(enemy)
    }
    return enemies
  }

  relayoutEnemyDisplays() {
    // Only layout living enemies; dead displays stay where they are (invisible).
    const aliveDisplays = this.enemyDisplays.filter(d => d.enemy.isAlive())
    const total = aliveDisplays.length
    const masterLayout = aliveDisplays[0]?.enemy.definition.layout[String(total)]
    for (let i = 0; i < total; i++) {
      const display = aliveDisplays[i]
      const layout = masterLayout?.[i]
        || display.enemy.definition.layout[String(total)]?.[i]
        || display.enemy.definition.layout['1']?.[0]
        || { x: 660 + i * 100, y: 470, scale: 0.12 }
      display.x = layout.x
      display.sprite.setPosition(layout.x, layout.y)
      display.sprite.setScale(layout.scale)
      if (display.enemy.definition.tint) {
        display.sprite.setTint(parseInt(display.enemy.definition.tint, 16))
      }
      display.nameBg.setPosition(layout.x, 102)
      display.nameText.setPosition(layout.x, 95)
      display.jaText.setPosition(layout.x, 110)
      display.hpBg.setPosition(layout.x, 500)
      display.hpBar.setPosition(layout.x - 50, 500)
      display.staminaBg.setPosition(layout.x, 517)
      display.staminaBar.setPosition(layout.x - 50, 517)
      display.hpText.setPosition(layout.x, 500)
      display.staminaText.setPosition(layout.x, 517)
      display.blockText.setPosition(layout.x, 485)
      if (display.intentionBtn) display.intentionBtn.setPosition(layout.x, 150)
      if (display.intentionBubble) this.repositionIntentionBubble(display)
      display.statusContainer.setPosition(layout.x, layout.y - display.sprite.displayHeight * 0.95)
    }
  }

  transformEnemy(enemy, result) {
    const def = result.transformDef
    if (!def) return
    const transformed = new Enemy(def)
    const keepRatio = result.keepHpRatio !== false
    const hpRatio = keepRatio ? enemy.hp / Math.max(1, enemy.maxHp) : 1

    enemy.definition = def
    enemy.currentSprites = transformed.currentSprites
    enemy.name = transformed.name
    enemy.nameJa = transformed.nameJa
    enemy.maxHp = transformed.maxHp
    enemy.hp = keepRatio ? Math.max(1, Math.floor(enemy.maxHp * hpRatio)) : transformed.hp
    enemy.maxStamina = transformed.maxStamina
    enemy.stamina = Math.min(enemy.stamina, enemy.maxStamina)
    enemy.strength = transformed.strength
    enemy.skill = transformed.skill
    enemy.mana = transformed.mana
    enemy.luck = transformed.luck
    enemy.defense = transformed.defense
    enemy.armor = transformed.armor
    enemy.abilities = transformed.abilities
    enemy.phases = []
    enemy.phaseIndex = 0
    enemy.phaseModifiers = {}
    enemy.phaseAbilityOverrides = {}
    enemy.resetAbilityUses()

    this.refreshEnemyDisplay(this.getDisplayForEnemy(enemy))
    this.updateBars()
  }

  onEnemySpriteClick(display) {
    if (!this.targetingMode) return
    if (!display.enemy.isAlive()) return
    const callback = this.targetingCallback
    this.clearTargetMode()
    if (callback) callback(display.enemy)
  }

  enterTargetMode(callback, prompt = 'Select a target') {
    if (this.targetingMode) return
    this.targetingMode = true
    this.targetingCallback = callback

    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    this.targetingPrompt = this.add.text(GAME_CONFIG.width / 2, 32, prompt, {
      ...FONTS.title,
      fontSize: '16px',
      color: '#f1c40f',
    }).setOrigin(0.5).setDepth(60)

    this.targetingCancelBtn = this.createButton(GAME_CONFIG.width / 2, 70, 'Cancel', () => this.clearTargetMode(), 120, 36, 0x7f8c8d, 0x95a5a6)
    this.targetingCancelBtn.text.setDepth(61)
    this.targetingCancelBtn.bg.setDepth(61)
    this.targetingCancelBtn.hitArea.setDepth(61)
    if (this.targetingCancelBtn.shadow) this.targetingCancelBtn.shadow.setDepth(60)

    this.targetingHighlights = []
    for (const display of this.enemyDisplays) {
      if (!display.enemy.isAlive()) continue
      display.sprite.setInteractive({ useHandCursor: true })

      // Full-enemy clickable target zone so tapping anywhere on the enemy/bars works.
      const displayHeight = display.sprite.displayHeight || 120
      const zoneW = 120
      const zoneH = displayHeight + 70
      const zoneY = display.sprite.y - zoneH / 2 + 10

      const hitZone = this.add.rectangle(display.x, zoneY, zoneW, zoneH, 0xe74c3c, 0)
      hitZone.setOrigin(0.5)
      hitZone.setDepth(99)
      hitZone.setInteractive({ useHandCursor: true })
      hitZone.on('pointerdown', () => this.onEnemySpriteClick(display))
      this.targetingHighlights.push(hitZone)

      // Visible pulsing ring centered on the enemy.
      const ringY = display.sprite.y - displayHeight * 0.45
      const ringRadius = Math.max(48, Math.min(70, Math.round(displayHeight * 0.45)))
      const ring = this.add.circle(display.x, ringY, ringRadius, 0xe74c3c, 0.12)
      ring.setOrigin(0.5)
      ring.setStrokeStyle(3, 0xe74c3c)
      ring.setDepth(100)
      this.targetingHighlights.push(ring)

      this.tweens.add({
        targets: ring,
        alpha: { from: 0.9, to: 0.35 },
        duration: 500,
        yoyo: true,
        repeat: -1,
      })
    }
  }

  clearTargetMode() {
    if (!this.targetingMode) return
    this.targetingMode = false
    this.targetingCallback = null

    if (this.targetingPrompt) {
      this.targetingPrompt.destroy()
      this.targetingPrompt = null
    }
    if (this.targetingCancelBtn) {
      this.targetingCancelBtn.bg.destroy()
      this.targetingCancelBtn.text.destroy()
      this.targetingCancelBtn.hitArea.destroy()
      if (this.targetingCancelBtn.shadow) this.targetingCancelBtn.shadow.destroy()
      this.targetingCancelBtn = null
    }

    for (const ring of this.targetingHighlights) {
      ring.destroy()
    }
    this.targetingHighlights = []

    for (const display of this.enemyDisplays) {
      if (display.enemy.isAlive()) {
        display.sprite.setInteractive({ useHandCursor: false })
      } else {
        display.sprite.disableInteractive()
      }
    }

    if (this.turnManager.currentTurn === 'player' && !this.challengeActive) {
      this.setSkillButtonsEnabled(true)
      this.endTurnBtn.setVisible(true)
    }
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

    // Action panel — modern rounded glass panel behind hero sprite
    this.actionPanel = this.createModernPanel(120, 305, 180, 360, 16)

    // TEMPORARY: Win Battle button for testing the reward loop (hidden on boss tiles)
    this.winBattleBtn = this.createButton(120, 95, 'Win Battle', () => {
      this.scene.start('WinScene', { player: this.player, enemy: this.enemies[0], tile: this.tile })
    }, 160, 36, 0x27ae60, 0x2ecc71)

    this.skillButtons = []
    // All active actions get a button (parry is passive but shown)
    const clickableActions = this.player.activeActions
    clickableActions.forEach((action, i) => {
      const y = 155 + i * 44
      const colors = getAbilityRarityColor(action.rarity)
      const label = this.getSkillButtonLabel(action)
      const btn = this.createButton(120, y, label, () => this.onSkillClick(action), 160, 40, colors.main, colors.hover)
      this.skillButtons.push({ btn, skill: action })
    })

    // Switch Action button
    const switchY = 155 + clickableActions.length * 44 + 8
    this.switchActionBtn = this.createButton(120, switchY, 'Switch Action (1)', () => this.onSwitchActionClick(), 160, 40, 0x2980b9, 0x3498db)

    // End turn button — fixed at the bottom of the action panel
    this.endTurnBtn = this.createButton(120, 513, 'End Turn', () => this.onEndTurn(), 160, 40, 0xe67e22, 0xf39c12)

    // Block indicators
    this.playerBlockText = this.add.text(300, 485, '', { ...FONTS.default, fontSize: '12px', color: '#3498db' }).setOrigin(0.5)

    // Player status effect icons
    this.playerStatusContainer = this.add.container(300, 470)
    this.playerStatusContainer.setDepth(60)
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

  drawNameBg(x, y, w = 180) {
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

  createWordChallenge() {
    this.wordChallengeActive = false
    this.wordChallenge = new WordChallengeSystem(this, {
      title: 'End Turn Challenge',
      promptForMeaning: 'Type the meaning of this word:',
      timeLimit: 10000,
      hangOnWrong: 5000,
    })
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
    const activeItemIds = this.player.loadout?.activeItemIds || []
    const inventory = this.player.loadout?.inventory || {}
    const items = (this.player.inventory || []).filter(
      item => activeItemIds.includes(item.id) && (inventory[item.id] || 0) > 0,
    )
    if (items.length === 0) {
      this.addCombatLog('No active items equipped!')
      return
    }

    this.challengeActive = true
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    this.itemMenuRows.forEach((row, i) => {
      if (i < items.length) {
        const item = items[i]
        const canAfford = this.player.stamina >= item.staminaCost
        const count = inventory[item.id] || 0
        row.icon.setText(item.icon)
        row.name.setText(`${item.name} x${count} (${item.staminaCost} STA)`)
        row.desc.setText(item.description)
        row.bg.setVisible(true)
        row.icon.setVisible(true)
        row.name.setVisible(true)
        row.desc.setVisible(true)
        row.hitArea.setVisible(true)
        if (canAfford) {
          row.hitArea.setInteractive({ useHandCursor: true })
          row.hitArea.off('pointerdown')
          row.hitArea.on('pointerdown', () => this.onItemSelect(item))
          row.bg.setFillStyle(0x1a1a2e)
          row.hitArea.on('pointerover', () => row.bg.setFillStyle(0x27ae60))
          row.hitArea.on('pointerout', () => row.bg.setFillStyle(0x1a1a2e))
          row.name.setAlpha(1)
          row.desc.setAlpha(1)
          row.icon.setAlpha(1)
        } else {
          row.hitArea.disableInteractive()
          row.bg.setFillStyle(0x2c2c3a)
          row.name.setAlpha(0.4)
          row.desc.setAlpha(0.4)
          row.icon.setAlpha(0.4)
        }
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

  // ---------- Switch Action Dialog ----------

  createSwitchActionDialog() {
    this.switchDialogOverlay = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    this.switchDialogOverlay.setDepth(100)
    this.switchDialogOverlay.setVisible(false)

    // Dark backdrop
    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.7).setOrigin(0.5)
    backdrop.setInteractive()
    this.switchDialogOverlay.add(backdrop)

    // Panel
    const panel = this.add.rectangle(0, 0, 460, 520, COLORS.panelBg).setStrokeStyle(2, 0x3498db)
    this.switchDialogOverlay.add(panel)

    // Title
    this.switchDialogTitle = this.add.text(0, -240, 'Switch Actions', { ...FONTS.title, fontSize: '20px', color: '#3498db' }).setOrigin(0.5)
    this.switchDialogOverlay.add(this.switchDialogTitle)

    // Active section label
    this.switchDialogActiveLabel = this.add.text(-200, -205, 'ACTIVE', { ...FONTS.default, fontSize: '13px', color: '#2ecc71' }).setOrigin(0, 0)
    this.switchDialogOverlay.add(this.switchDialogActiveLabel)

    // Inactive section label
    this.switchDialogInactiveLabel = this.add.text(-200, 70, 'INACTIVE', { ...FONTS.default, fontSize: '13px', color: '#7f8c8d' }).setOrigin(0, 0)
    this.switchDialogOverlay.add(this.switchDialogInactiveLabel)

    // Action card rows
    this.switchDialogActiveRows = []
    this.switchDialogInactiveRows = []

    for (let i = 0; i < 6; i++) {
      // Active rows (top, up to 6)
      const activeY = -175 + i * 40
      const activeRow = this._createActionCard(0, activeY)
      this.switchDialogActiveRows.push(activeRow)
      this.switchDialogOverlay.add(activeRow.container)

      // Inactive rows (bottom, up to 6)
      const inactiveY = 100 + i * 40
      const inactiveRow = this._createActionCard(0, inactiveY)
      this.switchDialogInactiveRows.push(inactiveRow)
      this.switchDialogOverlay.add(inactiveRow.container)
    }

    // Hint text
    this.switchDialogHint = this.add.text(0, 245, 'Click an inactive action, then an active one to swap.', { ...FONTS.default, fontSize: '11px', color: '#7f8c8d' }).setOrigin(0.5)
    this.switchDialogOverlay.add(this.switchDialogHint)

    // Close button
    const closeBtn = this.createButton(0, 260, 'Close', () => this.hideSwitchActionDialog(), 120, 36, 0x7f8c8d, 0x95a5a6)
    this.switchDialogCloseBtn = closeBtn
    this.switchDialogOverlay.add(closeBtn.bg)
    this.switchDialogOverlay.add(closeBtn.shadow)
    this.switchDialogOverlay.add(closeBtn.hitArea)
    this.switchDialogOverlay.add(closeBtn.text)

    this.switchDialogSelectedInactive = null
  }

  _createActionCard(x, y) {
    const container = this.add.container(x, y)
    const bg = this.add.rectangle(0, 0, 400, 46, 0x1a1a2e).setStrokeStyle(1, 0x7f8c8d).setOrigin(0.5)
    const typeIcon = this.add.text(-180, 0, '', { ...FONTS.default, fontSize: '16px' }).setOrigin(0.5)
    const name = this.add.text(-150, -6, '', { ...FONTS.default, fontSize: '14px' }).setOrigin(0, 0.5)
    const meta = this.add.text(-150, 10, '', { ...FONTS.default, fontSize: '11px', color: '#7f8c8d' }).setOrigin(0, 0.5)
    const stamina = this.add.text(170, 0, '', { ...FONTS.default, fontSize: '13px' }).setOrigin(0.5)
    const hitArea = this.add.rectangle(0, 0, 400, 46, 0x000000, 0).setOrigin(0.5)

    container.add(bg)
    container.add(typeIcon)
    container.add(name)
    container.add(meta)
    container.add(stamina)
    container.add(hitArea)

    return { container, bg, typeIcon, name, meta, stamina, hitArea }
  }

  showSwitchActionDialog() {
    if (this.challengeActive) return
    if (this.turnManager.currentTurn !== 'player') return
    if (this.player.stamina < 1) {
      this.addCombatLog('Not enough stamina to switch actions!')
      return
    }

    this.challengeActive = true
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)
    this.switchDialogSelectedInactive = null

    this.renderSwitchDialog()
    this.switchDialogOverlay.setVisible(true)
  }

  hideSwitchActionDialog() {
    this.switchDialogOverlay.setVisible(false)
    this.challengeActive = false
    this.setSkillButtonsEnabled(true)
    this.endTurnBtn.setVisible(true)
    this.switchDialogSelectedInactive = null
  }

  renderSwitchDialog() {
    const maxActive = this.player.maxActiveSlots
    const combatActive = this.player.activeActions.filter(a => a.id !== 'use_item')
    const activeCount = combatActive.length
    this.switchDialogTitle.setText(`Switch Actions (${activeCount}/${maxActive})`)

    const TYPE_ICONS = {
      attack: '⚔',
      defence: '🛡',
      parry: '🔄',
      heal: '💚',
      item: '🎒',
    }

    // Render active rows (Use Item is always available and not swappable)
    const combatInactive = this.player.inactiveActions.filter(a => a.id !== 'use_item')
    this.switchDialogActiveRows.forEach((row, i) => {
      const action = combatActive[i]
      if (action) {
        row.container.setVisible(true)
        row.typeIcon.setText(TYPE_ICONS[action.type] || '?')
        row.name.setText(action.name)
        const typeLabel = action.type.toUpperCase()
        const equipLabel = action.requiredEquipment || '—'
        row.meta.setText(`${typeLabel} · ${equipLabel}`)
        row.stamina.setText(`${action.staminaCost} STA`)

        const colors = getAbilityRarityColor(action.rarity)
        const isSelected = false // active rows can't be selected first
        row.bg.setStrokeStyle(2, colors.main)
        row.bg.setFillStyle(0x1a1a2e, 1)
        row.hitArea.setInteractive({ useHandCursor: true })
        row.hitArea.off('pointerdown')
        row.hitArea.on('pointerdown', () => this._onSwitchDialogActiveClick(action))
        row.hitArea.off('pointerover')
        row.hitArea.off('pointerout')
        row.hitArea.on('pointerover', () => row.bg.setFillStyle(colors.main, 0.15))
        row.hitArea.on('pointerout', () => row.bg.setFillStyle(0x1a1a2e, 1))
      } else if (i < maxActive) {
        // Empty active slot — show it so the player can fill it.
        row.container.setVisible(true)
        row.typeIcon.setText('○')
        row.name.setText('Empty Slot')
        row.meta.setText('Click to fill')
        row.stamina.setText('')
        row.bg.setStrokeStyle(1, 0x555555)
        row.bg.setFillStyle(0x1a1a2e, 1)
        row.hitArea.setInteractive({ useHandCursor: true })
        row.hitArea.off('pointerdown')
        row.hitArea.on('pointerdown', () => this._onSwitchDialogActiveClick(null))
        row.hitArea.off('pointerover')
        row.hitArea.off('pointerout')
        row.hitArea.on('pointerover', () => row.bg.setFillStyle(0x555555, 0.25))
        row.hitArea.on('pointerout', () => row.bg.setFillStyle(0x1a1a2e, 1))
      } else {
        row.container.setVisible(false)
        row.hitArea.disableInteractive()
      }
    })

    // Render inactive rows
    this.switchDialogInactiveRows.forEach((row, i) => {
      const action = combatInactive[i]
      if (action) {
        row.container.setVisible(true)
        row.typeIcon.setText(TYPE_ICONS[action.type] || '?')
        row.name.setText(action.name)
        const typeLabel = action.type.toUpperCase()
        const equipLabel = action.requiredEquipment || '—'
        row.meta.setText(`${typeLabel} · ${equipLabel}`)
        row.stamina.setText(`${action.staminaCost} STA`)

        const isSelected = this.switchDialogSelectedInactive === action.id
        row.bg.setStrokeStyle(2, isSelected ? 0xf1c40f : 0x7f8c8d)
        row.bg.setFillStyle(isSelected ? 0xf1c40f : 0x1a1a2e, isSelected ? 0.15 : 1)
        row.hitArea.setInteractive({ useHandCursor: true })
        row.hitArea.off('pointerdown')
        row.hitArea.on('pointerdown', () => this._onSwitchDialogInactiveClick(action))
      } else {
        row.container.setVisible(false)
        row.hitArea.disableInteractive()
      }
    })

    if (this.switchDialogSelectedInactive) {
      this.switchDialogHint.setText('Now click an active action to swap.')
      this.switchDialogHint.setColor('#f1c40f')
    } else {
      this.switchDialogHint.setText('Click an inactive action to select it for swapping.')
      this.switchDialogHint.setColor('#7f8c8d')
    }
  }

  _onSwitchDialogInactiveClick(action) {
    if (this.switchDialogSelectedInactive === action.id) {
      this.switchDialogSelectedInactive = null
    } else {
      this.switchDialogSelectedInactive = action.id
    }
    this.renderSwitchDialog()
  }

  _onSwitchDialogActiveClick(activeAction) {
    if (!this.switchDialogSelectedInactive) return

    const inactiveAction = this.player.inactiveActions.find(a => a.id === this.switchDialogSelectedInactive)
    if (!inactiveAction) {
      this.switchDialogSelectedInactive = null
      this.renderSwitchDialog()
      return
    }

    // Validate: must keep at least one attack action active
    const currentActiveIds = this.player.activeActions.map(a => a.id)
    const newActiveIds = activeAction
      ? currentActiveIds.map(id => (id === activeAction.id ? inactiveAction.id : id))
      : [...currentActiveIds, inactiveAction.id]

    const wouldHaveAttack = newActiveIds.some(id => {
      const a = ALL_ACTIONS.find(act => act.id === id)
      return a && a.type === 'attack'
    })
    if (!wouldHaveAttack) {
      this.switchDialogHint.setText('You must keep at least one attack action active!')
      this.switchDialogHint.setColor('#e74c3c')
      this.time.delayedCall(1500, () => this.renderSwitchDialog())
      return
    }

    // Perform swap (or fill an empty slot)
    if (activeAction) {
      this.player.swapActions(activeAction.id, inactiveAction.id)
    } else {
      this.player.loadout.activeActionIds.push(inactiveAction.id)
      this.player.addToSelectedPool(inactiveAction.id)
      this.player.saveLoadout()
      this.player.refreshActions()
    }
    this.player.useStamina(1)
    this.updateBars()
    this.switchDialogSelectedInactive = null

    // Re-render main UI skill buttons
    this._refreshSkillButtons()

    // Close dialog after swap
    this.hideSwitchActionDialog()
  }

  _refreshSkillButtons() {
    // Destroy old skill buttons
    this.skillButtons.forEach(({ btn }) => {
      btn.bg.destroy()
      btn.shadow.destroy()
      btn.hitArea.destroy()
      btn.text.destroy()
    })
    this.skillButtons = []

    // Recreate from active actions
    const clickableActions = this.player.activeActions
    clickableActions.forEach((action, i) => {
      const y = 155 + i * 44
      const colors = getAbilityRarityColor(action.rarity)
      const label = this.getSkillButtonLabel(action)
      const btn = this.createButton(120, y, label, () => this.onSkillClick(action), 160, 40, colors.main, colors.hover)
      this.skillButtons.push({ btn, skill: action })
    })

    // Reposition switch button
    const switchY = 155 + clickableActions.length * 44 + 8
    this.switchActionBtn.bg.destroy()
    this.switchActionBtn.shadow.destroy()
    this.switchActionBtn.hitArea.destroy()
    this.switchActionBtn.text.destroy()
    this.switchActionBtn = this.createButton(120, switchY, 'Switch Action (1)', () => this.onSwitchActionClick(), 160, 40, 0x2980b9, 0x3498db)
  }

  onSwitchActionClick() {
    this.showSwitchActionDialog()
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
    this.startKanjiDrawingChallenge(kanji.stroke_data, hint, {
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
    }, kanji)
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
      const aliveEnemies = this.turnManager.getAliveEnemies()
      if (aliveEnemies.length > 1) {
        // Defer damage until the player picks a target.
        this.pendingItem = item
        this.pendingItemKanjiResult = kanjiResult
        this.enterTargetMode((target) => {
          this.applyItemDamage(item, kanjiResult, target)
        }, 'Throw at which enemy?')
        return
      }
      this.applyItemDamage(item, kanjiResult, aliveEnemies[0])
    }

    this.player.useEquippedItem(item.id)
    this.player.clearItemEffectModifier()
    this.updateBars()
    this.updateBlockText()
  }

  applyItemDamage(item, kanjiResult, target) {
    const rawDamage = this.player.getItemDamage(item.baseValue)
    const defense = target.getDefense()
    let finalDamage
    if (defense <= 0) {
      finalDamage = rawDamage
    } else {
      finalDamage = Math.floor(rawDamage * rawDamage / (rawDamage + defense))
    }
    finalDamage = Math.max(1, finalDamage - target.armor)
    const actual = target.takeDamage(finalDamage)

    if (!target.isAlive()) {
      this.onEnemyDefeated(target)
    } else if (target.checkPhaseTransition) {
      if (target.checkPhaseTransition((msg) => this.addCombatLog(msg))) {
        this.refreshEnemyDisplay(this.getDisplayForEnemy(target))
      }
    }

    this.turnManager.checkBattleOver(this.player)

    const targetDisplay = this.getDisplayForEnemy(target)
    this.setPlayerPose('idle') // placeholder until we have stone throw sprite
    this.addCombatLog(`${item.name} thrown! -> ${actual} damage!`)
    if (targetDisplay) {
      this.spawnFloatingText(targetDisplay.sprite.x, targetDisplay.sprite.y - 40, `-${actual}`, COLORS.danger)
      this.shakeSprite(targetDisplay.sprite)
    }
    this.time.delayedCall(600, () => this.setPlayerPose('idle'))

    this.player.useEquippedItem(item.id)
    this.player.clearItemEffectModifier()
    this.updateBars()
    this.updateBlockText()
  }

  startReadinessChallenge() {
    const wordList = filterChallengeWords(this.player.wordList)
    if (!wordList || wordList.length === 0) {
      // No challenge-suitable words available — skip challenge, readiness stays 0
      this.addCombatLog('No words to review. Stay focused!')
      this.turnManager.endTurn()
      return
    }

    // Pick a random word
    const wordData = wordList[Math.floor(Math.random() * wordList.length)]
    if (!wordData.meaning || wordData.meaning.trim().length === 0) {
      this.addCombatLog('No meaning available — skipping challenge.')
      this.turnManager.endTurn()
      return
    }

    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    this.wordChallenge.start(wordData, {
      title: 'End Turn Challenge',
      promptType: 'meaning',
      timeLimit: 10000,
      hangOnWrong: 5000,
      hangOnCorrect: 900,
      onStart: () => {
        this.challengeActive = true
        this.wordChallengeActive = true
        window.scrollTo(0, 0)
      },
      onResult: ({ success, timedOut, word, correctAnswer }) => {
        if (success) {
          this.player.addReadiness(0.3)
          this._animateWordChallengeSuccess(this.wordChallenge.wordText)
        } else {
          this.player.addReadiness(-0.3)
          this._animateWordChallengeFailure(this.wordChallenge.wordText, timedOut, correctAnswer)
        }
      },
      onComplete: ({ success, timedOut, word }) => {
        this.challengeActive = false
        this.wordChallengeActive = false
        if (success) {
          this.addCombatLog('Readiness: Focused! (+5 DEF, enemy miss chance doubled)')
          this.spawnFloatingText(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 120, 'FOCUSED!', COLORS.success)
        } else {
          const logMsg = timedOut ? "Time's up! Readiness: Distracted..." : 'Wrong! Readiness: Distracted...'
          this.addCombatLog(logMsg)
          if (word?.meaning) this.addCombatLog(`Correct meaning: ${word.meaning}`)
        }
        this.turnManager.endTurn()
      },
    })
  }

  _animateWordChallengeSuccess(word) {
    // Positive animation: word bounces up, flashes green, sparkles
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
      this.wordChallenge.overlay.add(p)

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
  }

  _animateWordChallengeFailure(word, timedOut, correctAnswer) {
    // Negative animation: word shakes, flashes red, drops
    word.setColor('#e74c3c')

    const msg = timedOut ? "Time's up!" : 'Wrong!'
    this.wordChallenge.feedbackText.setText(`${msg} The meaning was: ${correctAnswer || '?'}`)
    this.wordChallenge.feedbackText.setColor('#e74c3c')

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
      this.wordChallenge.overlay.add(xMark)

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
  }

  // ---------- Reaction Challenge (during enemy attacks) ----------

  roll2d6() {
    return Math.floor(Math.random() * 6) + 1 + Math.floor(Math.random() * 6) + 1
  }

  async runReactionChallenge() {
    return new Promise((resolve) => {
      const wordList = filterChallengeWords(this.player.wordList)
      if (!wordList || wordList.length === 0) {
        resolve()
        return
      }

      // Pick a random word
      const wordData = wordList[Math.floor(Math.random() * wordList.length)]
      if (!wordData.meaning || wordData.meaning.trim().length === 0) {
        resolve()
        return
      }

      this.wordChallenge.start(wordData, {
        title: 'REACTION!',
        promptType: 'meaning',
        timeLimit: 5000,
        hangOnWrong: 400,
        hangOnCorrect: 400,
        onStart: () => {
          this.challengeActive = true
          this.wordChallengeActive = true
          this.wordChallenge.titleText.setColor('#e74c3c')
          this.wordChallenge.promptText.setColor('#f39c12')
        },
        onResult: ({ success, timedOut, word }) => {
          if (success) {
            this.player.reactionMultiplier = 2
            this.player.lastReactionCorrect = true
            this.wordChallenge.wordText.setColor('#2ecc71')
            this.wordChallenge.feedbackText.setText('PARRY!')
            this.wordChallenge.feedbackText.setColor('#2ecc71')
            this.spawnFloatingText(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 100, 'PARRY!', COLORS.success)
          } else {
            this.player.reactionMultiplier = 0.5
            this.player.lastReactionCorrect = false
            this.wordChallenge.wordText.setColor('#e74c3c')
            this.wordChallenge.feedbackText.setText('Failed...')
            this.wordChallenge.feedbackText.setColor('#e74c3c')
            this.spawnFloatingText(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 100, 'FAILED!', COLORS.danger)
          }
        },
        onComplete: () => {
          this.challengeActive = false
          this.wordChallengeActive = false
          resolve()
        },
      })
    })
  }

  createIntentionIcons() {
    // Per-enemy intention containers are already created in createEnemyDisplay().
    // This method is kept for compatibility with the existing create() flow.
  }

  computePredictedDamageRange(attacker, target) {
    const plan = attacker.computeActionPlan()
    let min = 0
    let max = 0
    for (const action of plan) {
      if (action.type !== 'attack' && action.type !== 'attack_defence') continue
      const range = this.computeAbilityDamageRange(attacker, action, target)
      min += range.min
      max += range.max
    }
    if (max <= 0) return null
    return { min, max }
  }

  computeAbilityDamageRange(attacker, ability, target) {
    const base = (ability.basePower || 0) + attacker.getStatValue(ability.scalingStat) * (ability.scalingMultiplier || 0)
    const nextAttackBonus = attacker.nextAttackBonus || 0
    const outgoing = attacker.getOutgoingDamageMultiplier()
    const incoming = target.getIncomingDamageMultiplier()
    const damageMultiplier = attacker.resolveDamageMultiplier(ability, {})
    const raw = (base + nextAttackBonus) * outgoing * incoming * damageMultiplier

    const minRaw = Math.floor(raw)
    const maxRaw = Math.floor(raw * 1.5)

    const defense = target.getTotalDefense ? target.getTotalDefense() : target.getDefense()
    const min = this.applyDefenseToDamage(minRaw, defense, target.armor)
    const max = this.applyDefenseToDamage(maxRaw, defense, target.armor)
    return { min, max }
  }

  applyDefenseToDamage(raw, defense, armor) {
    let damage
    if (defense <= 0) {
      damage = raw
    } else {
      damage = (raw * raw) / (raw + defense)
    }
    damage = Math.floor(damage)
    damage = Math.max(1, damage - (armor || 0))
    return Math.floor(damage)
  }

  updateIntentionButtonForEnemy(display) {
    const plan = display.enemy.computeActionPlan()
    display.intentionPlan = plan
    if (!plan || plan.length === 0 || !display.enemy.isAlive()) {
      this.closeIntentionBubble(display)
      if (display.intentionBtn) display.intentionBtn.setVisible(false)
      return
    }
    if (display.intentionBtn) display.intentionBtn.setVisible(true)
  }

  showIntentionPlan() {
    for (const display of this.enemyDisplays) {
      this.updateIntentionButtonForEnemy(display)
    }
  }

  hideIntentionIcons() {
    for (const display of this.enemyDisplays) {
      if (display.intentionBtn) display.intentionBtn.setVisible(false)
      this.closeIntentionBubble(display)
    }
  }

  toggleIntentionBubble(display) {
    if (display.intentionBubble && display.intentionBubble.active) {
      this.closeIntentionBubble(display)
    } else {
      this.openIntentionBubble(display)
    }
  }

  openIntentionBubble(display) {
    this.closeAllIntentionBubbles()
    const plan = display.intentionPlan || display.enemy.computeActionPlan()
    if (!plan || plan.length === 0) return

    const ICON_MAP = {
      buff: { char: '⬆', color: '#f39c12' },
      attack: { char: '⚔', color: '#e74c3c' },
      defence: { char: '🛡', color: '#3498db' },
      defense: { char: '🛡', color: '#3498db' },
      recover: { char: '↩', color: '#2ecc71' },
      curse: { char: '⬇', color: '#9b59b6' },
      debuff: { char: '⬇', color: '#9b59b6' },
      summon: { char: '✦', color: '#2ecc71' },
      transform: { char: '↻', color: '#9b59b6' },
      heal: { char: '✚', color: '#e91e63' },
    }

    const width = 150
    const rowHeight = 24
    const padding = 14
    const height = padding * 2 + 18 + plan.length * rowHeight
    const x = display.x
    const y = 120 + height / 2

    const container = this.add.container(x, y).setDepth(70)

    const bg = this.add.graphics()
    bg.fillStyle(0x1a1a2e, 0.96)
    bg.lineStyle(2, 0x3498db, 0.9)
    bg.fillRoundedRect(-width / 2, -height / 2, width, height, 12)
    bg.strokeRoundedRect(-width / 2, -height / 2, width, height, 12)
    container.add(bg)

    const title = this.add.text(0, -height / 2 + 16, 'Next turn', {
      ...FONTS.default,
      fontSize: '12px',
      color: '#f39c12',
      fontStyle: 'bold',
    }).setOrigin(0.5)
    container.add(title)

    plan.forEach((action, i) => {
      const rowY = -height / 2 + 34 + i * rowHeight
      const isAttack = action.type === 'attack' || action.type === 'attack_defence'
      if (isAttack) {
        const range = this.computeAbilityDamageRange(display.enemy, action, this.player)
        const label = `${range.min}-${range.max}`
        const txt = this.add.text(0, rowY, `⚔ ${label}`, {
          ...FONTS.default,
          fontSize: '13px',
          color: '#e74c3c',
        }).setOrigin(0.5)
        container.add(txt)
      } else {
        const info = ICON_MAP[action.type] || { char: '?', color: '#7f8c8d' }
        const txt = this.add.text(0, rowY, `${info.char} ${action.type}`, {
          ...FONTS.default,
          fontSize: '13px',
          color: info.color,
        }).setOrigin(0.5)
        container.add(txt)
      }
    })

    display.intentionBubble = container

    // Backdrop to close when clicking outside
    this.intentionBubbleBackdrop = this.add.rectangle(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      GAME_CONFIG.width,
      GAME_CONFIG.height,
      0x000000,
      0.01
    )
      .setDepth(60)
      .setInteractive({ useHandCursor: false })
    this.intentionBubbleBackdrop.on('pointerdown', () => this.closeIntentionBubble(display))
  }

  repositionIntentionBubble(display) {
    if (!display.intentionBubble || !display.intentionBubble.active) return
    const plan = display.intentionPlan || []
    const height = 28 + 18 + plan.length * 24
    display.intentionBubble.setPosition(display.x, 120 + height / 2)
  }

  closeIntentionBubble(display) {
    if (display.intentionBubble) {
      display.intentionBubble.destroy()
      display.intentionBubble = null
    }
    if (this.intentionBubbleBackdrop) {
      this.intentionBubbleBackdrop.destroy()
      this.intentionBubbleBackdrop = null
    }
  }

  closeAllIntentionBubbles() {
    for (const display of this.enemyDisplays) {
      this.closeIntentionBubble(display)
    }
  }

  createCombatLog() {
    this.combatLogHistory = []
    this.combatLogBg = this.add.graphics()
    this.combatLogText = this.add.text(20, 32, '', {
      ...FONTS.default,
      fontSize: '16px',
      align: 'left',
      wordWrap: { width: 360 },
      stroke: '#000000',
      strokeThickness: 3,
    }).setOrigin(0, 0.5).setDepth(50)
    this.combatLogBg.setDepth(49)

    this.combatLogText.setInteractive({ useHandCursor: true })
    this.combatLogText.on('pointerdown', () => this.showCombatLogHistory())

    this.createCombatLogHistoryPanel()
  }

  drawCombatLogBg() {
    const text = this.combatLogText.text
    if (!text) {
      this.combatLogBg.clear()
      return
    }
    const metrics = this.combatLogText.getBounds()
    const padX = 12
    const padY = 8
    const w = Math.max(metrics.width + padX * 2, 160)
    const h = metrics.height + padY * 2
    const x = metrics.x - padX
    const y = metrics.y - padY
    const radius = 10
    this.combatLogBg.clear()
    // Drop shadow
    this.combatLogBg.fillStyle(0x000000, 0.5)
    this.combatLogBg.fillRoundedRect(x + 3, y + 4, w, h, radius)
    // Main background
    this.combatLogBg.fillStyle(0x1a1a2e, 0.92)
    this.combatLogBg.fillRoundedRect(x, y, w, h, radius)
    this.combatLogBg.lineStyle(2, 0x5dade2, 0.8)
    this.combatLogBg.strokeRoundedRect(x, y, w, h, radius)
  }

  createCombatLogHistoryPanel() {
    this.combatLogHistoryPanel = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    this.combatLogHistoryPanel.setDepth(200)
    this.combatLogHistoryPanel.setVisible(false)
    this.combatLogHistoryLinesPerPage = 12
    this.combatLogHistoryPage = 0
    this.combatLogHistoryPagedLines = []

    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.7).setOrigin(0.5)
    backdrop.on('pointerdown', () => this.hideCombatLogHistory())
    this.combatLogHistoryPanel.add(backdrop)
    this.combatLogHistoryPanel.backdrop = backdrop

    const panelW = 520
    const panelH = 380
    this.combatLogHistoryPanel.panelH = panelH
    const panel = this.add.rectangle(0, 0, panelW, panelH, 0x1a1a2e).setStrokeStyle(2, 0x5dade2).setOrigin(0.5)
    this.combatLogHistoryPanel.add(panel)

    const title = this.add.text(0, -panelH / 2 + 24, 'Battle Log', {
      ...FONTS.title,
      fontSize: '22px',
      color: '#5dade2',
    }).setOrigin(0.5)
    this.combatLogHistoryPanel.add(title)

    this.combatLogHistoryText = this.add.text(0, -panelH / 2 + 60, '', {
      ...FONTS.default,
      fontSize: '14px',
      align: 'left',
      wordWrap: { width: panelW - 48 },
      lineSpacing: 6,
    }).setOrigin(0.5, 0)
    this.combatLogHistoryPanel.add(this.combatLogHistoryText)

    this.combatLogHistoryPageText = this.add.text(0, panelH / 2 - 32, '', {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
    }).setOrigin(0.5)
    this.combatLogHistoryPanel.add(this.combatLogHistoryPageText)

    const closeBtn = this.createButton(140, panelH / 2 - 32, 'Close', () => this.hideCombatLogHistory(), 100, 34, 0x7f8c8d, 0x95a5a6)
    this.combatLogHistoryPanel.add([closeBtn.bg, closeBtn.shadow, closeBtn.hitArea, closeBtn.text])
    closeBtn.hitArea.disableInteractive()
    this.combatLogHistoryPanel.closeBtn = closeBtn

    const prevBtn = this.createButton(-140, panelH / 2 - 32, 'Prev', () => this.changeCombatLogHistoryPage(-1), 80, 34, 0x2980b9, 0x3498db)
    this.combatLogHistoryPanel.add([prevBtn.bg, prevBtn.shadow, prevBtn.hitArea, prevBtn.text])
    prevBtn.hitArea.disableInteractive()
    this.combatLogHistoryPanel.prevBtn = prevBtn

    const nextBtn = this.createButton(-50, panelH / 2 - 32, 'Next', () => this.changeCombatLogHistoryPage(1), 80, 34, 0x2980b9, 0x3498db)
    this.combatLogHistoryPanel.add([nextBtn.bg, nextBtn.shadow, nextBtn.hitArea, nextBtn.text])
    nextBtn.hitArea.disableInteractive()
    this.combatLogHistoryPanel.nextBtn = nextBtn
  }

  changeCombatLogHistoryPage(delta) {
    const maxPage = Math.max(0, Math.ceil(this.combatLogHistoryPagedLines.length / this.combatLogHistoryLinesPerPage) - 1)
    this.combatLogHistoryPage = Math.max(0, Math.min(maxPage, this.combatLogHistoryPage + delta))
    this.renderCombatLogHistoryPage()
  }

  renderCombatLogHistoryPage() {
    const perPage = this.combatLogHistoryLinesPerPage
    const start = this.combatLogHistoryPage * perPage
    const pageLines = this.combatLogHistoryPagedLines.slice(start, start + perPage)
    this.combatLogHistoryText.setText(pageLines.join('\n'))
    const totalPages = Math.max(1, Math.ceil(this.combatLogHistoryPagedLines.length / perPage))
    this.combatLogHistoryPageText.setText(`${this.combatLogHistoryPage + 1} / ${totalPages}`)

    const hasPrev = this.combatLogHistoryPage > 0
    const hasNext = this.combatLogHistoryPage < totalPages - 1
    this.setHistoryNavButtonEnabled(this.combatLogHistoryPanel.prevBtn, hasPrev)
    this.setHistoryNavButtonEnabled(this.combatLogHistoryPanel.nextBtn, hasNext)
  }

  setHistoryNavButtonEnabled(btn, enabled) {
    if (!btn) return
    if (enabled) {
      btn.hitArea.setInteractive({ useHandCursor: true })
      btn.text.setAlpha(1)
      btn.bg.setAlpha(1)
    } else {
      btn.hitArea.disableInteractive()
      btn.text.setAlpha(0.4)
      btn.bg.setAlpha(0.4)
    }
  }

  showCombatLogHistory() {
    if (!this.combatLogHistoryPanel) return
    this.combatLogHistoryPagedLines = this.combatLogHistory.map(entry => `Turn ${entry.turn}: ${entry.message}`)
    this.combatLogHistoryPage = 0
    this.renderCombatLogHistoryPage()
    this.combatLogHistoryPanel.backdrop.setInteractive()
    this.combatLogHistoryPanel.closeBtn.hitArea.setInteractive({ useHandCursor: true })
    this.combatLogHistoryPanel.setVisible(true)
  }

  hideCombatLogHistory() {
    if (!this.combatLogHistoryPanel) return
    this.combatLogHistoryPanel.setVisible(false)
    this.combatLogHistoryPanel.backdrop.disableInteractive()
    this.combatLogHistoryPanel.closeBtn.hitArea.disableInteractive()
    this.combatLogHistoryPanel.prevBtn.hitArea.disableInteractive()
    this.combatLogHistoryPanel.nextBtn.hitArea.disableInteractive()
  }

  // ---------- Interaction ----------

  getSkillButtonLabel(action) {
    const infusion = this.player.getAbilityInfusion(action.id)
    const badge = infusion ? (INFUSION_ICONS[infusion.value] || '✦') : ''
    const charges = action.singleUse ? this.player.getAbilityCharges(action.id) : null
    const chargesText = charges !== null ? ` x${charges}` : ''
    return `${badge}${badge ? ' ' : ''}${action.name} (${action.staminaCost})${chargesText}`
  }

  updateSkillButtonLabels() {
    for (const { btn, skill } of this.skillButtons) {
      if (!btn || !btn.text) continue
      btn.text.setText(this.getSkillButtonLabel(skill))
    }
  }

  enterInfusionMode(infuseSkill) {
    if (this.pendingInfusion) this.clearInfusionMode()
    this.pendingInfusion = { skill: infuseSkill, value: infuseSkill.infusionValue }
    this.addCombatLog(`Select an ability to infuse with ${infuseSkill.infusionValue}.`)

    this.infusionPrompt = this.add.text(GAME_CONFIG.width / 2, 32, `Infuse with ${infuseSkill.infusionValue}`, {
      ...FONTS.title,
      fontSize: '16px',
      color: '#f1c40f',
    }).setOrigin(0.5).setDepth(60)

    this.infusionCancelBtn = this.createButton(GAME_CONFIG.width / 2, 70, 'Cancel', () => this.clearInfusionMode(), 120, 36, 0x7f8c8d, 0x95a5a6)
    this.infusionCancelBtn.text.setDepth(61)
    this.infusionCancelBtn.bg.setDepth(61)
    this.infusionCancelBtn.hitArea.setDepth(61)
    if (this.infusionCancelBtn.shadow) this.infusionCancelBtn.shadow.setDepth(60)

    this.endTurnBtn.setVisible(false)
    this.switchActionBtn.setVisible(false)

    this.renderInfusionMode()
  }

  clearInfusionMode() {
    this.pendingInfusion = null
    if (this.infusionPrompt) {
      this.infusionPrompt.destroy()
      this.infusionPrompt = null
    }
    if (this.infusionCancelBtn) {
      this.infusionCancelBtn.bg.destroy()
      this.infusionCancelBtn.text.destroy()
      this.infusionCancelBtn.hitArea.destroy()
      if (this.infusionCancelBtn.shadow) this.infusionCancelBtn.shadow.destroy()
      this.infusionCancelBtn = null
    }
    this.setSkillButtonsEnabled(true)
    this.updateSkillButtonLabels()
    if (this.turnManager.currentTurn === 'player' && !this.challengeActive) {
      this.endTurnBtn.setVisible(true)
      this.switchActionBtn.setVisible(true)
    }
  }

  renderInfusionMode() {
    // Ensure buttons are interactive so the player can pick a target ability.
    this.setSkillButtonsEnabled(true)

    for (const { btn, skill } of this.skillButtons) {
      if (!btn || !btn.text) continue
      btn.text.setText(this.getSkillButtonLabel(skill))

      if (skill.id === this.pendingInfusion.skill.id) {
        btn.redraw(0xf1c40f)
      } else if (skill.infusableWith?.includes(this.pendingInfusion.value)) {
        btn.redraw(0x27ae60)
      } else {
        btn.redraw(0x5a5a6a)
        btn.text.setAlpha(0.6)
      }
    }
  }

  getInfusionKanjiTier(kanji, pools) {
    if (!pools || !kanji) return 0
    const levels = Object.entries(pools)
      .filter(([, chars]) => chars.includes(kanji))
      .map(([lvl]) => Number(lvl))
      .sort((a, b) => b - a)
    return levels[0] || 0
  }

  computeInfusionPotency(kanji, tier = 0) {
    const kanjiData = this.player.kanjiList.find(k => k.character === kanji)
    const strokeCount = kanjiData?.stroke_count || 1
    return Math.min(2.0, 1 + tier * 0.01 + strokeCount * 0.015)
  }

  pickInfusionChallengeKanji(infuseSkill) {
    const userLevel = getWindowGameData()?.level || 1
    const pools = infuseSkill.infusionKanjiPools

    // 20% chance to override the pool with the focus/to-learn kanji.
    const focusKanjiData = this.player.loadout.focusKanjiData
    if (focusKanjiData && Math.random() < 0.2 && focusKanjiData.stroke_data?.strokes?.length > 0) {
      return {
        kanji: focusKanjiData.character,
        data: focusKanjiData,
        strokeData: focusKanjiData.stroke_data,
        tier: this.getInfusionKanjiTier(focusKanjiData.character, pools),
      }
    }

    if (pools) {
      const effectivePool = Object.entries(pools)
        .filter(([min]) => Number(min) <= userLevel)
        .flatMap(([, chars]) => chars)
      const learned = effectivePool
        .map(c => ({ char: c, data: this.player.kanjiList.find(k => k.character === c) }))
        .filter(item => item.data?.stroke_data?.strokes?.length > 0)
      if (learned.length > 0) {
        const pick = learned[Math.floor(Math.random() * learned.length)]
        return { kanji: pick.char, data: pick.data, strokeData: pick.data.stroke_data, tier: this.getInfusionKanjiTier(pick.char, pools) }
      }
    }

    const learnedList = this.player.kanjiList.filter(k => k.stroke_data?.strokes?.length > 0)
    if (learnedList.length > 0) {
      const pick = learnedList[Math.floor(Math.random() * learnedList.length)]
      return { kanji: pick.character, data: pick, strokeData: pick.stroke_data, tier: 0 }
    }

    return null
  }

  startInfusionChallenge(targetSkill) {
    const infuseSkill = this.pendingInfusion.skill
    const value = this.pendingInfusion.value
    this.clearInfusionMode()

    this.pendingInfusionTarget = { targetSkill, infuseSkill, value }

    const pick = this.pickInfusionChallengeKanji(infuseSkill)
    if (!pick) {
      this.addCombatLog(`No learned kanji available — infusing without challenge.`)
      this.finishInfusionAttempt(this.pendingInfusionTarget, null, 1)
      return
    }

    this.pendingInfusionTarget.kanji = pick.kanji
    this.pendingInfusionTarget.tier = pick.tier
    this.pendingInfusionTarget.totalStrokes = pick.strokeData?.strokes?.length || 1

    const meaning = pick.data?.meanings?.[0]
    const on = pick.data?.on_readings?.[0]
    const kun = pick.data?.kun_readings?.[0]
    const hintParts = []
    if (meaning) hintParts.push(`Meaning: ${meaning}`)
    if (on) hintParts.push(`On: ${on}`)
    if (kun) hintParts.push(`Kun: ${kun}`)
    const hint = `Infuse ${value}! ${hintParts.join(' | ')}`

    this.challengeActive = true
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)
    this.switchActionBtn.setVisible(false)

    this.startKanjiDrawingChallenge(pick.strokeData, hint, {
      onComplete: (result) => {
        this.challengeActive = false
        this.setSkillButtonsEnabled(true)
        this.endTurnBtn.setVisible(true)
        this.switchActionBtn.setVisible(true)
        this.finishInfusionAttempt(this.pendingInfusionTarget, result)
        this.pendingInfusionTarget = null
      },
      onWrongStroke: ({ count }) => {
        this.spawnFloatingText(
          GAME_CONFIG.width / 2,
          GAME_CONFIG.height / 2 - 180,
          `Wrong stroke! (${count})`,
          COLORS.danger
        )
      },
    }, pick.data)
  }

  finishInfusionAttempt(pending, kanjiResult) {
    const { targetSkill, infuseSkill, value, kanji, tier } = pending

    const refreshUI = () => {
      this.updateBars()
      this.updateSkillButtonLabels()
      this.setSkillButtonsEnabled(true)
    }

    if (!this.player.canUseSkill(infuseSkill)) {
      this.addCombatLog('Not enough stamina to infuse!')
      refreshUI()
      return
    }

    this.player.useStamina(infuseSkill.staminaCost)

    const mana = this.player.mana || 0
    let failureChance = Math.max(0.1, 0.8 - mana * 0.02)
    let challengeBonus = 0

    if (kanjiResult) {
      if (kanjiResult.completed) {
        const totalStrokes = pending.totalStrokes || 1
        const ratio = kanjiResult.wrongStrokes / totalStrokes
        if (ratio <= 1 / 3) {
          challengeBonus = 0.35
          this.addCombatLog(`${kanji} drawn cleanly! Infusion chance greatly improved.`)
        } else if (ratio <= 1 / 2) {
          challengeBonus = 0.20
          this.addCombatLog(`${kanji} drawn! Infusion chance improved.`)
        } else {
          challengeBonus = -0.10
          this.addCombatLog(`${kanji} drawn sloppily. Infusion chance worsened.`)
        }
      } else {
        challengeBonus = -0.10
        this.addCombatLog(`${kanji} failed! Infusion chance worsened.`)
      }
    }

    failureChance = Math.max(0, failureChance - challengeBonus)
    const failed = Math.random() < failureChance

    if (failed) {
      this.addCombatLog(`The ${value} infusion fizzles... (mana ${mana})`)
    } else {
      let potency = kanji ? this.computeInfusionPotency(kanji, tier || 0) : 1
      let finalValue = value
      let extraEffects = []
      let reactionMsg = null

      const existing = this.player.getAbilityInfusion(targetSkill.id)
      if (existing) {
        const reaction = resolveInfusionReaction(existing.value, value, existing)
        reactionMsg = reaction.message
        if (reaction.type === 'cancel') {
          this.player.clearAbilityInfusion(targetSkill.id)
          this.player.recoverStamina(infuseSkill.staminaCost)
          const icon = INFUSION_ICONS[value] || '✦'
          this.addCombatLog(`${icon} ${targetSkill.name}: ${reactionMsg}`)
          this.flashScreen(0xecf0f1, 100)
          this.shakeScreen(0.005, 120)
          refreshUI()
          return
        }
        finalValue = reaction.value
        extraEffects = reaction.extraEffects || []
        potency = Math.max(existing.potency || 1, potency) + reaction.potencyDelta
      }

      const infusedMana = existing ? Math.max(existing.mana || 0, mana) : mana
      this.player.setAbilityInfusion(targetSkill.id, finalValue, infusedMana, potency, extraEffects)
      const icon = INFUSION_ICONS[finalValue] || '✦'
      const reactionText = reactionMsg ? ` ${reactionMsg}` : ''
      this.addCombatLog(`${icon} ${targetSkill.name} is infused with ${finalValue}! (potency ${potency.toFixed(2)})${reactionText}`)
      if (this.isComboElement(finalValue)) {
        const fxColor = this.getElementColor(getElementForInfusion(finalValue) || finalValue)
        this.flashScreen(fxColor, 120)
        this.shakeScreen(0.008, 150)
      }
    }

    refreshUI()
  }

  handleKeyInput(event) {
    if (!this.challengeActive) return

    // Prevent browser find/search from intercepting typed keys
    event.preventDefault()

    // The reusable word challenge manages its own keyboard input
    if (this.wordChallengeActive) {
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

    // Use Item is a special action that opens the item menu.
    if (skill.type === 'item') {
      this.onUseItemClick()
      return
    }

    // Infuse ability selection / target handling
    if (skill.type === 'infuse') {
      if (this.pendingInfusion && this.pendingInfusion.skill.id === skill.id) {
        this.clearInfusionMode()
        return
      }
      this.enterInfusionMode(skill)
      return
    }

    if (this.pendingInfusion) {
      if (skill.id === this.pendingInfusion.skill.id) {
        this.clearInfusionMode()
        return
      }
      if (skill.infusableWith?.includes(this.pendingInfusion.value)) {
        this.startInfusionChallenge(skill)
      } else {
        this.addCombatLog(`${skill.name} cannot be infused with ${this.pendingInfusion.value}.`)
      }
      return
    }

    if (!this.player.canUseSkill(skill)) {
      this.addCombatLog('Not enough stamina!')
      return
    }

    // Parry must be set up during player turn (kanji drawing + stamina cost)
    if (skill.type === 'parry') {
      this.challengeActive = true
      this.setSkillButtonsEnabled(false)
      this.endTurnBtn.setVisible(false)

      const onComplete = (outcome) => {
        this.challengeActive = false
        this.setSkillButtonsEnabled(true)
        this.endTurnBtn.setVisible(true)

        this.player.useStamina(skill.staminaCost)
        this.player.addParryCharge(outcome.quality)

        const count = this.player.parryCharges.length
        const qualityText = outcome.quality === 'perfect' ? 'Perfect' : outcome.quality === 'sloppy' ? 'Solid' : 'Weak'
        this.addCombatLog(`${qualityText} parry set up! (${count} charge${count !== 1 ? 's' : ''}) (-${skill.staminaCost} STA)`)
        this.updateBars()
      }

      this.resolveParryKanjiChallenge(skill, {
        onComplete,
        onWrongStroke: ({ count }) => {
          this.spawnFloatingText(
            GAME_CONFIG.width / 2,
            GAME_CONFIG.height / 2 - 180,
            `Wrong stroke! (${count})`,
            COLORS.danger
          )
        },
      }, 'Set up parry!')
      return
    }

    this.selectedSkill = skill

    const aliveEnemies = this.turnManager.getAliveEnemies()
    if (this.isEnemyTargetedSkill(skill) && aliveEnemies.length > 1) {
      this.enterTargetMode((target) => {
        this.selectedTarget = target
        this.startChallenge(skill)
      }, 'Select a target')
      return
    }

    // Single enemy or self-targeted skill: auto-target the first/only enemy.
    this.selectedTarget = aliveEnemies[0] || null
    this.startChallenge(skill)
  }

  isEnemyTargetedSkill(skill) {
    return ['attack', 'attack_defence', 'debuff', 'curse'].includes(skill?.type)
  }

  onEndTurn() {
    if (this.challengeActive) return
    if (this.turnManager.currentTurn !== 'player') return
    if (this.pendingInfusion) this.clearInfusionMode()

    // Start readiness word challenge before ending turn
    this.startReadinessChallenge()
  }

  startChallenge(skill) {
    this.challengeActive = true
    this.selectedSkill = skill
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    // Weapon attacks with a kanjiChallenge config use the generic resolver.
    if (skill.kanjiChallenge) {
      this.weaponKanjiChallenge.resolve(skill, ({ challengeResult }) => {
        this.executeSkill(challengeResult)
      })
      return
    }

    // Setup Defence uses kanji drawing for a random shield kanji
    if (skill.id === 'setup_defence') {
      const userData = getWindowGameData()
      const basePool = ['守', '防', '盾', '硬', '堅']
      const charmPool = this.player.shield?.kanjiPool || []
      const pool = Array.from(new Set([...basePool, ...charmPool]))
      const selectedKanji = pool[Math.floor(Math.random() * pool.length)]

      let strokeData = this.player.kanjiList.find(k => k.character === selectedKanji)?.stroke_data
      if (!strokeData || !strokeData.strokes || strokeData.strokes.length === 0) {
        strokeData = userData?.shield_kanji_pool_strokes?.[selectedKanji] || userData?.shield_kanji_strokes || { strokes: [] }
      }

      if (!strokeData.strokes || strokeData.strokes.length === 0) {
        // No stroke data for this kanji: fall back to a guaranteed success with half value.
        const amount = Math.floor(this.player.computeSetupDefenceAmount(skill, 0.5))
        this.challengeActive = false
        this.player.addDefense(amount)
        this.addCombatLog(`Guard raised! +${amount} Defence`)
        this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 60, `+${amount} Defence`, 0x2ecc71)
        this.executeSkill('success')
        return
      }

      const gameData = getWindowGameData()
      const userLevel = gameData?.level || 1
      const hint = userLevel >= 10
        ? this.player.shield?.moveHint?.ja || '盾を構えろ。'
        : this.player.shield?.moveHint?.en || 'Raise your GUARD.'

      const kanjiEntry = this.player.kanjiList.find(k => k.character === selectedKanji)
      const meanings = kanjiEntry?.meanings || userData?.shield_kanji_pool_strokes?.[selectedKanji]?.meanings || []
      const kanjiData = { character: selectedKanji, meanings }

      this.startKanjiDrawingChallenge(strokeData, hint, {
        onComplete: (result) => {
          this.challengeActive = false
          this.setSkillButtonsEnabled(true)
          this.endTurnBtn.setVisible(true)

          const multiplier = result.completed
            ? (result.wrongStrokes === 0 ? 1.25 : 1.0)
            : 0.5
          const amount = this.player.computeSetupDefenceAmount(skill, multiplier)
          this.player.addDefense(amount)
          this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 60, `+${amount} Defence`, 0x2ecc71)

          if (result.completed) {
            const quality = result.wrongStrokes === 0 ? 'perfectly' : ''
            this.addCombatLog(`${selectedKanji} drawn${quality ? ' ' + quality : ''}! +${amount} Defence`)
            this.executeSkill('success')
          } else {
            this.addCombatLog(`${selectedKanji} failed! Only +${amount} Defence`)
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
      }, kanjiData)
      return
    }

    // Focus uses a kanji challenge to add readiness.
    if (skill.id === 'focus') {
      const cfg = skill.kanjiChallenge || {}
      const outcomes = cfg.outcomes || {}

      // 10% chance to skip the challenge entirely.
      const skipChance = cfg.skipChance ?? 0.1
      if (skipChance > 0 && Math.random() < skipChance) {
        const delta = outcomes.skipped?.readinessDelta ?? 0.5
        this.player.addReadiness(delta)
        this.challengeActive = false
        this.setSkillButtonsEnabled(true)
        this.endTurnBtn.setVisible(true)
        this.addCombatLog(`Focus settles. +${delta} readiness.`)
        this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${delta} Readiness`, 0x9b59b6)
        this.executeSkill('success')
        return
      }

      // Pick a kanji from the Focus pool; 20% chance to use the current focus kanji instead.
      const pool = skill.kanjiPool || ['気', '心', '集', '念', '魂', '精']
      const focusOverrideChance = cfg.focusOverrideChance ?? 0.2
      const focusKanjiData = this.player.loadout.focusKanjiData
      let selectedKanjiData = null

      if (focusKanjiData && focusOverrideChance > 0 && Math.random() < focusOverrideChance && focusKanjiData.stroke_data?.strokes?.length > 0) {
        selectedKanjiData = focusKanjiData
      } else {
        const allKanji = getWindowGameData()?.all_kanji || []
        const candidates = pool
          .map(char => {
            const fromList = this.player.kanjiList.find(k => k.character === char)
            if (fromList?.stroke_data?.strokes?.length > 0) return fromList
            const fromAll = allKanji.find(k => k.character === char)
            if (fromAll?.stroke_data?.strokes?.length > 0) return fromAll
            return null
          })
          .filter(Boolean)
        if (candidates.length > 0) {
          selectedKanjiData = candidates[Math.floor(Math.random() * candidates.length)]
        }
      }

      // No usable stroke data: fall back to the base gain.
      if (!selectedKanjiData || !selectedKanjiData.stroke_data?.strokes?.length) {
        const delta = outcomes.fallback?.readinessDelta ?? 0.5
        this.player.addReadiness(delta)
        this.challengeActive = false
        this.setSkillButtonsEnabled(true)
        this.endTurnBtn.setVisible(true)
        this.addCombatLog(`Focus settles. +${delta} readiness.`)
        this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${delta} Readiness`, 0x9b59b6)
        this.executeSkill('success')
        return
      }

      const strokeData = selectedKanjiData.stroke_data
      const totalStrokes = strokeData.strokes.length
      const failThreshold = cfg.failThreshold === 'halfUp'
        ? Math.ceil(totalStrokes / 2)
        : (typeof cfg.failThreshold === 'number' ? cfg.failThreshold : Math.ceil(totalStrokes / 2))

      this.challengeActive = true
      this.setSkillButtonsEnabled(false)
      this.endTurnBtn.setVisible(false)

      this.startKanjiDrawingChallenge(strokeData, `Focus! Draw ${selectedKanjiData.character}:`, {
        onComplete: (result) => {
          this.challengeActive = false
          this.setSkillButtonsEnabled(true)
          this.endTurnBtn.setVisible(true)

          const passed = result.completed && result.wrongStrokes < failThreshold
          if (passed) {
            const delta = outcomes.pass?.readinessDelta ?? 0.7
            this.player.addReadiness(delta)
            this.addCombatLog(`${selectedKanjiData.character} drawn! +${delta} readiness.`)
            this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${delta} Readiness`, 0x9b59b6)
            this.executeSkill('success')
          } else {
            const delta = outcomes.fail?.readinessDelta ?? 0.3
            this.player.addReadiness(delta)
            this.addCombatLog(`${selectedKanjiData.character} failed! +${delta} readiness.`)
            this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${delta} Readiness`, 0x9b59b6)
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
      }, selectedKanjiData)
      return
    }

    // Sharpen Blade draws a kanji from its pool; the buff's damage depends on stroke count.
    if (skill.id === 'sword_buff') {
      const pool = skill.kanjiPool || ['鋭', '研', '磨', '錬']
      const focusOverrideChance = skill.kanjiChallenge?.focusOverrideChance ?? 0.2
      const focusKanjiData = this.player.loadout.focusKanjiData
      let selectedKanjiData = null

      if (focusKanjiData && focusOverrideChance > 0 && Math.random() < focusOverrideChance && focusKanjiData.stroke_data?.strokes?.length > 0) {
        selectedKanjiData = focusKanjiData
      } else {
        const allKanji = getWindowGameData()?.all_kanji || []
        const candidates = pool
          .map(char => {
            const fromList = this.player.kanjiList.find(k => k.character === char)
            if (fromList?.stroke_data?.strokes?.length > 0) return fromList
            const fromAll = allKanji.find(k => k.character === char)
            if (fromAll?.stroke_data?.strokes?.length > 0) return fromAll
            return null
          })
          .filter(Boolean)
        if (candidates.length > 0) {
          selectedKanjiData = candidates[Math.floor(Math.random() * candidates.length)]
        }
      }

      if (!selectedKanjiData || !selectedKanjiData.stroke_data?.strokes?.length) {
        this.player.setKanjiResult(99)
        this.player.setKanjiStrokeCount(0)
        this.challengeActive = false
        this.executeSkill('fail')
        return
      }

      const strokeData = selectedKanjiData.stroke_data
      const totalStrokes = strokeData.strokes.length

      this.startKanjiDrawingChallenge(strokeData, `Sharpen! Draw ${selectedKanjiData.character}:`, {
        onComplete: (result) => {
          this.challengeActive = false
          this.setSkillButtonsEnabled(true)
          this.endTurnBtn.setVisible(true)

          this.player.setKanjiStrokeCount(totalStrokes)
          if (result.completed) {
            this.player.setKanjiResult(result.wrongStrokes)
            this.addCombatLog(`${selectedKanjiData.character} drawn (${totalStrokes} strokes, ${result.wrongStrokes} mistakes). The blade is sharpened.`)
            this.executeSkill('success')
          } else {
            this.player.setKanjiResult(99)
            this.addCombatLog(`${selectedKanjiData.character} failed! The blade remains dull.`)
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
      }, selectedKanjiData)
      return
    }

    // Berserk draws a kanji from its pool; the lifesteal percentage depends on strokes and mistakes.
    if (skill.id === 'berserk') {
      this.startBerserkChallenge(skill)
      return
    }

    // Use Item opens the item menu directly
    if (skill.id === 'use_item') {
      this.challengeActive = false
      this.showItemMenu()
      return
    }

    // Taunt and Zen are whole-battle stances resolved with a kanji challenge.
    if (skill.type === 'stance') {
      if (skill.id === 'taunt') {
        this.startStanceAbilityChallenge(skill, {
          label: 'Taunt',
          basePlayerMult: 1.5,
          baseEnemyMult: 1.5,
          passPlayerMult: 1.7,
          passEnemyMult: 1.4,
          failPlayerMult: 1.3,
          failEnemyMult: 1.7,
        })
      } else if (skill.id === 'zen') {
        this.startStanceAbilityChallenge(skill, {
          label: 'Zen',
          basePlayerMult: 1 / 1.5,
          baseEnemyMult: 1 / 1.5,
          passPlayerMult: 1 / 1.7,
          passEnemyMult: 1 / 1.5,
          failPlayerMult: 1 / 1.3,
          failEnemyMult: 1 / 1.5,
        })
      }
      return
    }

    // Dash is a per-battle reflex ability that adds miss chance for every other ability used.
    if (skill.type === 'dash') {
      this.startDashAbilityChallenge(skill)
      return
    }

    // Fallback: typing challenge for other skills
    this.typedInput = ''
    this.currentChallenge = this.challengeSystem.getChallengeForSkill(skill)
    if (!this.currentChallenge) {
      this.challengeActive = false
      this.executeSkill('success')
      // Re-enable controls so the player can keep acting or end their turn.
      this.setSkillButtonsEnabled(true)
      this.endTurnBtn.setVisible(true)
      return
    }

    this.challengeKanji.setText(this.currentChallenge.kanji)
    this.challengePrompt.setText(this.currentChallenge.prompt)
    this.challengeInput.setText('')
    this.challengeOverlay.setVisible(true)
  }

  startStanceAbilityChallenge(skill, cfg) {
    const challengeCfg = skill.kanjiChallenge || {}

    const finish = (playerMult, enemyMult, logMsg) => {
      this.player.multiplyStanceOutgoing(playerMult)
      this.player.multiplyStanceIncoming(enemyMult)
      this.challengeActive = false
      this.setSkillButtonsEnabled(true)
      this.endTurnBtn.setVisible(true)
      this.addCombatLog(logMsg)
      this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 60, `${cfg.label} x${playerMult.toFixed(2)}`, cfg.label === 'Zen' ? 0x3498db : 0xe67e22)
      this.executeSkill('success')
    }

    // 40% chance to skip the challenge entirely.
    const skipChance = challengeCfg.skipChance ?? 0.4
    if (skipChance > 0 && Math.random() < skipChance) {
      finish(cfg.basePlayerMult, cfg.baseEnemyMult, `${cfg.label} takes hold. Player x${cfg.basePlayerMult.toFixed(2)}, enemy x${cfg.baseEnemyMult.toFixed(2)}`)
      return
    }

    // Pick a kanji from the stance pool; 20% chance to use the focus kanji instead.
    const pool = skill.kanjiPool || []
    const focusOverrideChance = challengeCfg.focusOverrideChance ?? 0.2
    const focusKanjiData = this.player.loadout.focusKanjiData
    let selectedKanjiData = null

    if (focusKanjiData && focusOverrideChance > 0 && Math.random() < focusOverrideChance && focusKanjiData.stroke_data?.strokes?.length > 0) {
      selectedKanjiData = focusKanjiData
    } else {
      const allKanji = getWindowGameData()?.all_kanji || []
      const candidates = pool
        .map(char => {
          const fromList = this.player.kanjiList.find(k => k.character === char)
          if (fromList?.stroke_data?.strokes?.length > 0) return fromList
          const fromAll = allKanji.find(k => k.character === char)
          if (fromAll?.stroke_data?.strokes?.length > 0) return fromAll
          return null
        })
        .filter(Boolean)
      if (candidates.length > 0) {
        selectedKanjiData = candidates[Math.floor(Math.random() * candidates.length)]
      }
    }

    // No usable stroke data: apply the base multiplier.
    if (!selectedKanjiData || !selectedKanjiData.stroke_data?.strokes?.length) {
      finish(cfg.basePlayerMult, cfg.baseEnemyMult, `${cfg.label} takes hold. Player x${cfg.basePlayerMult.toFixed(2)}, enemy x${cfg.baseEnemyMult.toFixed(2)}`)
      return
    }

    const strokeData = selectedKanjiData.stroke_data
    const totalStrokes = strokeData.strokes.length
    const failThreshold = challengeCfg.failThreshold === 'halfUp'
      ? Math.ceil(totalStrokes / 2)
      : (typeof challengeCfg.failThreshold === 'number' ? challengeCfg.failThreshold : Math.ceil(totalStrokes / 2))

    this.challengeActive = true
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    this.startKanjiDrawingChallenge(strokeData, `${cfg.label}! Draw ${selectedKanjiData.character}:`, {
      onComplete: (result) => {
        this.challengeActive = false
        this.setSkillButtonsEnabled(true)
        this.endTurnBtn.setVisible(true)

        const passed = result.completed && result.wrongStrokes < failThreshold
        if (passed) {
          finish(cfg.passPlayerMult, cfg.passEnemyMult, `${selectedKanjiData.character} drawn! ${cfg.label} intensified. Player x${cfg.passPlayerMult.toFixed(2)}, enemy x${cfg.passEnemyMult.toFixed(2)}`)
        } else {
          finish(cfg.failPlayerMult, cfg.failEnemyMult, `${selectedKanjiData.character} failed! ${cfg.label} weakened. Player x${cfg.failPlayerMult.toFixed(2)}, enemy x${cfg.failEnemyMult.toFixed(2)}`)
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
    }, selectedKanjiData)
  }

  startDashAbilityChallenge(skill) {
    const challengeCfg = skill.kanjiChallenge || {}

    const finish = (bonusDelta, logMsg) => {
      this.player.addDashBonus(bonusDelta)
      this.challengeActive = false
      this.setSkillButtonsEnabled(true)
      this.endTurnBtn.setVisible(true)
      this.addCombatLog(logMsg)
      this.spawnFloatingText(
        this.playerSprite.x,
        this.playerSprite.y - 60,
        `Dash +${(bonusDelta * 100).toFixed(0)}%`,
        0x2ecc71
      )
      this.executeSkill('success')
    }

    // 20% chance to skip the challenge entirely.
    const skipChance = challengeCfg.skipChance ?? 0.2
    if (skipChance > 0 && Math.random() < skipChance) {
      finish(0.05, 'Dash reflex sharpened. +5% miss per ability.')
      return
    }

    // Pick a kanji from the dash pool; 20% chance to use the focus kanji instead.
    const pool = skill.kanjiPool || []
    const focusOverrideChance = challengeCfg.focusOverrideChance ?? 0.2
    const focusKanjiData = this.player.loadout.focusKanjiData
    let selectedKanjiData = null

    if (focusKanjiData && focusOverrideChance > 0 && Math.random() < focusOverrideChance && focusKanjiData.stroke_data?.strokes?.length > 0) {
      selectedKanjiData = focusKanjiData
    } else {
      const allKanji = getWindowGameData()?.all_kanji || []
      const candidates = pool
        .map(char => {
          const fromList = this.player.kanjiList.find(k => k.character === char)
          if (fromList?.stroke_data?.strokes?.length > 0) return fromList
          const fromAll = allKanji.find(k => k.character === char)
          if (fromAll?.stroke_data?.strokes?.length > 0) return fromAll
          return null
        })
        .filter(Boolean)
      if (candidates.length > 0) {
        selectedKanjiData = candidates[Math.floor(Math.random() * candidates.length)]
      }
    }

    // No usable stroke data: apply the base bonus.
    if (!selectedKanjiData || !selectedKanjiData.stroke_data?.strokes?.length) {
      finish(0.05, 'Dash reflex sharpened. +5% miss per ability.')
      return
    }

    const strokeData = selectedKanjiData.stroke_data
    const totalStrokes = strokeData.strokes.length
    const failThreshold = challengeCfg.failThreshold === 'halfUp'
      ? Math.ceil(totalStrokes / 2)
      : (typeof challengeCfg.failThreshold === 'number' ? challengeCfg.failThreshold : Math.ceil(totalStrokes / 2))

    this.challengeActive = true
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)

    this.startKanjiDrawingChallenge(strokeData, `Dash! Draw ${selectedKanjiData.character}:`, {
      onComplete: (result) => {
        this.challengeActive = false
        this.setSkillButtonsEnabled(true)
        this.endTurnBtn.setVisible(true)

        const passed = result.completed && result.wrongStrokes < failThreshold
        if (passed) {
          finish(0.07, `${selectedKanjiData.character} drawn! Dash reflex honed. +7% miss per ability.`)
        } else {
          finish(0.03, `${selectedKanjiData.character} failed! Dash reflex dulled. +3% miss per ability.`)
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
    }, selectedKanjiData)
  }

  startBerserkChallenge(skill) {
    const challengeCfg = skill.kanjiChallenge || {}

    const finish = (percent, logMsg) => {
      this.player.addBerserkLifesteal(percent)
      this.challengeActive = false
      this.setSkillButtonsEnabled(true)
      this.endTurnBtn.setVisible(true)
      this.addCombatLog(logMsg)
      this.spawnFloatingText(
        this.playerSprite.x,
        this.playerSprite.y - 60,
        `Berserk +${percent.toFixed(0)}%`,
        0xf1c40f
      )
      this.executeSkill('success')
    }

    // 10% chance to skip the challenge entirely — default 10% lifesteal.
    const skipChance = challengeCfg.skipChance ?? 0.1
    if (skipChance > 0 && Math.random() < skipChance) {
      finish(10, 'Berserk rage takes hold. +10% lifesteal.')
      return
    }

    // Pick a kanji from the berserk pool; 20% chance to use the focus kanji instead.
    const pool = skill.kanjiPool || []
    const focusOverrideChance = challengeCfg.focusOverrideChance ?? 0.2
    const focusKanjiData = this.player.loadout.focusKanjiData
    let selectedKanjiData = null

    if (focusKanjiData && focusOverrideChance > 0 && Math.random() < focusOverrideChance && focusKanjiData.stroke_data?.strokes?.length > 0) {
      selectedKanjiData = focusKanjiData
    } else {
      const allKanji = getWindowGameData()?.all_kanji || []
      const candidates = pool
        .map(char => {
          const fromList = this.player.kanjiList.find(k => k.character === char)
          if (fromList?.stroke_data?.strokes?.length > 0) return fromList
          const fromAll = allKanji.find(k => k.character === char)
          if (fromAll?.stroke_data?.strokes?.length > 0) return fromAll
          return null
        })
        .filter(Boolean)
      if (candidates.length > 0) {
        selectedKanjiData = candidates[Math.floor(Math.random() * candidates.length)]
      }
    }

    // No usable stroke data: apply the default lifesteal.
    if (!selectedKanjiData || !selectedKanjiData.stroke_data?.strokes?.length) {
      finish(10, 'Berserk rage takes hold. +10% lifesteal.')
      return
    }

    const strokeData = selectedKanjiData.stroke_data
    const totalStrokes = strokeData.strokes.length

    this.startKanjiDrawingChallenge(strokeData, `Berserk! Draw ${selectedKanjiData.character}:`, {
      onComplete: (result) => {
        this.challengeActive = false
        this.setSkillButtonsEnabled(true)
        this.endTurnBtn.setVisible(true)

        this.player.setKanjiStrokeCount(totalStrokes)
        if (result.completed) {
          this.player.setKanjiResult(result.wrongStrokes)
          const cleanStrokes = Math.max(0, totalStrokes - result.wrongStrokes)
          const bonus = 2 * cleanStrokes
          const totalPercent = 10 + bonus
          finish(totalPercent, `${selectedKanjiData.character} drawn! Berserk rage grows. +${totalPercent.toFixed(0)}% lifesteal (${cleanStrokes} clean strokes).`)
        } else {
          this.player.setKanjiResult(99)
          finish(8, `${selectedKanjiData.character} failed! Berserk rage flickers. +8% lifesteal.`)
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
    }, selectedKanjiData)
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

  getDisplayForEnemy(enemy) {
    return this.enemyDisplays.find(d => d.enemy === enemy)
  }

  grantFirstDefeatRewards(enemy) {
    const rewards = enemy.definition?.firstDefeatRewards || []
    if (rewards.length === 0) return

    for (const reward of rewards) {
      if (reward.type === 'charm') {
        const result = this.player.addCharm(reward.id)
        if (result.owned) {
          this.addCombatLog(`First defeat reward: ${getCharmById(reward.id)?.name || reward.id} unlocked!`)
        }
      } else if (reward.type === 'socketCharm') {
        if (this.player.addSocketCharm(reward.id)) {
          const charm = getSocketCharmById?.(reward.id)
          this.addCombatLog(`First defeat reward: ${charm?.name || reward.id} unlocked!`)
        }
        // Also mark it as unlocked in the shop catalogue.
        if (!this.player.loadout.unlockedSocketCharmIds.includes(reward.id)) {
          this.player.loadout.unlockedSocketCharmIds.push(reward.id)
          this.player.saveLoadout()
        }
      }
    }
  }

  onEnemyDefeated(enemy) {
    const display = this.getDisplayForEnemy(enemy)
    if (!display || display.defeated) return
    display.defeated = true

    const roles = enemy.definition?.roles || []
    let essenceGained = 0
    if (this.tile?.type === TILE_TYPES.BATTLE && roles.includes('battle')) {
      if (!this.normalBattleEssenceAwarded) {
        essenceGained = this.player.rollNormalBattleEssence()
        this.normalBattleEssenceAwarded = true
      }
    } else if (this.tile?.type === TILE_TYPES.MINI_BOSS && roles.includes('mini_boss')) {
      essenceGained = this.player.rollMiniBossEssence()
    } else if (this.tile?.type === TILE_TYPES.BOSS && roles.includes('boss')) {
      const mapDef = getMapDefinition(this.mapIndex)
      essenceGained = this.player.rollMapBossEssence(mapDef?.level)
    }

    if (essenceGained > 0) {
      this.essenceGainedThisBattle += essenceGained
      this.addCombatLog(`+${essenceGained} Ouro Essence`)
    } else {
      this.addCombatLog('No Ouro Essence this time.')
    }

    this.addCombatLog(`${enemy.name || 'Enemy'} defeated!`)
    this.grantFirstDefeatRewards(enemy)

    display.sprite.disableInteractive()
    display.sprite.setTexture(this.getEnemySpriteKey(enemy, 'death'))
    if (display.intentionBtn) display.intentionBtn.setVisible(false)
    this.closeIntentionBubble(display)

    // Fade out the sprite and collapse the UI.
    this.tweens.add({
      targets: display.sprite,
      alpha: 0,
      scale: display.sprite.scale * 0.6,
      y: display.sprite.y + 30,
      duration: 700,
      ease: 'Quad.easeIn',
    })

    const uiElements = [
      display.nameBg,
      display.nameText,
      display.jaText,
      display.hpBg,
      display.hpBar,
      display.staminaBg,
      display.staminaBar,
      display.hpText,
      display.staminaText,
      display.blockText,
      display.statusContainer,
    ]
    for (const el of uiElements) {
      if (el) el.setVisible(false)
    }
  }

  executeSkill(challengeResult) {
    const target = this.selectedTarget || this.turnManager.getAliveEnemies()[0]
    if (!target) return

    const result = this.turnManager.useSkill(
      this.selectedSkill,
      this.player,
      target,
      challengeResult
    )

    if (!result) {
      this.addCombatLog('Skill failed!')
      return
    }

    // Consume a charge for single-use abilities and refresh the action bar.
    if (this.selectedSkill.singleUse) {
      this.player.consumeAbilityCharge(this.selectedSkill.id)
      this._refreshSkillButtons()
    }

    if (!target.isAlive()) {
      this.onEnemyDefeated(target)
    } else if (target.checkPhaseTransition) {
      if (target.checkPhaseTransition((msg) => this.addCombatLog(msg))) {
        this.refreshEnemyDisplay(this.getDisplayForEnemy(target))
      }
    }

    const targetDisplay = this.getDisplayForEnemy(target)

    this.updateBars()
    this.updateBlockText()
    this.updateSkillButtonLabels()
    this.updatePlayerStatusButton()
    this.player.clearKanjiBonus()
    this.player.clearBasePowerBonus()

    const quality = challengeResult === 'perfect' ? 'Perfect!' : challengeResult === 'success' ? '' : 'Failed...'
    switch (result.type) {
      case 'attack': {
        const isHeavy = this.selectedSkill?.id === 'heavy_slash' || this.selectedSkill?.id === 'two_hand_heavy'
        this.setPlayerPose(isHeavy ? 'slash_heavy' : 'slash_light_01')
        const critText = result.isCrit ? ' CRITICAL!' : ''
        const bypassText = result.defenseBypassed ? ' (Defense pierced!)' : ''
        const lifestealText = result.lifesteal ? ` (+${result.lifesteal} HP)` : ''
        const infusedIcon = result.infusion ? (INFUSION_ICONS[result.infusion.value] || '✦') : ''
        const infusedText = result.infusion ? `${infusedIcon} Infused ` : ''
        if (result.missed) {
          this.addCombatLog(`${quality} ${this.selectedSkill.name} -> missed!`)
          if (targetDisplay) {
            this.spawnFloatingText(targetDisplay.sprite.x, targetDisplay.sprite.y - 40, 'MISS', COLORS.warning)
          }
          this.time.delayedCall(600, () => this.setPlayerPose('idle'))
          break
        }
        this.addCombatLog(`${quality} ${infusedText}${this.selectedSkill.name}${critText} -> ${result.damage} damage!${bypassText}${lifestealText}`)
        if (targetDisplay) {
          if (result.blocked) {
            this.spawnFloatingText(targetDisplay.sprite.x, targetDisplay.sprite.y - 50, 'NULLIFIED!', 0x3498db)
          } else {
            const dmgColor = this.getDamageColor(result, this.selectedSkill.element)
            this.spawnFloatingText(targetDisplay.sprite.x, targetDisplay.sprite.y - 40, `-${result.damage}`, dmgColor)
            this.shakeSprite(targetDisplay.sprite)
            if (target.isAlive()) {
              this.setEnemySprite(this.getEnemySpriteKey(target, 'defend'), target)
              this.time.delayedCall(350, () => {
                if (target.isAlive()) this.setEnemySprite(this.getEnemySpriteKey(target, 'default'), target)
              })
            }
            if (result.infusion && this.isComboElement(result.infusion.value)) {
              this.flashScreen(dmgColor, 120)
              this.shakeScreen(0.01, 180)
            }
          }
        }
        if (result.lifesteal) {
          this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${result.lifesteal}`, COLORS.success)
        }
        this.time.delayedCall(600, () => this.setPlayerPose('idle'))
        break
      }
      case 'defence': {
        this.setPlayerPose('block_idle')
        const infusedIcon = result.infusion ? (INFUSION_ICONS[result.infusion.value] || '✦') : ''
        const infusedText = result.infusion ? `${infusedIcon} Infused ` : ''
        this.addCombatLog(`${quality} ${infusedText}${this.selectedSkill.name} -> +${result.block} block!`)
        this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${result.block} Block`, 0x3498db)
        this.time.delayedCall(600, () => this.setPlayerPose('idle'))
        break
      }
      case 'attack_defence': {
        this.setPlayerPose('block_idle')
        const critText = result.isCrit ? ' CRITICAL!' : ''
        const bypassText = result.defenseBypassed ? ' (Defense pierced!)' : ''
        const infusedIcon = result.infusion ? (INFUSION_ICONS[result.infusion.value] || '✦') : ''
        const infusedText = result.infusion ? `${infusedIcon} Infused ` : ''
        if (result.missed) {
          this.addCombatLog(`${quality} ${this.selectedSkill.name} -> missed!`)
          if (targetDisplay) {
            this.spawnFloatingText(targetDisplay.sprite.x, targetDisplay.sprite.y - 40, 'MISS', COLORS.warning)
          }
          this.time.delayedCall(600, () => this.setPlayerPose('idle'))
          break
        }
        this.addCombatLog(`${quality} ${infusedText}${this.selectedSkill.name}${critText} -> ${result.damage} damage + ${result.block} block!${bypassText}`)
        if (targetDisplay) {
          if (result.blocked) {
            this.spawnFloatingText(targetDisplay.sprite.x, targetDisplay.sprite.y - 50, 'NULLIFIED!', 0x3498db)
          } else {
            const dmgColor = this.getDamageColor(result, this.selectedSkill.element)
            this.spawnFloatingText(targetDisplay.sprite.x, targetDisplay.sprite.y - 40, `-${result.damage}`, dmgColor)
            this.shakeSprite(targetDisplay.sprite)
            if (target.isAlive()) {
              this.setEnemySprite(this.getEnemySpriteKey(target, 'defend'), target)
              this.time.delayedCall(350, () => {
                if (target.isAlive()) this.setEnemySprite(this.getEnemySpriteKey(target, 'default'), target)
              })
            }
            if (result.infusion && this.isComboElement(result.infusion.value)) {
              this.flashScreen(dmgColor, 120)
              this.shakeScreen(0.01, 180)
            }
          }
        }
        this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `+${result.block} Block`, 0x3498db)
        this.time.delayedCall(600, () => this.setPlayerPose('idle'))
        break
      }
      case 'buff': {
        const buffLabel = result.buffType === 'sword_damage_bonus' ? 'Blade sharpened!' : result.buffType === 'berserk_lifesteal' ? 'Berserk rage!' : 'Buff active'
        this.addCombatLog(`${quality} ${this.selectedSkill.name} -> ${buffLabel}`)
        this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, buffLabel, 0xf39c12)
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

    // Dash reflex: every non-Dash ability used during the player turn builds miss chance for the enemy turn.
    if (this.player.dashBonusPerAbility > 0 && this.selectedSkill?.id !== 'dash') {
      const bonus = this.player.dashBonusPerAbility
      this.player.addTurnMissChance(bonus)
      this.addCombatLog(`Dash reflex +${(bonus * 100).toFixed(0)}%. Enemy miss chance now ${(this.player.turnMissChance * 100).toFixed(0)}%.`)
      this.spawnFloatingText(
        this.playerSprite.x,
        this.playerSprite.y - 90,
        `Reflex +${(bonus * 100).toFixed(0)}%`,
        0x2ecc71
      )
    }

    // Trigger socket hit procs for attacks that dealt damage.
    if ((result.type === 'attack' || result.type === 'attack_defence') && result.damage > 0) {
      this.socketProcSystem.trigger('on_hit', { scene: this, target, result })
      this.updateBars()
    }

    // If the skill killed the last enemy, TurnManager already ends the battle.
    // Otherwise, let the player continue acting.
  }

  // ---------- Enemy AI ----------

  async onTurnChange(turn) {
    this.updateBars()
    this.updateBlockText()
    this.updatePlayerStatusButton()

    if (turn === 'player') {
      this.turnText.setText('YOUR TURN')
      this.turnText.setColor(COLORS.text)
      this.animateTurnChange()
      this.setSkillButtonsEnabled(true)
      this.endTurnBtn.setVisible(true)
      this.updateSkillButtonLabels()
      // Reset per-turn flags
      this.player.resetReadiness()
      this.player.resetTurnMissChance()
      // Trigger socket start-of-turn procs
      this.socketProcSystem.trigger('on_turn_start', { scene: this })
      this.updateBars()
      // Show what each enemy will do on the upcoming turn
      this.showIntentionPlan()
    } else {
      if (this.pendingInfusion) this.clearInfusionMode()
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

    // Per-enemy state for the whole enemy-team turn.
    const enemyState = new Map()
    for (const enemy of this.turnManager.enemies) {
      enemyState.set(enemy, { usedBuff: false, actionsTaken: 0 })
    }

    const pendingSummons = []

    while (this.turnManager.currentTurn === 'enemy' && !this.turnManager.battleOver) {
      let anyActionTaken = false

      for (const enemy of this.turnManager.enemies) {
        if (this.turnManager.battleOver) break
        if (!enemy.isAlive()) continue

        const state = enemyState.get(enemy)
        if (!enemy.shouldContinueTurn(state.actionsTaken)) continue

        const action = enemy.chooseAction(state.usedBuff)
        if (!action) continue

        this.currentAttackingEnemy = enemy
        this.player.lastReactionCorrect = false

        if (['buff', 'debuff', 'summon', 'transform'].includes(action.type)) state.usedBuff = true
        state.actionsTaken++

        // Per-ability challenge: word/kanji quiz to weaken or cancel the ability.
        // Supports a single `challenge` object or a `challenges` array.
        const challengeConfigs = action.challenges || (action.challenge ? [action.challenge] : [])
        let challengeModifier = null
        let weakestMultiplier = 1
        let effectChanceMultiplier = 1
        const context = enemy.getAbilityContext ? enemy.getAbilityContext(action) : {}
        for (const config of challengeConfigs) {
          if (Math.random() >= (config.chance ?? 0)) continue
          const challenge = buildEnemyChallenge(this.player, config)
          if (!challenge) continue
          challenge.abilityName = action.name
          this.addCombatLog(`${enemy.name || 'The enemy'}'s ${action.name} triggers a ${challenge.type === 'kanji' ? 'kanji' : 'word'} challenge!`)
          const outcome = await this.runEnemyAbilityChallenge(challenge)
          const outcomeType = typeof outcome === 'string' ? outcome : outcome?.type
          if (outcomeType === 'cancel' || outcomeType === 'neutralize') {
            challengeModifier = 'cancel'
            break
          }
          if (outcomeType === 'weaken') {
            challengeModifier = 'weaken'
            weakestMultiplier = Math.min(weakestMultiplier, config.weakenMultiplier || 0.5)
          }
          if (outcomeType === 'halveChance') {
            effectChanceMultiplier *= 0.5
          }
          if (outcomeType === 'boostChance') {
            effectChanceMultiplier *= 2.1
          }
          if (outcomeType === 'setChance') {
            context.chanceOverrides = context.chanceOverrides || {}
            context.chanceOverrides[outcome.effectId] = outcome.value
          }
          if (outcomeType === 'setValue') {
            context.valueOverrides = context.valueOverrides || {}
            context.valueOverrides[outcome.key] = outcome.value
          }
        }
        if (challengeModifier === 'cancel') {
          enemy.incrementAbilityUses(action)
          this.addCombatLog(`${enemy.name || 'The enemy'} tries ${action.name}, but you cancel it!`)
          anyActionTaken = true
          await this.delay(800)
          continue
        }

        // Before an attack, check for reaction challenge trigger
        if (action.type === 'attack') {
          const diceRoll = this.roll2d6()
          const triggerChance = (this.player.luck * 0.1 * diceRoll) / 100
          if (Math.random() < triggerChance) {
            this.addCombatLog('Reaction opportunity!')
            await this.runReactionChallenge()
          }
        }

        let result
        let parried = false

        // Parry check (only for attacks, after reaction challenge)
        if (action.type === 'attack' && this.player.hasActiveParry()) {
          const parryChance = this.player.getParryChance()
          this.addCombatLog(`Parry chance: ${(parryChance * 100).toFixed(0)}%`)
          // Consume one parry charge regardless of whether the parry succeeds.
          this.player.consumeParryCharge()
          if (Math.random() < parryChance) {
            parried = true
            result = { type: 'attack', damage: 0, isCrit: false, missed: false, parried: true }
            // Parry is already set up and paid for — no additional cost here
            this.addCombatLog('Parry triggered! Counter-attack incoming!')
            // Reset reaction multiplier since parry replaces the attack
            this.player.reactionMultiplier = 1
          }
          this.updatePlayerStatusButton()
        }

        if (challengeModifier === 'weaken') {
          context.damageMultiplier = weakestMultiplier
        }
        if (effectChanceMultiplier !== 1) {
          context.effectChanceMultiplier = effectChanceMultiplier
        }

        if (!parried) {
          result = enemy.performAction(action, this.player, context, (msg) => this.addCombatLog(msg))
        }

        // Reset reaction multiplier after the attack resolves
        const reactionMult = this.player.reactionMultiplier
        this.player.reactionMultiplier = 1

        this.updateBars()
        this.updateBlockText()
        if (this.turnManager.checkBattleOver(enemy)) break

        const display = this.getDisplayForEnemy(enemy)
        const enemyName = enemy.name || 'The enemy'

        switch (result.type) {
          case 'attack': {
            this.setEnemySprite(this.getEnemySpriteKey(enemy, 'attack'), enemy)
            if (result.parried) {
              this.setPlayerPose('block_idle')
              const reactionText = reactionMult !== 1 ? (reactionMult > 1 ? ' (Reaction bonus!)' : ' (Reaction failed...)') : ''
              this.addCombatLog(`${enemyName} uses ${action.name}... PARRIED!${reactionText}`)
              this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, 'PARRIED!', 0x9b59b6)
              await this.delay(600)
              this.setPlayerPose('idle')
              this.setEnemySprite(this.getEnemySpriteKey(enemy, 'default'), enemy)
              await this.runCounterAttack()
            } else if (result.missed) {
              const reactionText = reactionMult !== 1 ? (reactionMult > 1 ? ' (PARRY!)' : ' (Reaction failed...)') : ''
              this.addCombatLog(`${enemyName} uses ${action.name}... but missed!${reactionText}`)
              this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, 'MISS', COLORS.warning)
              await this.delay(800)
              this.setPlayerPose('idle')
              this.setEnemySprite(this.getEnemySpriteKey(enemy, 'default'), enemy)
            } else if (result.blocked) {
              const reactionText = reactionMult !== 1 ? (reactionMult > 1 ? ' (PARRY!)' : ' (Reaction failed...)') : ''
              this.addCombatLog(`${enemyName} uses ${action.name}... BLOCKED by your guard!${reactionText}`)
              this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, 'BLOCKED!', 0x3498db)
              await this.delay(800)
              this.setPlayerPose('idle')
              this.setEnemySprite(this.getEnemySpriteKey(enemy, 'default'), enemy)
            } else {
              this.setPlayerPose('block_idle')
              const weakenedText = challengeModifier === 'weaken' ? ' (Weakened!)' : ''
              const critText = result.isCrit ? ' CRITICAL!' : ''
              const reactionText = reactionMult !== 1 ? (reactionMult > 1 ? ' (PARRY!)' : ' (Reaction failed...)') : ''
              this.addCombatLog(`${enemyName} uses ${action.name}${critText}! You take ${result.damage} damage!${reactionText}${weakenedText}`)
              const dmgColor = this.getDamageColor(result, action.element, 'enemy')
              this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `-${result.damage}`, dmgColor)
              this.shakeSprite(this.playerSprite)
              if (action.element && this.isComboElement(action.element)) {
                this.flashScreen(dmgColor, 120)
                this.shakeScreen(0.01, 180)
              }
              // Trigger socket defend procs now that damage has been taken.
              this.socketProcSystem.trigger('on_defend', { scene: this, source: enemy, result })
              this.updateBars()
              await this.delay(800)
              this.setPlayerPose('idle')
              this.setEnemySprite(this.getEnemySpriteKey(enemy, 'default'), enemy)
            }
            break
          }
          case 'debuff': {
            const debuffSpriteKey = action.sprite || this.getEnemySpriteKey(enemy, 'attack')
            this.setEnemySprite(debuffSpriteKey, enemy)
            if (result.missed) {
              this.addCombatLog(`${enemyName} uses ${action.name}... but missed!`)
              this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, 'MISS', COLORS.warning)
            } else if (result.blocked) {
              this.addCombatLog(`${enemyName} uses ${action.name}... BLOCKED by your guard!`)
              this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, 'BLOCKED!', 0x3498db)
            } else {
              const critText = result.isCrit ? ' CRITICAL!' : ''
              const damageText = result.damage > 0 ? ` You take ${result.damage} damage!` : ''
              this.addCombatLog(`${enemyName} uses ${action.name}${critText}!${damageText}`)
              if (result.damage > 0) {
                const dmgColor = this.getDamageColor(result, action.element, 'enemy')
                this.spawnFloatingText(this.playerSprite.x, this.playerSprite.y - 40, `-${result.damage}`, dmgColor)
                this.shakeSprite(this.playerSprite)
              }
            }
            this.updateBars()
            await this.delay(800)
            this.setEnemySprite(this.getEnemySpriteKey(enemy, 'default'), enemy)
            break
          }
          case 'buff': {
            this.setEnemySprite(this.getEnemySpriteKey(enemy, 'buff'), enemy)
            this.addCombatLog(`${enemyName} uses ${action.name}! Its next attack will be stronger!`)
            this.time.delayedCall(800, () => this.setEnemySprite(this.getEnemySpriteKey(enemy, 'default'), enemy))
            break
          }
          case 'recover': {
            this.addCombatLog(`${enemyName} rests and recovers ${result.stamina} stamina.`)
            break
          }
          case 'heal': {
            this.setEnemySprite(this.getEnemySpriteKey(enemy, 'buff'), enemy)
            const cleanseText = result.cleansed && result.cleansed.length > 0 ? ` Cleansed ${result.cleansed.length} ailments.` : ''
            const buffText = result.buff ? ` ${getEffect(result.buff.effectId)?.name || result.buff.effectId} (${result.buff.remainingTurns} turns).` : ''
            this.addCombatLog(`${enemyName} drinks sake and recovers ${result.healed} HP!${cleanseText}${buffText}`)
            this.spawnFloatingText(display.sprite.x, display.sprite.y - 40, `+${result.healed}`, COLORS.success)
            this.updateBars()
            await this.delay(800)
            this.setEnemySprite(this.getEnemySpriteKey(enemy, 'default'), enemy)
            break
          }
          case 'summon': {
            if (result.failed) {
              this.addCombatLog(`${enemyName}'s ${action.name} fizzles into leaves!`)
            } else {
              this.addCombatLog(`${enemyName} weaves ${action.name}!`)
              const summoned = this.createSummonedEnemies(result)
              pendingSummons.push(...summoned)
            }
            await this.delay(800)
            break
          }
          case 'transform': {
            if (result.transformDef) {
              this.addCombatLog(`${enemyName} shifts shape with ${action.name}!`)
              this.transformEnemy(enemy, result)
            } else {
              this.addCombatLog(`${enemyName}'s ${action.name} fails!`)
            }
            await this.delay(800)
            break
          }
        }

        anyActionTaken = true
        await this.delay(1000)

        if (this.turnManager.battleOver) break
      }

      if (!anyActionTaken) break
    }

    if (pendingSummons.length > 0) {
      for (const enemy of pendingSummons) {
        this.turnManager.enemies.push(enemy)
        const display = this.createEnemyDisplay(enemy, this.enemyDisplays.length, this.enemyDisplays.length + 1)
        this.enemyDisplays.push(display)
      }
      this.relayoutEnemyDisplays()
      this.enemy = this.enemyDisplays[0]?.enemy || this.enemy
      this.addCombatLog(`${pendingSummons.length} tanuki clone(s) appear!`)
    }

    this.currentAttackingEnemy = null

    if (!this.turnManager.battleOver) {
      this.turnManager.endTurn()
    }
  }

  runEnemyAbilityChallenge(challenge) {
    return new Promise((resolve) => {
      const system = new EnemyAbilityChallengeSystem(this)
      system.start(challenge, ({ success }) => {
        const outcome = success ? (challenge.onSuccess || 'weaken') : (challenge.onFail || 'full')
        resolve(outcome)
      })
    })
  }

  async runCounterAttack() {
    const attackAction = this.player.activeActions.find(a => a.type === 'attack')
    if (!attackAction) {
      this.addCombatLog('No attack action equipped — counter fails!')
      return
    }

    const parryAction = this.player.activeActions.find(a => a.type === 'parry')
    if (!parryAction) {
      this.addCombatLog('No parry ability equipped — counter fails!')
      return
    }

    this.addCombatLog(`Counter-attack with ${attackAction.name}!`)

    return new Promise((resolve) => {
      this.resolveParryKanjiChallenge(parryAction, {
        onComplete: (outcome) => {
          const result = {
            completed: outcome.quality !== 'fail',
            wrongStrokes: outcome.quality === 'perfect' ? 0 : (outcome.quality === 'sloppy' ? 1 : 999)
          }
          this.executeCounterAttack(attackAction, result)
          resolve()
        },
        onWrongStroke: ({ count }) => {
          this.spawnFloatingText(
            GAME_CONFIG.width / 2,
            GAME_CONFIG.height / 2 - 180,
            `Wrong stroke! (${count})`,
            COLORS.danger
          )
        },
      }, 'Counter!')
    })
  }

  executeCounterAttack(action, kanjiResult) {
    const target = this.currentAttackingEnemy || this.turnManager.getAliveEnemies()[0]
    if (!target) return

    let multiplier = 0.5
    if (kanjiResult.completed) {
      if (kanjiResult.wrongStrokes === 0) multiplier = 1.0
      else if (kanjiResult.wrongStrokes <= 2) multiplier = 0.75
    }

    const baseDmg = this.player.calculateWeaponDamage(action)
    const counterDmg = Math.max(1, Math.floor(baseDmg * multiplier))
    const actual = target.takeDamage(counterDmg)

    if (!target.isAlive()) {
      this.onEnemyDefeated(target)
    }

    this.turnManager.checkBattleOver(this.player)

    const targetDisplay = this.getDisplayForEnemy(target)
    this.setPlayerPose('slash_light_01')
    const qualityText = multiplier >= 1.0 ? 'Perfect counter!' : multiplier >= 0.75 ? 'Solid counter!' : 'Weak counter!'
    this.addCombatLog(`${qualityText} ${action.name} -> ${actual} damage!`)
    if (targetDisplay) {
      this.spawnFloatingText(targetDisplay.sprite.x, targetDisplay.sprite.y - 40, `-${actual}`, COLORS.danger)
      this.shakeSprite(targetDisplay.sprite)
    }

    this.time.delayedCall(600, () => this.setPlayerPose('idle'))
  }

  // ---------- UI Updates ----------

  updateBars() {
    this.updateBar('playerHp', this.player.hp, this.player.maxHp)
    this.updateBar('playerStamina', this.player.stamina, this.player.maxStamina)

    this.playerHpText.setText(`${this.player.hp}/${this.player.maxHp}`)
    this.playerStaminaText.setText(`${this.player.stamina}/${this.player.maxStamina}`)
    this.updatePlayerStatusIcons()
    this.updatePlayerStatusButton()

    for (const display of this.enemyDisplays) {
      const e = display.enemy
      const hpPct = Math.max(0, e.hp / e.maxHp)
      display.hpBar.setScale(hpPct, 1)
      display.hpBar.setFillStyle(hpPct <= 0.25 ? COLORS.danger : COLORS.hp)
      const staminaPct = Math.max(0, e.stamina / e.maxStamina)
      display.staminaBar.setScale(staminaPct, 1)
      display.hpText.setText(`${e.hp}/${e.maxHp}`)
      display.staminaText.setText(`${e.stamina}/${e.maxStamina}`)
      this.updateStatusIcons(display)
    }
  }

  createStatusIcon(entry, x, y) {
    const effect = getEffect(entry.effectId)
    const icon = STATUS_EFFECT_ICONS[entry.effectId] || (effect ? effect.name.charAt(0).toUpperCase() : '?')
    const iconText = this.add.text(x, y - 2, icon, {
      fontFamily: FONTS.default.fontFamily,
      fontSize: '18px',
    }).setOrigin(0.5)
    const turnsText = this.add.text(x + 9, y + 9, `${entry.remainingTurns}`, {
      fontFamily: FONTS.default.fontFamily,
      fontSize: '10px',
      color: '#ffffff',
      stroke: '#000000',
      strokeThickness: 2,
    }).setOrigin(0.5)
    return [iconText, turnsText]
  }

  updateStatusIcons(display) {
    if (!display.statusContainer) return
    display.statusContainer.removeAll(true)

    if (display.defeated || !display.enemy.isAlive()) {
      display.statusContainer.setVisible(false)
      return
    }

    const effects = display.enemy.activeEffects
    if (effects.length === 0) {
      display.statusContainer.setVisible(false)
      return
    }

    const iconWidth = 30
    const totalWidth = effects.length * iconWidth
    let offsetX = -totalWidth / 2 + iconWidth / 2

    for (const entry of effects) {
      display.statusContainer.add(this.createStatusIcon(entry, offsetX, 0))
      offsetX += iconWidth
    }

    display.statusContainer.setVisible(true)
  }

  updatePlayerStatusIcons() {
    if (!this.playerStatusContainer) return
    this.playerStatusContainer.removeAll(true)

    const effects = this.player.activeEffects
    if (effects.length === 0) {
      this.playerStatusContainer.setVisible(false)
      return
    }

    const iconWidth = 30
    const totalWidth = effects.length * iconWidth
    let offsetX = -totalWidth / 2 + iconWidth / 2

    for (const entry of effects) {
      this.playerStatusContainer.add(this.createStatusIcon(entry, offsetX, 0))
      offsetX += iconWidth
    }

    this.playerStatusContainer.setVisible(true)
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
    for (const display of this.enemyDisplays) {
      display.blockText.setText(display.enemy.block > 0 ? `Block: ${display.enemy.block}` : '')
    }
  }

  setSkillButtonsEnabled(enabled) {
    this.skillButtons.forEach(({ btn, skill }) => {
      // Use Item needs at least 1 stamina (minimum item cost)
      const cantUseItem = skill.type === 'item' && this.player.stamina < 1

      if (enabled && this.player.canUseSkill(skill) && !cantUseItem) {
        btn.redraw(btn.color)
        btn.hitArea.setInteractive({ useHandCursor: true })
        btn.text.setAlpha(1)
      } else {
        btn.redraw(COLORS.buttonDisabled)
        btn.hitArea.disableInteractive()
        btn.text.setAlpha(0.6)
      }
    })

    // Switch Action button (costs 1 stamina to use)
    if (enabled && this.turnManager.currentTurn === 'player' && this.player.stamina >= 1) {
      this.switchActionBtn.redraw(this.switchActionBtn.color)
      this.switchActionBtn.hitArea.setInteractive({ useHandCursor: true })
      this.switchActionBtn.text.setAlpha(1)
    } else {
      this.switchActionBtn.redraw(COLORS.buttonDisabled)
      this.switchActionBtn.hitArea.disableInteractive()
      this.switchActionBtn.text.setAlpha(0.6)
    }
  }

  addCombatLog(msg) {
    this.combatLogHistory.unshift({ turn: this.turnManager?.turnCount ?? 0, message: msg })
    if (this.combatLogHistory.length > 40) this.combatLogHistory.pop()

    this.combatLogText.setText(msg)
    this.drawCombatLogBg()
    // Reset alpha animation
    this.combatLogText.setAlpha(1)
    this.combatLogBg.setAlpha(1)
    this.tweens.killTweensOf([this.combatLogText, this.combatLogBg])
    this.tweens.add({
      targets: [this.combatLogText, this.combatLogBg],
      alpha: 0.75,
      duration: 2500,
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

  shakeScreen(intensity = 0.008, duration = 200) {
    if (this.cameras.main && typeof this.cameras.main.shake === 'function') {
      this.cameras.main.shake(duration, intensity)
    }
  }

  flashScreen(color = 0xffffff, duration = 150) {
    if (!this.flashOverlay) {
      this.flashOverlay = this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, color, 0).setOrigin(0.5).setDepth(250)
    } else {
      this.flashOverlay.setFillStyle(color, 0)
      this.flashOverlay.setAlpha(1)
    }
    this.tweens.killTweensOf(this.flashOverlay)
    this.flashOverlay.setFillStyle(color, 0.35)
    this.tweens.add({
      targets: this.flashOverlay,
      alpha: 0,
      duration,
      ease: 'Linear',
    })
  }

  getElementColor(element) {
    const map = {
      fire: 0xe74c3c,
      water: 0x3498db,
      wind: 0x2ecc71,
      earth: 0xa0522d,
      void: 0x9b59b6,
      poison: 0x2ecc71,
      physical: 0xcccccc,
    }
    return map[element] || COLORS.danger
  }

  getDamageColor(result, fallbackElement, source = 'player') {
    if (result.infusion) {
      const effective = getElementForInfusion(result.infusion.value) || result.infusion.value
      return this.getElementColor(effective)
    }
    if (source === 'enemy' && result.element) {
      const effective = getElementForInfusion(result.element) || result.element
      return this.getElementColor(effective)
    }
    if (fallbackElement) return this.getElementColor(getElementForInfusion(fallbackElement) || fallbackElement)
    return COLORS.danger
  }

  isComboElement(value) {
    return value && getElementForInfusion(value) && getElementForInfusion(value) !== value
  }

  // ---------- Battle End ----------

  onBattleEnd(winner) {
    this.setSkillButtonsEnabled(false)
    this.endTurnBtn.setVisible(false)
    this.challengeOverlay.setVisible(false)
    this.challengeActive = false

    const representativeEnemy = this.enemies[0]
    const isWin = winner === 'player'
    if (isWin) {
      // Enemies that died from status effects won't have gone through the normal
      // defeat path, so process them now to award essence, first-defeat rewards, etc.
      for (const enemy of this.enemies) {
        if (!enemy.isAlive()) {
          this.onEnemyDefeated(enemy)
        }
      }

      for (const display of this.enemyDisplays) {
        if (display.enemy.isAlive()) {
          display.sprite.setTexture(this.getEnemySpriteKey(display.enemy, 'death'))
        }
      }
      // Determine if this win completes the entire run (final boss).
      const isRunVictory =
        this.tile?.type === TILE_TYPES.BOSS &&
        getMapDefinition(this.mapIndex).isFinal !== false

      // Send result to server before transitioning
      const runResultPayload = {
        winner,
        playerHp: this.player.hp,
        enemyHp: representativeEnemy.hp,
        turnCount: this.turnManager.turnCount,
        timestamp: new Date().toISOString(),
      }
      if (isRunVictory && this.player.loadout.focusKanji) {
        runResultPayload.focus_kanji = this.player.loadout.focusKanji
      }
      sendRunResult(runResultPayload)

      if (this.tile?.type === TILE_TYPES.BOSS) {
        const mapDef = getMapDefinition(this.mapIndex)
        // Defaults to final when the flag is missing, so early-release maps
        // always show the run-victory screen.
        if (mapDef.isFinal !== false) {
          const beforeScales = this.player.loadout.ouroScales || 0
          const beforeSource = this.player.loadout.ouroSource || 0
          const beforeUnlocked = new Set(this.player.loadout.unlockedAbilityIds || [])

          this.player.endRun(true)

          const rewards = {
            ouroScales: (this.player.loadout.ouroScales || 0) - beforeScales,
            ouroSource: (this.player.loadout.ouroSource || 0) - beforeSource,
            ouroEssence: this.essenceGainedThisBattle,
          }
          const unlockedId = (this.player.loadout.unlockedAbilityIds || []).find(id => !beforeUnlocked.has(id))
          rewards.unlockedAbility = unlockedId ? ALL_ACTIONS.find(a => a.id === unlockedId) : null

          this.scene.start('RunVictoryScene', { player: this.player, rewards })
        } else {
          this.player.completeTile(this.tile.id)
          this.player.advanceMap()
          this.scene.start('MapScene', { player: this.player })
        }
        return
      }

      // Mark the tile completed immediately so the map state is correct even if
      // the player gambles/closes the WinScene before clicking Continue.
      if (this.tile?.id) this.player.completeTile(this.tile.id)
      this.scene.start('WinScene', { player: this.player, enemy: representativeEnemy, tile: this.tile, essenceGained: this.essenceGainedThisBattle })
      return
    }

    // Defeat handling — return to map and restart current map
    this.setPlayerPose('defeated')

    const title = 'DEFEAT...'
    const color = COLORS.danger
    const killerName = this.currentAttackingEnemy?.name || representativeEnemy?.name || 'The enemy'

    // Overlay
    const overlay = this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.6).setDepth(200)
    const panel = this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, 400, 200, COLORS.panelBg).setDepth(200).setStrokeStyle(2, color)
    const titleText = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 40, title, {
      ...FONTS.title,
      fontSize: '32px',
      color: '#' + color.toString(16).padStart(6, '0'),
    }).setOrigin(0.5).setDepth(200)

    const subText = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 10, `${killerName} ended your run...`, {
      ...FONTS.default,
      fontSize: '16px',
    }).setOrigin(0.5).setDepth(200)

    const restartBtn = this.createButton(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 60, 'Return to Hero Select', () => {
      this.player.endRun(false)
      this.scene.start('HeroSelectScene', { player: this.player })
    }, 240, 44)
    restartBtn.bg.setDepth(200)
    restartBtn.text.setDepth(200)

    // Send result to server
    sendRunResult({
      winner,
      playerHp: this.player.hp,
      enemyHp: representativeEnemy.hp,
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
    if (this.wordChallenge) {
      this.wordChallenge.destroy()
    }
    if (window.visualViewport && this._onVisualViewportResize) {
      window.visualViewport.removeEventListener('resize', this._onVisualViewportResize)
    }
  }
}
