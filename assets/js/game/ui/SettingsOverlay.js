import { GAME_CONFIG, FONTS } from '../config.js'

/**
 * Small in-game settings overlay with manual save upload and fullscreen toggle.
 * Used on the map and in battle so the player can sync progress on demand.
 */
export default class SettingsOverlay {
  constructor(scene, player) {
    this.scene = scene
    this.player = player
    this.container = null
    this.toast = null
    this.openButton = null
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

    this.container = this.scene.add.container(0, 0).setDepth(200)

    const backdrop = this.scene.add.rectangle(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      GAME_CONFIG.width,
      GAME_CONFIG.height,
      0x000000,
      0.7,
    ).setOrigin(0.5).setInteractive()
    this.container.add(backdrop)

    const panel = this.scene.add.rectangle(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      360,
      260,
      0x1a1a2e,
    ).setStrokeStyle(2, 0x3498db).setOrigin(0.5)
    this.container.add(panel)

    const title = this.scene.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 90, 'Settings', {
      ...FONTS.title,
      fontSize: '24px',
      color: '#f1c40f',
    }).setOrigin(0.5)
    this.container.add(title)

    const uploadBtn = this.createPanelButton(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2 - 20,
      'Upload Save',
      0x2980b9,
      0x3498db,
      () => this.handleUpload(),
    )
    this.container.add(uploadBtn)

    const fsLabel = document.fullscreenElement ? 'Exit Fullscreen' : 'Enter Fullscreen'
    this.fsButton = this.createPanelButton(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2 + 40,
      fsLabel,
      0x7f8c8d,
      0x95a5a6,
      () => this.toggleFullscreen(),
    )
    this.container.add(this.fsButton)

    const closeBtn = this.createPanelButton(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2 + 100,
      'Close',
      0x27ae60,
      0x2ecc71,
      () => this.close(),
    )
    this.container.add(closeBtn)
  }

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

    this.toast = this.scene.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 150, message, {
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
