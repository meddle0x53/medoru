import { GAME_CONFIG, FONTS } from '../config.js'
import { openChest, getUpgradeOptions, applyUpgrade } from '../systems/ChestRewards.js'
import { setupHighDPIWorld } from '../highDpi.js'

export default class ChestScene extends Phaser.Scene {
  constructor() {
    super({ key: 'ChestScene' })
  }

  init(data) {
    this.player = data.player
    this.tile = data.tile
    this.mapIndex = data.mapIndex
    this.returnScene = data.returnScene || 'MapScene'
    this.skipCompleteTile = data.skipCompleteTile || false
    this.pendingRewards = []
    this.pendingUpgradeOptions = []
    this.selectedUpgrade = null
  }

  preload() {
    this.load.image('chest_scene_background', '/images/game/chest_scene_background.png')
    this.load.image('chest_scene_open', '/images/game/chest_scene_open.png')
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()
    this.createTitle()
    this.startOpeningSequence()
  }

  createBackground() {
    const addScaledBg = (key, depth = 0, alpha = 1) => {
      const bg = this.add.image(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, key)
      const src = this.textures.get(key).getSourceImage()
      const baseScaleX = GAME_CONFIG.width / (src.width || GAME_CONFIG.width)
      const baseScaleY = GAME_CONFIG.height / (src.height || GAME_CONFIG.height)
      bg.setScale(baseScaleX, baseScaleY)
      bg.setDepth(depth)
      bg.setAlpha(alpha)
      return bg
    }

    this.closedBg = addScaledBg('chest_scene_background', 0)
    this.openBg = addScaledBg('chest_scene_open', 1, 0)
  }

  createTitle() {
    this.add.text(GAME_CONFIG.width / 2, 36, 'Treasure Chest', {
      ...FONTS.title,
      fontSize: '28px',
      color: '#f1c40f',
      stroke: '#000000',
      strokeThickness: 4,
    }).setOrigin(0.5).setDepth(10)
  }

  startOpeningSequence() {
    // Brief anticipation, then crossfade to the opened chest with a flash.
    this.time.delayedCall(600, () => {
      this.tweens.add({
        targets: this.openBg,
        alpha: 1,
        duration: 400,
        onComplete: () => {
          if (this.closedBg) this.closedBg.destroy()
          this.flashOpen()
          this.spawnSparkles(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 60)
          this.pendingRewards = openChest(this.player)
          {
            const roll = Math.random()
            let essenceAmount = 0
            if (roll < 0.10) {
              essenceAmount = this.player.addOuroEssence(2)
            } else if (roll < 0.30) {
              essenceAmount = this.player.addOuroEssence(4)
            }
            if (essenceAmount > 0) {
              this.pendingRewards.push({ type: 'ouro_essence', amount: essenceAmount })
            }
          }
          this.pendingUpgradeOptions = getUpgradeOptions(this.player)
          this.handleUpgradeFlow()
        },
      })
    })
  }

  flashOpen() {
    const flash = this.add.rectangle(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      GAME_CONFIG.width,
      GAME_CONFIG.height,
      0xffffff,
      0.45,
    )
    flash.setDepth(5)
    this.tweens.add({
      targets: flash,
      alpha: 0,
      duration: 700,
      onComplete: () => flash.destroy(),
    })
  }

  spawnSparkles(x, y) {
    for (let i = 0; i < 16; i++) {
      const sparkle = this.add.circle(x, y, 3 + Math.random() * 3, 0xf1c40f)
      sparkle.setDepth(6)
      const angle = (Math.PI * 2 * i) / 16 + (Math.random() * 0.4 - 0.2)
      const distance = 60 + Math.random() * 80
      this.tweens.add({
        targets: sparkle,
        x: x + Math.cos(angle) * distance,
        y: y + Math.sin(angle) * distance,
        alpha: 0,
        scale: 0,
        duration: 800,
        onComplete: () => sparkle.destroy(),
      })
    }
  }

  handleUpgradeFlow() {
    if (this.pendingUpgradeOptions.length === 0) {
      this.showRewardSummary()
      return
    }

    if (this.pendingUpgradeOptions.length === 1) {
      applyUpgrade(this.player, this.pendingUpgradeOptions[0])
      this.pendingRewards.push({ type: 'upgrade', option: this.pendingUpgradeOptions[0] })
      this.showRewardSummary()
      return
    }

    this.showUpgradeChoice(this.pendingUpgradeOptions)
  }

  showUpgradeChoice(options) {
    const panel = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 20)
    panel.setDepth(100)

    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.7).setOrigin(0.5)
    backdrop.setInteractive()
    panel.add(backdrop)

    const dialog = this.add.rectangle(0, 0, 420, 220, 0x16213e).setStrokeStyle(2, 0x3498db).setOrigin(0.5)
    panel.add(dialog)

    const title = this.add.text(0, -70, 'Choose an upgrade', {
      ...FONTS.title,
      fontSize: '20px',
      color: '#f1c40f',
    }).setOrigin(0.5)
    panel.add(title)

    options.forEach((option, index) => {
      const xOffset = index === 0 ? -90 : 90
      const btn = this.add.rectangle(xOffset, 0, 150, 80, 0x2980b9).setInteractive({ useHandCursor: true }).setOrigin(0.5)
      const icon = this.add.text(xOffset, -16, option.icon, {
        ...FONTS.default,
        fontSize: '28px',
      }).setOrigin(0.5)
      const label = this.add.text(xOffset, 14, `${option.name}\n+${option.nextLevel}`, {
        ...FONTS.default,
        fontSize: '13px',
        color: '#ffffff',
        align: 'center',
      }).setOrigin(0.5)

      btn.on('pointerdown', () => {
        applyUpgrade(this.player, option)
        this.pendingRewards.push({ type: 'upgrade', option })
        panel.destroy()
        this.showRewardSummary()
      })
      btn.on('pointerover', () => btn.setFillStyle(0x3498db))
      btn.on('pointerout', () => btn.setFillStyle(0x2980b9))

      panel.add([btn, icon, label])
    })
  }

  showRewardSummary() {
    const panel = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 30)
    panel.setDepth(100)

    const bg = this.add.rectangle(0, 0, 460, 280, 0x16213e).setStrokeStyle(2, 0x2ecc71).setOrigin(0.5)
    panel.add(bg)

    const title = this.add.text(0, -110, 'Chest Loot', {
      ...FONTS.title,
      fontSize: '22px',
      color: '#f1c40f',
    }).setOrigin(0.5)
    panel.add(title)

    const lines = this.formatRewardLines()
    let y = -70
    lines.forEach(line => {
      if (typeof line === 'string') {
        panel.add(this.add.text(0, y, line, {
          ...FONTS.default,
          fontSize: '14px',
          color: '#ecf0f1',
          align: 'center',
        }).setOrigin(0.5))
      } else {
        const text = this.add.text(8, y, line.text, {
          ...FONTS.default,
          fontSize: '14px',
          color: '#ecf0f1',
        }).setOrigin(0, 0.5)
        const icon = this.add.image(-text.width / 2 - 4, y, line.iconKey).setDisplaySize(20, 20).setOrigin(0.5)
        panel.add([icon, text])
      }
      y += 26
    })

    const btn = this.add.rectangle(0, 110, 160, 40, 0x27ae60).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const btnText = this.add.text(0, 110, 'Continue', {
      ...FONTS.default,
      fontSize: '16px',
      color: '#ffffff',
    }).setOrigin(0.5)

    btn.on('pointerdown', () => this.completeTile())
    btn.on('pointerover', () => btn.setFillStyle(0x2ecc71))
    btn.on('pointerout', () => btn.setFillStyle(0x27ae60))

    panel.add([btn, btnText])
  }

  formatRewardLines() {
    const lines = []

    for (const reward of this.pendingRewards) {
      switch (reward.type) {
        case 'gold':
          lines.push(`🪙 ${reward.value} gold`)
          break
        case 'item':
          lines.push(`${reward.item.icon || '•'} ${reward.item.name}`)
          break
        case 'ability':
          lines.push(`⚔️ Ability: ${reward.ability.name}`)
          break
        case 'charm':
          lines.push(`✨ Charm: ${reward.charm.name}`)
          break
        case 'statPoint':
          lines.push('🌟 +1 Stat Point')
          break
        case 'upgrade':
          lines.push(`${reward.option.icon} ${reward.option.name} +${reward.option.nextLevel}`)
          break
        case 'ouro_essence':
          lines.push({ text: `+${reward.amount} Ouro Essence`, iconKey: 'ouro_essence' })
          break
        default:
          break
      }
    }

    if (lines.length === 0) lines.push('The chest was empty...')
    return lines
  }

  completeTile() {
    if (this.tile?.id && !this.skipCompleteTile) {
      this.player.completeTile(this.tile.id)
    }
    this.player.saveLoadout()
    this.scene.start(this.returnScene, { player: this.player })
  }
}
