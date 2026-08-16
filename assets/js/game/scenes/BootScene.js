
import { MAP_DEFINITIONS } from '../data/maps/index.js'
import { setupHighDPIWorld } from '../highDpi.js'

/**
 * Boot Scene - loads assets and initial data.
 */
export default class BootScene extends Phaser.Scene {
  constructor() {
    super({ key: 'BootScene' })
  }

  preload() {
    this._bootPerfStart = performance.now()
    this._loadedFiles = 0
    this._totalFiles = 0

    this.load.on('start', () => {
      this._bootPerfStart = performance.now()
      console.log('[GamePerf] BootScene preload started')
    })

    this.load.on('progress', (progress) => {
      if (progress === 1) {
        const elapsed = Math.round(performance.now() - this._bootPerfStart)
        console.log('[GamePerf] BootScene preload progress 100%', { elapsedMs: elapsed })
      }
    })

    this.load.on('load', (file) => {
      this._loadedFiles++
      console.log('[GamePerf] BootScene file loaded', { key: file.key, url: file.url, type: file.type })
    })

    this.load.on('loaderror', (file) => {
      console.warn('[GamePerf] BootScene file failed', { key: file.key, url: file.url })
    })

    this.load.on('complete', () => {
      const elapsed = Math.round(performance.now() - this._bootPerfStart)
      console.log('[GamePerf] BootScene preload complete', {
        elapsedMs: elapsed,
        loadedFiles: this._loadedFiles,
        totalFiles: this.load.totalToLoad,
      })
    })

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
    setupHighDPIWorld(this)
    // Always start at the title screen. It will decide whether to show
    // Continue, New Run, or Settings based on the saved loadout.
    this.scene.start('TitleScene')
  }
}
