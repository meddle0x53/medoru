import { GAME_CONFIG, FONTS } from '../config.js'

export default class RunVictoryScene extends Phaser.Scene {
  constructor() {
    super({ key: 'RunVictoryScene' })
  }

  init(data) {
    this.player = data.player
    this.rewards = data.rewards || { ouroScales: 0, ouroSource: 0, unlockedAbility: null }
  }

  create() {
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
    const lines = []

    if (this.rewards.ouroScales > 0) {
      lines.push(`🪙 +${this.rewards.ouroScales} Ouro Scale`)
    }

    if (this.rewards.ouroSource > 0) {
      lines.push(`💎 +${this.rewards.ouroSource} Ouro Source`)
    }

    if (this.rewards.unlockedAbility) {
      lines.push(`⚔️ New ability unlocked: ${this.rewards.unlockedAbility.name}`)
    }

    if (lines.length === 0) {
      lines.push('No new rewards this run.')
    }

    const startY = 180
    lines.forEach((line, i) => {
      this.add.text(GAME_CONFIG.width / 2, startY + i * 44, line, {
        ...FONTS.default,
        fontSize: '18px',
        color: '#ecf0f1',
        align: 'center',
        wordWrap: { width: 520 },
      }).setOrigin(0.5)
    })

    const totals = this.player.loadout || {}
    this.add.text(GAME_CONFIG.width / 2, 360, `Totals: ${totals.ouroScales || 0} 🪙    ${totals.ouroSource || 0} 💎    ${totals.ouroEssence || 0} 🔮`, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#7f8c8d',
    }).setOrigin(0.5)
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
