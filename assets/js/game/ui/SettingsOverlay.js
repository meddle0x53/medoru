import { GAME_CONFIG, FONTS } from '../config.js'

const JLPT_LEVELS = [5, 4, 3, 2, 1]

/**
 * Small in-game settings overlay with manual save upload, fullscreen toggle,
 * and the kanji challenge mode settings (default pools vs free kanji mode).
 * Used on the map and in battle so the player can sync progress on demand.
 */
export default class SettingsOverlay {
  constructor(scene, player) {
    this.scene = scene
    this.player = player
    this.container = null
    this.toast = null
    this.openButton = null
    this.kanjiSection = null
  }

  createButton(x, y, label = '⚙ Menu') {
    this.openButton = this.scene.add.text(x, y, label, {
      fontFamily: 'Arial',
      fontSize: '14px',
      color: '#ffffff',
      backgroundColor: '#2c3e50',
      padding: { left: 8, right: 8, top: 4, bottom: 4 },
    })
      .setOrigin(1, 0)
      .setInteractive({ useHandCursor: true })
      .setDepth(100)

    this.openButton.on('pointerdown', () => this.open())
    return this.openButton
  }

  open() {
    if (this.container) return

    this.fullscreenHandler = () => this.updateFullscreenLabel()
    document.addEventListener('fullscreenchange', this.fullscreenHandler)

    const cx = GAME_CONFIG.width / 2
    const cy = GAME_CONFIG.height / 2

    this.container = this.scene.add.container(0, 0).setDepth(200)

    const backdrop = this.scene.add.rectangle(
      cx,
      cy,
      GAME_CONFIG.width,
      GAME_CONFIG.height,
      0x000000,
      0.7,
    ).setOrigin(0.5).setInteractive()
    this.container.add(backdrop)

    const panel = this.scene.add.rectangle(
      cx,
      cy,
      380,
      420,
      0x1a1a2e,
    ).setStrokeStyle(2, 0x3498db).setOrigin(0.5)
    this.container.add(panel)

    const title = this.scene.add.text(cx, cy - 180, 'Settings', {
      ...FONTS.title,
      fontSize: '24px',
      color: '#f1c40f',
    }).setOrigin(0.5)
    this.container.add(title)

    const uploadBtn = this.createPanelButton(
      cx,
      cy - 130,
      'Upload Save',
      0x2980b9,
      0x3498db,
      () => this.handleUpload(),
    )
    this.container.add(uploadBtn)

    const fsLabel = document.fullscreenElement ? 'Exit Fullscreen' : 'Enter Fullscreen'
    this.fsButton = this.createPanelButton(
      cx,
      cy - 80,
      fsLabel,
      0x7f8c8d,
      0x95a5a6,
      () => this.toggleFullscreen(),
    )
    this.container.add(this.fsButton)

    this.createKanjiSection(cx, cy)

    const closeBtn = this.createPanelButton(
      cx,
      cy + 160,
      'Close',
      0x27ae60,
      0x2ecc71,
      () => this.close(),
    )
    this.container.add(closeBtn)
  }

  // ---------- Kanji challenge mode ----------

  createKanjiSection(cx, cy) {
    if (this.kanjiSection) {
      this.kanjiSection.destroy()
    }
    this.kanjiSection = this.scene.add.container(0, 0)
    this.container.add(this.kanjiSection)

    const loadout = this.player.loadout
    const mode = loadout.kanjiChallengeMode === 'free' ? 'free' : 'default'
    const selectedLevels = new Set(
      Array.isArray(loadout.freeKanjiLevels) && loadout.freeKanjiLevels.length > 0
        ? loadout.freeKanjiLevels
        : [5],
    )

    this.kanjiSection.add(
      this.scene.add.text(cx, cy - 33, 'Kanji Challenges', {
        ...FONTS.default,
        fontSize: '13px',
        color: '#bdc3c7',
      }).setOrigin(0.5),
    )

    const defaultBtn = this.createToggleButton(cx - 70, cy - 5, 130, 32, 'Default', mode === 'default')
    const freeBtn = this.createToggleButton(cx + 70, cy - 5, 130, 32, 'Free Kanji', mode === 'free')
    this.kanjiSection.add([defaultBtn.container, freeBtn.container])

    defaultBtn.bg.on('pointerdown', () => this.setKanjiMode('default'))
    freeBtn.bg.on('pointerdown', () => this.setKanjiMode('free'))

    if (mode !== 'free') return

    this.kanjiSection.add(
      this.scene.add.text(cx, cy + 38, 'Free mode JLPT levels', {
        ...FONTS.default,
        fontSize: '12px',
        color: '#bdc3c7',
      }).setOrigin(0.5),
    )

    const chipW = 56
    const chipGap = 8
    const totalW = JLPT_LEVELS.length * chipW + (JLPT_LEVELS.length - 1) * chipGap
    let chipX = cx - totalW / 2 + chipW / 2
    for (const level of JLPT_LEVELS) {
      const chip = this.createToggleButton(chipX, cy + 68, chipW, 30, `N${level}`, selectedLevels.has(level))
      this.kanjiSection.add(chip.container)
      chip.bg.on('pointerdown', () => this.toggleLevel(level, selectedLevels))
      chipX += chipW + chipGap
    }

    this.kanjiSection.add(
      this.scene.add.text(cx, cy + 100, 'Free pools are rolled when a new run starts.', {
        ...FONTS.default,
        fontSize: '10px',
        color: '#7f8c8d',
      }).setOrigin(0.5),
    )
  }

  setKanjiMode(mode) {
    this.player.loadout.kanjiChallengeMode = mode
    this.player.saveLoadout()
    // Rebuild the section so the level picker appears/disappears and the
    // active-mode highlight updates. Pools themselves are only rolled at run
    // start, so a mid-run change applies to the next run.
    this.createKanjiSection(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
  }

  toggleLevel(level, selectedLevels) {
    if (selectedLevels.has(level)) {
      // Keep at least one level selected so pools always have a source.
      if (selectedLevels.size <= 1) return
      selectedLevels.delete(level)
    } else {
      selectedLevels.add(level)
    }
    this.player.loadout.freeKanjiLevels = JLPT_LEVELS.filter(l => selectedLevels.has(l))
    this.player.saveLoadout()
    this.createKanjiSection(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
  }

  createToggleButton(x, y, w, h, label, active) {
    const color = active ? 0x3498db : 0x2c3e50
    const hoverColor = active ? 0x5dade2 : 0x34495e
    const bg = this.scene.add.rectangle(x, y, w, h, color)
      .setInteractive({ useHandCursor: true })
      .setOrigin(0.5)
    const text = this.scene.add.text(x, y, label, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ffffff',
    }).setOrigin(0.5)

    bg.on('pointerover', () => bg.setFillStyle(hoverColor))
    bg.on('pointerout', () => bg.setFillStyle(color))

    return { container: this.scene.add.container(0, 0, [bg, text]), bg, text }
  }

  // ---------- Panel buttons ----------

  createPanelButton(x, y, label, color, hoverColor, onClick) {
    const bg = this.scene.add.rectangle(x, y, 220, 40, color)
      .setInteractive({ useHandCursor: true })
      .setOrigin(0.5)
    const text = this.scene.add.text(x, y, label, {
      ...FONTS.default,
      fontSize: '16px',
      color: '#ffffff',
    }).setOrigin(0.5)

    bg.on('pointerover', () => bg.setFillStyle(hoverColor))
    bg.on('pointerout', () => bg.setFillStyle(color))
    bg.on('pointerdown', onClick)

    return this.scene.add.container(0, 0, [bg, text])
  }

  async handleUpload() {
    const result = await this.player.uploadSave()
    this.showToast(result.ok ? 'Save uploaded' : `Upload failed${result.error ? ': ' + result.error : ''}`)
  }

  showToast(message) {
    if (this.toast) {
      this.toast.destroy()
      this.toast = null
    }

    this.toast = this.scene.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 190, message, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
      backgroundColor: '#000000',
      padding: { left: 8, right: 8, top: 4, bottom: 4 },
    }).setOrigin(0.5).setDepth(210)

    this.scene.time.delayedCall(2000, () => {
      if (this.toast) {
        this.toast.destroy()
        this.toast = null
      }
    })
  }

  toggleFullscreen() {
    const wrapper = document.getElementById('game-wrapper')
    if (!document.fullscreenElement) {
      if (wrapper?.requestFullscreen) {
        wrapper.requestFullscreen().catch(() => {})
      } else {
        this.scene.game.canvas.requestFullscreen?.().catch(() => {})
      }
    } else {
      document.exitFullscreen?.().catch(() => {})
    }
  }

  updateFullscreenLabel() {
    if (!this.fsButton) return
    const text = this.fsButton.list.find((c) => c.type === 'Text')
    if (text) {
      text.setText(document.fullscreenElement ? 'Exit Fullscreen' : 'Enter Fullscreen')
    }
  }

  close() {
    if (this.container) {
      this.container.destroy()
      this.container = null
    }
    this.kanjiSection = null
    if (this.toast) {
      this.toast.destroy()
      this.toast = null
    }
    if (this.fullscreenHandler) {
      document.removeEventListener('fullscreenchange', this.fullscreenHandler)
      this.fullscreenHandler = null
    }
    this.fsButton = null
  }
}
