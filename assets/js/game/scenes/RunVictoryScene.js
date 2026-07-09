import { GAME_CONFIG, FONTS } from '../config.js'
import { setupHighDPIWorld } from '../highDpi.js'

export default class RunVictoryScene extends Phaser.Scene {
  constructor() {
    super({ key: 'RunVictoryScene' })
  }

  init(data) {
    this.player = data.player
    this.rewards = data.rewards || { ouroScales: 0, ouroSource: 0, ouroEssence: 0, unlockedAbility: null }
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()
    this.createTitle()
    this.createRewards()
    this.createContinueButton()
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createTitle() {
    this.add.text(GAME_CONFIG.width / 2, 60, 'Map Complete!', {
      ...FONTS.title,
      fontSize: '36px',
      color: '#f1c40f',
    }).setOrigin(0.5)

    this.add.text(GAME_CONFIG.width / 2, 110, 'The boss has fallen.', {
      ...FONTS.default,
      fontSize: '16px',
      color: '#bdc3c7',
    }).setOrigin(0.5)
  }

  createRewards() {
    const startY = 180
    const lineHeight = 44
    let row = 0

    const addRewardRow = (iconKey, label, amount, color = '#ecf0f1') => {
      const y = startY + row * lineHeight
      const iconSize = 24
      this.add.image(GAME_CONFIG.width / 2 - 120, y, iconKey)
        .setDisplaySize(iconSize, iconSize)
        .setOrigin(0.5)
      this.add.text(GAME_CONFIG.width / 2 - 90, y, `+${amount} ${label}`, {
        ...FONTS.default,
        fontSize: '18px',
        color,
      }).setOrigin(0, 0.5)
      row++
    }

    if (this.rewards.ouroScales > 0) {
      addRewardRow('ouro_scale', 'Ouro Scale', this.rewards.ouroScales, '#f1c40f')
    }

    if (this.rewards.ouroSource > 0) {
      addRewardRow('ouro_source', 'Ouro Source', this.rewards.ouroSource, '#3498db')
    }

    if (this.rewards.ouroEssence > 0) {
      addRewardRow('ouro_essence', 'Ouro Essence', this.rewards.ouroEssence, '#9b59b6')
    }

    if (this.rewards.unlockedAbility) {
      const y = startY + row * lineHeight
      this.add.text(GAME_CONFIG.width / 2, y, `⚔️ New ability unlocked: ${this.rewards.unlockedAbility.name}`, {
        ...FONTS.default,
        fontSize: '18px',
        color: '#2ecc71',
        align: 'center',
        wordWrap: { width: 520 },
      }).setOrigin(0.5)
      row++
    }

    if (row === 0) {
      this.add.text(GAME_CONFIG.width / 2, startY, 'No new rewards this run.', {
        ...FONTS.default,
        fontSize: '18px',
        color: '#7f8c8d',
      }).setOrigin(0.5)
    }

    const totals = this.player.loadout || {}
    const totalY = startY + Math.max(row, 1) * lineHeight + 40

    this.add.text(GAME_CONFIG.width / 2, totalY - 30, 'Totals', {
      ...FONTS.default,
      fontSize: '14px',
      color: '#7f8c8d',
    }).setOrigin(0.5)

    this.createCurrencyBadge(GAME_CONFIG.width / 2 - 110, totalY, 'ouro_scale', totals.ouroScales || 0)
    this.createCurrencyBadge(GAME_CONFIG.width / 2, totalY, 'ouro_source', totals.ouroSource || 0)
    this.createCurrencyBadge(GAME_CONFIG.width / 2 + 110, totalY, 'ouro_essence', totals.ouroEssence || 0)
  }

  createCurrencyBadge(x, y, iconKey, amount) {
    this.add.image(x - 12, y, iconKey)
      .setDisplaySize(20, 20)
      .setOrigin(0.5)
    this.add.text(x + 8, y, String(amount), {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
    }).setOrigin(0, 0.5)
  }

  createContinueButton() {
    const btn = this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height - 80, 220, 50, 0x27ae60).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height - 80, 'Continue', {
      ...FONTS.default,
      fontSize: '18px',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5)

    btn.on('pointerdown', () => {
      this.scene.start('HeroSelectScene', { player: this.player })
    })
    btn.on('pointerover', () => btn.setFillStyle(0x2ecc71))
    btn.on('pointerout', () => btn.setFillStyle(0x27ae60))
  }
}
