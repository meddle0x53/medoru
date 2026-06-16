/**
 * Boot Scene - loads assets and initial data.
 */
export default class BootScene extends Phaser.Scene {
  constructor() {
    super({ key: 'BootScene' })
  }

  preload() {
    // Warrior sprites
    this.load.image('player_idle', '/images/game/player_idle.png')
    this.load.image('player_ready', '/images/game/player_ready.png')
    this.load.image('player_sword', '/images/game/player_sword.png')
    this.load.image('player_shield', '/images/game/player_shield.png')
    this.load.image('player_sword_shield', '/images/game/player_sword_shield.png')
    this.load.image('player_sword_slash', '/images/game/player_sword_slash.png')
    this.load.image('player_heavy_slash', '/images/game/player_heavy_slash.png')
    this.load.image('player_shield_block', '/images/game/player_shield_block.png')
    this.load.image('player_defeated', '/images/game/player_defeated.png')

    // Battle background
    this.load.image('battle_background', '/images/game/battle_background.png')

    // Map backgrounds
    this.load.image('map_level_1', '/images/game/map_level_1.png')

    // Loadout portrait
    this.load.image('hero_portrait', '/images/game/hero_portrait.png')

    // Enemy sprites
    this.load.image('enemy_kasa_obake', '/images/game/enemy_kasa_obake.png')
    this.load.image('enemy_kasa_obake_attack', '/images/game/enemy_kasa_obake_attack.png')
    this.load.image('enemy_kasa_obake_defend', '/images/game/enemy_kasa_obake_defend.png')
    this.load.image('enemy_kasa_obake_buff', '/images/game/enemy_kasa_obake_buff.png')
    this.load.image('enemy_kasa_obake_defeated', '/images/game/enemy_kasa_obake_defeated.png')

    // Placeholder textures for UI bars
    const graphics = this.make.graphics({ x: 0, y: 0, add: false })
    graphics.fillStyle(0x2ecc71, 1)
    graphics.fillRect(0, 0, 1, 1)
    graphics.generateTexture('hpBar', 1, 1)
    graphics.fillStyle(0xf1c40f, 1)
    graphics.fillRect(0, 0, 1, 1)
    graphics.generateTexture('staminaBar', 1, 1)
    graphics.fillStyle(0x2c3e50, 1)
    graphics.fillRect(0, 0, 1, 1)
    graphics.generateTexture('barBg', 1, 1)
    graphics.destroy()
  }

  create() {
    this.scene.start('MapScene')
  }
}
