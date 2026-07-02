import { ENEMY_DEFINITIONS } from '../data/enemies/index.js'
import { MAP_DEFINITIONS } from '../data/maps/index.js'

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

    // Map backgrounds and tile art, loaded dynamically from the map registry.
    // This keeps new maps data-driven: add a map JSON and its images are loaded
    // automatically. Falls back to colored circles until the PNG files exist.
    const loadedImageKeys = new Set()
    for (const mapDef of MAP_DEFINITIONS) {
      const bgKey = mapDef.background?.image
      if (bgKey && !loadedImageKeys.has(bgKey)) {
        loadedImageKeys.add(bgKey)
        this.load.image(bgKey, `/images/game/${bgKey}.png`)
      }

      for (const cfg of Object.values(mapDef.tileImages || {})) {
        const key = cfg?.image
        if (key && !loadedImageKeys.has(key)) {
          loadedImageKeys.add(key)
          this.load.image(key, `/images/game/${key}.png`)
        }
      }
    }

    // Title screen, hero select, and loadout portrait
    this.load.image('title_screen', '/images/game/title_screen.png')
    this.load.image('hero_select_background', '/images/game/hero_select_background.png')
    this.load.image('hero_portrait', '/images/game/hero_portrait.png')

    // Meta-currency icons for the home camp shop and victory screens.
    this.load.image('ouro_scale', '/images/game/ouro_scale.png')
    this.load.image('ouro_source', '/images/game/ouro_source.png')
    this.load.image('ouro_essence', '/images/game/ouro_essence.png')

    // Enemy sprites — loaded dynamically from enemy definitions (including phase sprites).
    const loadedKeys = new Set()
    for (const def of ENEMY_DEFINITIONS) {
      const spriteKeys = new Set(Object.values(def.sprites || {}))
      for (const phase of def.phases || []) {
        for (const key of Object.values(phase.sprites || {})) {
          if (key) spriteKeys.add(key)
        }
      }
      for (const key of spriteKeys) {
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
    // Always start at the title screen. It will decide whether to show
    // Continue, New Run, or Settings based on the saved loadout.
    this.scene.start('TitleScene')
  }
}
