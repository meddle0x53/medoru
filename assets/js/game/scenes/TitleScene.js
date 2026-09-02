import { GAME_CONFIG, FONTS, COLORS } from '../config.js'
import Player, { loadoutKey } from '../entities/Player.js'
import { getWindowGameData } from '../api.js'
import { setupHighDPIWorld } from '../highDpi.js'

const SETTINGS_KEY = 'medoru_settings_v1'
const JLPT_LEVELS = [5, 4, 3, 2, 1]


export default class TitleScene extends Phaser.Scene {
  constructor() {
    super({ key: 'TitleScene' })
  }

  init() {
    this.settings = this.loadSettings()
  }

  create() {
    setupHighDPIWorld(this)
    this.hasActiveRun = this.checkActiveRun()

    this.createBackground()
    this.createTitle()
    this.createButtons()
    this.createConfirmationOverlay()
    this.createSettingsOverlay()
    this.setupFullscreenListeners()
  }

  loadSettings() {
    try {
      const raw = localStorage.getItem(SETTINGS_KEY)
      if (raw) {
        return { masterVolume: 1, sfxVolume: 1, fullscreen: false, ...JSON.parse(raw) }
      }
    } catch (e) {
      console.warn('[TitleScene] Failed to load settings:', e)
    }
    return { masterVolume: 1, sfxVolume: 1, fullscreen: false }
  }

  saveSettings() {
    try {
      localStorage.setItem(SETTINGS_KEY, JSON.stringify(this.settings))
    } catch (e) {
      console.warn('[TitleScene] Failed to save settings:', e)
    }
  }

  checkActiveRun() {
    try {
      const raw = localStorage.getItem(loadoutKey())
      if (raw) {
        const loadout = JSON.parse(raw)
        const map = loadout.mapState?.maps?.[loadout.mapState?.currentMapIndex]
        return !!map
      }
    } catch (e) {
      console.warn('[TitleScene] Failed to check active run:', e)
    }
    return false
  }

  createBackground() {
    this.add.image(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, 'title_screen')
      .setOrigin(0.5)
      .setDisplaySize(GAME_CONFIG.width, GAME_CONFIG.height)

    // Subtle dark overlay behind the title text for readability.
    this.add.rectangle(GAME_CONFIG.width / 2, 110, GAME_CONFIG.width, 120, 0x000000, 0.45)

    // Decorative top/bottom bars
    this.add.rectangle(GAME_CONFIG.width / 2, 6, GAME_CONFIG.width, 12, 0x16213e)
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height - 6, GAME_CONFIG.width, 12, 0x16213e)
  }

  createTitle() {
    this.add.text(GAME_CONFIG.width / 2, 110, 'The Hollow Ouroboros', {
      ...FONTS.title,
      fontSize: '42px',
      color: '#f1c40f',
    }).setOrigin(0.5)

    this.add.text(GAME_CONFIG.width / 2, 160, 'A Medoru Game', {
      ...FONTS.default,
      fontSize: '16px',
      color: '#bdc3c7',
    }).setOrigin(0.5)
  }

  createButtons() {
    const startY = 250
    const gap = 58
    const buttons = []

    if (this.hasActiveRun) {
      buttons.push({ label: 'Continue', color: 0x27ae60, hover: 0x2ecc71, callback: () => this.continueRun() })
    }

    buttons.push({ label: 'New Run', color: 0x2980b9, hover: 0x3498db, callback: () => this.newRun() })
    buttons.push({ label: 'Settings', color: 0x7f8c8d, hover: 0x95a5a6, callback: () => this.openSettings() })

    buttons.forEach((btn, index) => {
      this.createButton(GAME_CONFIG.width / 2, startY + index * gap, btn.label, btn.color, btn.hover, btn.callback)
    })
  }

  createButton(x, y, label, color, hoverColor, callback) {
    const width = 220
    const height = 46

    const bg = this.add.rectangle(0, 0, width, height, color).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: '18px',
      color: '#ffffff',
    }).setOrigin(0.5)

    const container = this.add.container(x, y, [bg, text])
    container.setSize(width, height)

    bg.on('pointerover', () => bg.setFillStyle(hoverColor))
    bg.on('pointerout', () => bg.setFillStyle(color))
    bg.on('pointerdown', () => {
      bg.setFillStyle(0xffffff)
      callback()
    })

    return container
  }

  continueRun() {
    const player = new Player(getWindowGameData())
    this.scene.start('MapScene', { player })
  }

  newRun() {
    if (this.hasActiveRun) {
      this.setOverlayInputEnabled(this.confirmationOverlay, true)
      this.confirmationOverlay.setVisible(true)
      return
    }
    this.startNewRun()
  }

  startNewRun() {
    const player = new Player(getWindowGameData())
    player.resetToFreshHero()
    this.scene.start('HeroSelectScene')
  }

  createConfirmationOverlay() {
    this.confirmationOverlay = this.add.container(0, 0).setDepth(200).setVisible(false)

    const backdrop = this.add.rectangle(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      GAME_CONFIG.width,
      GAME_CONFIG.height,
      0x000000,
      0.75,
    ).setOrigin(0.5)
    this.confirmationOverlay.add(backdrop)

    const panel = this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, 420, 200, 0x16213e)
      .setStrokeStyle(2, 0xe74c3c)
      .setOrigin(0.5)
    this.confirmationOverlay.add(panel)

    const title = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 60, 'Abandon Active Run?', {
      ...FONTS.title,
      fontSize: '22px',
      color: '#e74c3c',
    }).setOrigin(0.5)
    this.confirmationOverlay.add(title)

    const message = this.add.text(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2 - 20,
      'Starting a new run will erase your current progress.',
      {
        ...FONTS.default,
        fontSize: '14px',
        color: '#ecf0f1',
        align: 'center',
        wordWrap: { width: 360 },
      },
    ).setOrigin(0.5)
    this.confirmationOverlay.add(message)

    this.createConfirmationButton(GAME_CONFIG.width / 2 - 90, GAME_CONFIG.height / 2 + 40, 'Yes', 0xc0392b, 0xe74c3c, () => {
      this.confirmationOverlay.setVisible(false)
      this.setOverlayInputEnabled(this.confirmationOverlay, false)
      this.startNewRun()
    })

    this.createConfirmationButton(GAME_CONFIG.width / 2 + 90, GAME_CONFIG.height / 2 + 40, 'No', 0x27ae60, 0x2ecc71, () => {
      this.confirmationOverlay.setVisible(false)
      this.setOverlayInputEnabled(this.confirmationOverlay, false)
    })

    this.setOverlayInputEnabled(this.confirmationOverlay, false)
  }

  createConfirmationButton(x, y, label, color, hoverColor, callback) {
    const width = 120
    const height = 40
    const bg = this.add.rectangle(x, y, width, height, color).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(x, y, label, {
      ...FONTS.default,
      fontSize: '16px',
      color: '#ffffff',
    }).setOrigin(0.5)

    bg.on('pointerover', () => bg.setFillStyle(hoverColor))
    bg.on('pointerout', () => bg.setFillStyle(color))
    bg.on('pointerdown', callback)

    this.confirmationOverlay.add([bg, text])
  }

  openSettings() {
    this.setOverlayInputEnabled(this.settingsOverlay, true)
    this.settingsOverlay.setVisible(true)
    this.updateSettingsUI()
  }

  closeSettings() {
    this.settingsOverlay.setVisible(false)
    this.setOverlayInputEnabled(this.settingsOverlay, false)
  }

  /**
   * Enable or disable input on all interactive objects inside an overlay.
   * Hidden overlays must not steal touches from the title buttons.
   */
  setOverlayInputEnabled(overlay, enabled) {
    const walk = (obj) => {
      if (obj.input) {
        if (enabled) {
          if (obj.input.hitArea) {
            obj.setInteractive(obj.input.hitArea, obj.input.hitAreaCallback)
          } else {
            obj.setInteractive({ useHandCursor: true })
          }
        } else {
          obj.disableInteractive()
        }
      }
      if (obj.list && obj.list.length > 0) {
        obj.list.forEach(walk)
      }
    }
    walk(overlay)
  }

  createSettingsOverlay() {
    this.settingsOverlay = this.add.container(0, 0).setDepth(200).setVisible(false)

    // The kanji challenge settings live in the loadout (synced with the server
    // save); use a Player instance to read/write them like the game scenes do.
    this.player = new Player(getWindowGameData())

    const backdrop = this.add.rectangle(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      GAME_CONFIG.width,
      GAME_CONFIG.height,
      0x000000,
      0.75,
    ).setOrigin(0.5).setInteractive()
    this.settingsOverlay.add(backdrop)

    const panel = this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, 440, 440, 0x16213e)
      .setStrokeStyle(2, 0x3498db)
      .setOrigin(0.5)
    this.settingsOverlay.add(panel)

    const title = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 190, 'Settings', {
      ...FONTS.title,
      fontSize: '26px',
      color: '#f1c40f',
    }).setOrigin(0.5)
    this.settingsOverlay.add(title)

    this.masterVolumeText = this.add.text(GAME_CONFIG.width / 2 - 170, GAME_CONFIG.height / 2 - 140, 'Master Volume', {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
    }).setOrigin(0, 0.5)
    this.settingsOverlay.add(this.masterVolumeText)

    this.masterVolumeSlider = this.createSlider(GAME_CONFIG.width / 2 + 10, GAME_CONFIG.height / 2 - 140, this.settings.masterVolume, (value) => {
      this.settings.masterVolume = value
      this.saveSettings()
    })
    this.settingsOverlay.add(this.masterVolumeSlider.container)

    this.sfxVolumeText = this.add.text(GAME_CONFIG.width / 2 - 170, GAME_CONFIG.height / 2 - 90, 'SFX Volume', {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
    }).setOrigin(0, 0.5)
    this.settingsOverlay.add(this.sfxVolumeText)

    this.sfxVolumeSlider = this.createSlider(GAME_CONFIG.width / 2 + 10, GAME_CONFIG.height / 2 - 90, this.settings.sfxVolume, (value) => {
      this.settings.sfxVolume = value
      this.saveSettings()
    })
    this.settingsOverlay.add(this.sfxVolumeSlider.container)

    const fullscreenLabel = this.settings.fullscreen ? 'Fullscreen: On' : 'Fullscreen: Off'
    this.fullscreenButton = this.createSettingsButton(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2 - 30,
      fullscreenLabel,
      () => this.toggleFullscreen(),
    )
    this.settingsOverlay.add(this.fullscreenButton)

    this.createKanjiSettingsSection()

    const closeButton = this.createSettingsButton(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2 + 185,
      'Close',
      () => this.closeSettings(),
    )
    this.settingsOverlay.add(closeButton)

    this.setOverlayInputEnabled(this.settingsOverlay, false)
  }

  createKanjiSettingsSection() {
    if (this.kanjiSection) {
      this.kanjiSection.destroy()
    }
    this.kanjiSection = this.add.container(0, 0)
    this.settingsOverlay.add(this.kanjiSection)

    const cx = GAME_CONFIG.width / 2
    const cy = GAME_CONFIG.height / 2
    const loadout = this.player.loadout
    const mode = loadout.kanjiChallengeMode === 'free' ? 'free' : 'default'
    const selectedLevels = new Set(
      Array.isArray(loadout.freeKanjiLevels) && loadout.freeKanjiLevels.length > 0
        ? loadout.freeKanjiLevels
        : [5],
    )

    this.kanjiSection.add(
      this.add.text(cx, cy + 12, 'Kanji Challenges', {
        ...FONTS.default,
        fontSize: '14px',
        color: '#ecf0f1',
      }).setOrigin(0.5),
    )

    const defaultBtn = this.createToggleButton(cx - 85, cy + 46, 140, 32, 'Default', mode === 'default')
    const freeBtn = this.createToggleButton(cx + 85, cy + 46, 140, 32, 'Free Kanji', mode === 'free')
    this.kanjiSection.add([defaultBtn.container, freeBtn.container])

    defaultBtn.bg.on('pointerdown', () => this.setKanjiMode('default'))
    freeBtn.bg.on('pointerdown', () => this.setKanjiMode('free'))

    if (mode !== 'free') return

    const chipW = 56
    const chipGap = 8
    const totalW = JLPT_LEVELS.length * chipW + (JLPT_LEVELS.length - 1) * chipGap
    let chipX = cx - totalW / 2 + chipW / 2
    for (const level of JLPT_LEVELS) {
      const chip = this.createToggleButton(chipX, cy + 108, chipW, 30, `N${level}`, selectedLevels.has(level))
      this.kanjiSection.add(chip.container)
      chip.bg.on('pointerdown', () => this.toggleKanjiLevel(level, selectedLevels))
      chipX += chipW + chipGap
    }

    this.kanjiSection.add(
      this.add.text(cx, cy + 142, 'Free pools are rolled when a new run starts.', {
        ...FONTS.default,
        fontSize: '10px',
        color: '#7f8c8d',
      }).setOrigin(0.5),
    )
  }

  createToggleButton(x, y, w, h, label, active) {
    const color = active ? 0x3498db : 0x2c3e50
    const hoverColor = active ? 0x5dade2 : 0x34495e
    const bg = this.add.rectangle(x, y, w, h, color)
      .setInteractive({ useHandCursor: true })
      .setOrigin(0.5)
    const text = this.add.text(x, y, label, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ffffff',
    }).setOrigin(0.5)

    bg.on('pointerover', () => bg.setFillStyle(hoverColor))
    bg.on('pointerout', () => bg.setFillStyle(color))

    return { container: this.add.container(0, 0, [bg, text]), bg, text }
  }

  setKanjiMode(mode) {
    this.player.loadout.kanjiChallengeMode = mode
    this.player.saveLoadout()
    this.createKanjiSettingsSection()
    this.setOverlayInputEnabled(this.settingsOverlay, true)
  }

  toggleKanjiLevel(level, selectedLevels) {
    if (selectedLevels.has(level)) {
      // Keep at least one level selected so pools always have a source.
      if (selectedLevels.size <= 1) return
      selectedLevels.delete(level)
    } else {
      selectedLevels.add(level)
    }
    this.player.loadout.freeKanjiLevels = JLPT_LEVELS.filter(l => selectedLevels.has(l))
    this.player.saveLoadout()
    this.createKanjiSettingsSection()
    this.setOverlayInputEnabled(this.settingsOverlay, true)
  }

  createSlider(x, y, initialValue, onChange) {
    const width = 160
    const height = 12
    const handleRadius = 10
    const container = this.add.container(x, y)

    const track = this.add.rectangle(0, 0, width, height, 0x2c3e50).setOrigin(0.5)
    const fill = this.add.rectangle(-width / 2, 0, width * initialValue, height, 0x3498db).setOrigin(0, 0.5)
    const handle = this.add.circle(-width / 2 + width * initialValue, 0, handleRadius, 0xecf0f1).setInteractive({ useHandCursor: true })

    container.add([track, fill, handle])

    let dragging = false

    const clamp = (v, min, max) => Math.max(min, Math.min(max, v))

    const updateFromPointer = (pointer) => {
      const bounds = container.getBounds()
      const localX = pointer.x - bounds.x
      let value = clamp(localX / width, 0, 1)
      value = Math.round(value * 20) / 20
      fill.width = width * value
      handle.x = -width / 2 + width * value
      onChange(value)
    }

    handle.on('pointerdown', (pointer) => {
      dragging = true
      updateFromPointer(pointer)
    })
    this.input.on('pointermove', (pointer) => {
      if (dragging) updateFromPointer(pointer)
    })
    this.input.on('pointerup', () => {
      dragging = false
    })

    // Allow clicking anywhere on the track to jump.
    track.setInteractive()
    track.on('pointerdown', (pointer) => {
      updateFromPointer(pointer)
    })

    return { container, setValue: (value) => {
      fill.width = width * value
      handle.x = -width / 2 + width * value
    }}
  }

  createSettingsButton(x, y, label, callback) {
    const width = 180
    const height = 40
    const bg = this.add.rectangle(x, y, width, height, 0x2980b9).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(x, y, label, {
      ...FONTS.default,
      fontSize: '16px',
      color: '#ffffff',
    }).setOrigin(0.5)

    bg.on('pointerover', () => bg.setFillStyle(0x3498db))
    bg.on('pointerout', () => bg.setFillStyle(0x2980b9))
    bg.on('pointerdown', callback)

    return this.add.container(0, 0, [bg, text])
  }

  updateSettingsUI() {
    this.masterVolumeSlider.setValue(this.settings.masterVolume)
    this.sfxVolumeSlider.setValue(this.settings.sfxVolume)
    this.createKanjiSettingsSection()
    this.setOverlayInputEnabled(this.settingsOverlay, true)
  }

  setupFullscreenListeners() {
    this.fullscreenChangeHandler = () => {
      const isFullscreen = !!document.fullscreenElement
      if (isFullscreen !== this.settings.fullscreen) {
        this.settings.fullscreen = isFullscreen
        this.saveSettings()
        this.updateFullscreenButtonLabel()
      }
    }
    document.addEventListener('fullscreenchange', this.fullscreenChangeHandler)
  }

  shutdown() {
    if (this.fullscreenChangeHandler) {
      document.removeEventListener('fullscreenchange', this.fullscreenChangeHandler)
      this.fullscreenChangeHandler = null
    }
  }

  updateFullscreenButtonLabel() {
    const label = this.settings.fullscreen ? 'Fullscreen: On' : 'Fullscreen: Off'
    const text = this.fullscreenButton?.list.find(c => c.type === 'Text')
    if (text) text.setText(label)
  }

  toggleFullscreen() {
    if (!document.fullscreenElement) {
      // Fullscreen the wrapper, not the canvas, so CSS can make it fill the
      // viewport while Phaser's FIT scale mode keeps the game centred.
      const wrapper = document.getElementById('game-wrapper')
      if (wrapper?.requestFullscreen) {
        wrapper.requestFullscreen().catch(() => {})
      } else {
        this.game.canvas.requestFullscreen?.().catch(() => {})
      }
    } else {
      document.exitFullscreen?.().catch(() => {})
    }
  }
}
