import { GAME_CONFIG, COLORS, FONTS } from '../config.js'
import { setupHighDPIWorld } from '../highDpi.js'

export default class RunVictoryScene extends Phaser.Scene {
  constructor() {
    super({ key: 'RunVictoryScene' })
  }

  init(data) {
    this.player = data.player
    this.mapIndex = data.mapIndex ?? 0
    this.rewards = data.rewards || { ouroScales: 0, ouroSource: 0, ouroEssence: 0, unlockedAbility: null }
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()
    this.createTitle()
    this.createRewards()
    this.createNgPlusSection()
    this.createContinueButtons()
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createTitle() {
    const ngLevel = this.player.loadout?.ngPlusLevel || 0
    const titleText = ngLevel > 0 ? `Map Complete! (NG+${ngLevel})` : 'Map Complete!'
    this.add.text(GAME_CONFIG.width / 2, 50, titleText, {
      ...FONTS.title,
      fontSize: '32px',
      color: '#f1c40f',
    }).setOrigin(0.5)

    this.add.text(GAME_CONFIG.width / 2, 95, 'The boss has fallen.', {
      ...FONTS.default,
      fontSize: '16px',
      color: '#bdc3c7',
    }).setOrigin(0.5)
  }

  createRewards() {
    const startY = 130
    const lineHeight = 40
    let row = 0

    const addRewardRow = (iconKey, label, amount, color = '#ecf0f1') => {
      const y = startY + row * lineHeight
      const iconSize = 22
      this.add.image(GAME_CONFIG.width / 2 - 120, y, iconKey)
        .setDisplaySize(iconSize, iconSize)
        .setOrigin(0.5)
      this.add.text(GAME_CONFIG.width / 2 - 95, y, `+${amount} ${label}`, {
        ...FONTS.default,
        fontSize: '16px',
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
        fontSize: '16px',
        color: '#2ecc71',
        align: 'center',
        wordWrap: { width: 520 },
      }).setOrigin(0.5)
      row++
    }

    if (row === 0) {
      this.add.text(GAME_CONFIG.width / 2, startY, 'No new rewards this run.', {
        ...FONTS.default,
        fontSize: '16px',
        color: '#7f8c8d',
      }).setOrigin(0.5)
    }

    const totals = this.player.loadout || {}
    const totalY = startY + Math.max(row, 1) * lineHeight + 30

    this.add.text(GAME_CONFIG.width / 2, totalY - 22, 'Totals', {
      ...FONTS.default,
      fontSize: '13px',
      color: '#7f8c8d',
    }).setOrigin(0.5)

    this.createCurrencyBadge(GAME_CONFIG.width / 2 - 110, totalY, 'ouro_scale', totals.ouroScales || 0)
    this.createCurrencyBadge(GAME_CONFIG.width / 2, totalY, 'ouro_source', totals.ouroSource || 0)
    this.createCurrencyBadge(GAME_CONFIG.width / 2 + 110, totalY, 'ouro_essence', totals.ouroEssence || 0)
  }

  createCurrencyBadge(x, y, iconKey, amount) {
    this.add.image(x - 12, y, iconKey)
      .setDisplaySize(18, 18)
      .setOrigin(0.5)
    this.add.text(x + 8, y, String(amount), {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ecf0f1',
    }).setOrigin(0, 0.5)
  }

  createNgPlusSection() {
    const cost = this.player.getNgPlusCost()
    const nextLevel = (this.player.loadout?.ngPlusLevel || 0) + 1
    const nextMult = Math.pow(1.5, nextLevel).toFixed(2)

    const y = GAME_CONFIG.height / 2 + 20
    this.add.text(GAME_CONFIG.width / 2, y, `New Game+ ${nextLevel}`, {
      ...FONTS.default,
      fontSize: '20px',
      color: '#f39c12',
      fontStyle: 'bold',
    }).setOrigin(0.5)

    this.add.text(GAME_CONFIG.width / 2, y + 26, `Enemies & rewards ×${nextMult}`, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#bdc3c7',
    }).setOrigin(0.5)

    this.add.text(GAME_CONFIG.width / 2, y + 48, `Cost: ${cost.essence} Ouro Essence OR ${cost.scales} Ouro Scale`, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ecf0f1',
    }).setOrigin(0.5)

    this.ngPlusCost = cost
  }

  createContinueButtons() {
    const btnY = GAME_CONFIG.height - 70
    const btnW = 180
    const btnH = 44
    const gap = 20

    const createBtn = (x, label, color, hoverColor, onClick, disabled = false) => {
      const bg = this.add.rectangle(x, btnY, btnW, btnH, disabled ? 0x555555 : color)
        .setInteractive({ useHandCursor: !disabled })
        .setOrigin(0.5)
      const text = this.add.text(x, btnY, label, {
        ...FONTS.default,
        fontSize: '15px',
        color: '#ffffff',
        fontStyle: 'bold',
      }).setOrigin(0.5)

      if (!disabled) {
        bg.on('pointerover', () => bg.setFillStyle(hoverColor))
        bg.on('pointerout', () => bg.setFillStyle(color))
        bg.on('pointerdown', onClick)
      }

      return { bg, text }
    }

    const cost = this.ngPlusCost
    const canAfford =
      (this.player.loadout?.ouroEssence || 0) >= cost.essence ||
      (this.player.loadout?.ouroScales || 0) >= cost.scales

    createBtn(GAME_CONFIG.width / 2 - btnW / 2 - gap / 2, 'New Game+', 0x9b59b6, 0xaf7ac5, () => {
      if (!this.tryStartNgPlus()) return
      this.player.enterNgPlus()
      this.scene.start('MapScene', { player: this.player, mapIndex: this.mapIndex })
    }, !canAfford)

    createBtn(GAME_CONFIG.width / 2 + btnW / 2 + gap / 2, 'Return to Menu', 0x27ae60, 0x2ecc71, () => {
      this.player.loadout.ngPlusLevel = 0
      this.player.resetToFreshHero()
      this.scene.start('HeroSelectScene', { player: this.player })
    })
  }

  tryStartNgPlus() {
    const cost = this.ngPlusCost
    const canPayEssence = (this.player.loadout?.ouroEssence || 0) >= cost.essence
    const canPayScales = (this.player.loadout?.ouroScales || 0) >= cost.scales

    if (!canPayEssence && !canPayScales) return false

    // Prefer Ouro Essence if both are available; otherwise use whichever is available.
    if (canPayEssence) {
      this.player.spendOuroEssence(cost.essence)
    } else {
      this.player.spendOuroScales(cost.scales)
    }
    return true
  }
}
