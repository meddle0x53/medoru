import { COLORS, FONTS } from '../config.js'

/**
 * Boot Scene - loads assets and initial data.
 */
export default class BootScene extends Phaser.Scene {
  constructor() {
    super({ key: 'BootScene' })
  }

  create() {
    // Generate textures programmatically (squares for now)
    this.createRectTexture('player', COLORS.player, 64, 128)
    this.createRectTexture('enemy', COLORS.enemy, 80, 112)
    this.createSquareTexture('button', COLORS.button, 1)
    this.createSquareTexture('buttonHover', COLORS.buttonHover, 1)
    this.createSquareTexture('hpBar', COLORS.hp, 1)
    this.createSquareTexture('staminaBar', COLORS.stamina, 1)
    this.createSquareTexture('barBg', COLORS.hpBg, 1)

    this.scene.start('BattleScene')
  }

  createRectTexture(key, color, width, height) {
    const graphics = this.make.graphics({ x: 0, y: 0, add: false })
    graphics.fillStyle(color, 1)
    graphics.fillRect(0, 0, width, height)
    graphics.generateTexture(key, width, height)
    graphics.destroy()
  }

  createSquareTexture(key, color, size) {
    const graphics = this.make.graphics({ x: 0, y: 0, add: false })
    graphics.fillStyle(color, 1)
    if (size > 1) {
      graphics.fillRect(0, 0, size, size)
    } else {
      // For bar textures, create a 1x1 pixel
      graphics.fillRect(0, 0, 1, 1)
    }
    graphics.generateTexture(key, size > 1 ? size : 1, size > 1 ? size : 1)
    graphics.destroy()
  }
}
