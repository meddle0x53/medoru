import { ENEMY_DEFINITIONS } from '../data/enemies/index.js'

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

    // Map-specific tile art (Japanese Fields). Falls back to colored circles
    // until the PNG files are present. The ?v=2 busts the cache after the
    // recent re-crop.
    this.load.image('map0_battle_tile', '/images/game/map0_battle_tile.png?v=2')
    this.load.image('map0_mini_boss_tile', '/images/game/map0_mini_boss_tile.png?v=2')
    this.load.image('map0_boss_tile', '/images/game/map0_boss_tile.png?v=1')
    this.load.image('map0_chest_tile', '/images/game/map0_chest_tile.png?v=3')
    this.load.image('map0_shop_tile', '/images/game/map0_shop_tile.png?v=4')
    this.load.image('map0_memory_tile', '/images/game/map0_memory_tile.png?v=5')
    this.load.image('map0_rest_tile', '/images/game/map0_rest_tile.png?v=2')

    // Loadout portrait
    this.load.image('hero_portrait', '/images/game/hero_portrait.png')

    // Enemy sprites — loaded dynamically from enemy definitions.
    const loadedKeys = new Set()
    for (const def of ENEMY_DEFINITIONS) {
      for (const key of Object.values(def.sprites)) {
        if (!key || loadedKeys.has(key)) continue
        loadedKeys.add(key)
        this.load.image(key, `/images/game/${key}.png`)
      }
      if (def.portrait && !loadedKeys.has(def.portrait)) {
        loadedKeys.add(def.portrait)
        this.load.image(def.portrait, `/images/game/${def.portrait}.png`)
      }
      if (def.icon && !loadedKeys.has(def.icon)) {
        loadedKeys.add(def.icon)
        this.load.image(def.icon, `/images/game/${def.icon}.png`)
      }
    }

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
