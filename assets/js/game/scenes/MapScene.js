import { GAME_CONFIG } from '../config.js'
import { TILE_TYPES, getTileConfig, isBattleTile } from '../data/tileTypes.js'
import Player from '../entities/Player.js'
import { getWindowGameData } from '../api.js'
import { updateReachability, findTileById, computeLayout, getMapName } from '../systems/MapGenerator.js'

/**
 * MapScene — the rogue-like hub.
 *
 * Renders an 11-column directed graph:
 *   Home → 9 random-width columns → Boss
 *
 * Clicking a reachable tile routes to the appropriate scene:
 *   - battle tiles  → LoadoutScene
 *   - TODO tiles    → placeholder random event
 */

const TILE_RADIUS = 22
const CURRENT_PULSE_RADIUS = 28
const FONT_LABEL = { fontFamily: 'Arial', fontSize: '11px', color: '#ffffff', fontStyle: 'bold' }

export default class MapScene extends Phaser.Scene {
  constructor() {
    super({ key: 'MapScene' })
  }

  init(data) {
    this.player = data.player || new Player(getWindowGameData())
  }

  create() {
    this.setupMap()
    this.createBackground()
    this.createHud()
    this.drawMap()
    this.updateHud()
  }

  createBackground() {
    if (this.map.backgroundImage && this.textures.exists(this.map.backgroundImage)) {
      // Scale the image to exactly fill the canvas. The art is 16:9, same as
      // the canvas, so this shows the whole picture without cutting it off.
      const bg = this.add.image(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, this.map.backgroundImage)
      bg.setDisplaySize(GAME_CONFIG.width, GAME_CONFIG.height)
    } else {
      this.add.rectangle(
        GAME_CONFIG.width / 2,
        GAME_CONFIG.height / 2,
        GAME_CONFIG.width,
        GAME_CONFIG.height,
        0x1a1a2e,
      )
    }
  }

  setupMap() {
    this.player.ensureMapState()
    this.map = this.player.getCurrentMap()

    computeLayout(this.map)
    updateReachability(this.map, this.player.loadout.mapState.currentTileId)

    // Safety reset: if the saved state points to a missing or completed
    // dead-end tile (e.g. a finished boss), advance to the next map so the
    // player is never soft-locked.
    const currentTile = this.map.columns.flat().find(t => t.id === this.player.loadout.mapState.currentTileId)
    if (!currentTile || (currentTile.completed && currentTile.connections.length === 0)) {
      this.player.advanceMap()
      this.map = this.player.getCurrentMap()
      computeLayout(this.map)
      updateReachability(this.map, this.player.loadout.mapState.currentTileId)
    }
  }

  createHud() {
    this.hud = {}

    const userData = getWindowGameData()
    this.hud.title = this.add.text(20, 16, getMapName(this.map, userData?.level) || `Map ${this.map.index + 1}`, {
      fontFamily: 'Arial',
      fontSize: '24px',
      color: '#f1c40f',
      fontStyle: 'bold',
    })

    this.hud.hp = this.add.text(20, 50, '', {
      fontFamily: 'Arial',
      fontSize: '16px',
      color: '#e74c3c',
    })

    this.hud.gold = this.add.text(20, 74, '', {
      fontFamily: 'Arial',
      fontSize: '16px',
      color: '#f1c40f',
    })

    this.hud.help = this.add.text(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height - 24,
      'Click a reachable tile to move.',
      {
        fontFamily: 'Arial',
        fontSize: '14px',
        color: '#bdc3c7',
      },
    ).setOrigin(0.5)
  }

  updateHud() {
    const userData = getWindowGameData()
    this.hud.title.setText(getMapName(this.map, userData?.level) || `Map ${this.map.index + 1}`)
    this.hud.hp.setText(`HP: ${this.player.hp}/${this.player.maxHp}`)
    this.hud.gold.setText(`Gold: ${this.player.loadout.gold || 0}`)
  }

  drawMap() {
    this.drawConnections()
    this.drawTiles()
  }

  drawConnections() {
    const baseGraphics = this.add.graphics()
    const reachGraphics = this.add.graphics()

    for (const column of this.map.columns) {
      for (const tile of column) {
        const start = this.getTilePosition(tile)
        for (const nextId of tile.connections) {
          const next = findTileById(this.map, nextId)
          if (!next) continue
          const end = this.getTilePosition(next)
          const isReachable = tile.reachable && next.reachable

          // Draw a thick shadow line behind the visible path.
          baseGraphics.lineStyle(isReachable ? 7 : 5, 0x000000, 0.5)
          baseGraphics.beginPath()
          baseGraphics.moveTo(start.x, start.y)
          baseGraphics.lineTo(end.x, end.y)
          baseGraphics.strokePath()

          const graphics = isReachable ? reachGraphics : baseGraphics
          const color = isReachable ? 0xaed6f1 : 0x5d6d7e
          const alpha = isReachable ? 0.95 : 0.5
          const thickness = isReachable ? 5 : 4

          graphics.lineStyle(thickness, color, alpha)
          graphics.beginPath()
          graphics.moveTo(start.x, start.y)
          graphics.lineTo(end.x, end.y)
          graphics.strokePath()
        }
      }
    }
  }

  drawTiles() {
    this.tileContainers = []

    for (const column of this.map.columns) {
      for (const tile of column) {
        const pos = this.getTilePosition(tile)
        const config = getTileConfig(tile.type)

        const container = this.add.container(pos.x, pos.y)
        container.setSize(TILE_RADIUS * 2, TILE_RADIUS * 2)

        // Tile body sits behind the label so we can blur it independently.
        const bodyContainer = this.add.container(0, 0)
        container.add(bodyContainer)

        // Ground shadow for a raised look
        const shadow = this.add.circle(3, 5, TILE_RADIUS, 0x000000, 0.4)
        bodyContainer.add(shadow)

        // Current tile glow (behind the tile body)
        if (tile.id === this.player.loadout.mapState.currentTileId) {
          const marker = this.add.circle(0, 0, CURRENT_PULSE_RADIUS, 0xf1c40f, 0.3)
          bodyContainer.add(marker)
          this.tweens.add({
            targets: marker,
            scale: 1.15,
            alpha: 0.1,
            duration: 900,
            yoyo: true,
            repeat: -1,
          })
        }

        // Thick black-to-gray border ring
        const outerRim = this.add.circle(0, 0, TILE_RADIUS + 5, 0x111111)
        bodyContainer.add(outerRim)
        const innerRim = this.add.circle(0, 0, TILE_RADIUS + 2, 0x7f8c8d)
        bodyContainer.add(innerRim)

        // Main colored tile
        const circle = this.add.circle(0, 0, TILE_RADIUS, config.color)
        bodyContainer.add(circle)

        const label = this.add.text(0, 0, config.label, FONT_LABEL)
        label.setOrigin(0.5)
        container.add(label)

        // Reachable tiles are interactive; others are blurred/masked.
        if (tile.reachable && !tile.completed) {
          container.setInteractive(new Phaser.Geom.Rectangle(-TILE_RADIUS, -TILE_RADIUS, TILE_RADIUS * 2, TILE_RADIUS * 2), Phaser.Geom.Rectangle.Contains)
          container.on('pointerdown', () => this.onTileClick(tile))

          this.input.setDefaultCursor('pointer')
          container.setAlpha(1)
        } else if (tile.completed) {
          bodyContainer.setAlpha(0.55)
          label.setAlpha(0.65)
        } else {
          if (typeof bodyContainer.enableFilters === 'function') {
            bodyContainer.enableFilters()
            bodyContainer.filters.internal.addBlur(0.5, 0, 0, 0.5, 0x000000, 2)
          }
          bodyContainer.setAlpha(0.75)
          label.setAlpha(0.9)
        }

        this.tileContainers.push(container)
      }
    }
  }

  getTilePosition(tile) {
    return {
      x: tile.x ?? 0,
      y: tile.y ?? 0,
    }
  }

  onTileClick(tile) {
    if (tile.completed || !tile.reachable) return

    // Allow clicking the current tile only if it is a battle tile (so the
    // player can enter a battle they are standing on). Otherwise ignore it.
    const isCurrentTile = tile.id === this.player.loadout.mapState.currentTileId
    if (isCurrentTile && !isBattleTile(tile.type)) return

    if (isBattleTile(tile.type)) {
      this.scene.start('LoadoutScene', { player: this.player, tile })
      return
    }

    this.runPlaceholderEvent(tile)
  }

  /**
   * Temporary placeholder for non-battle tiles.
   * Rolls 33/33/33: -5 HP / +5 HP / instant win.
   */
  runPlaceholderEvent(tile) {
    const roll = Math.random()
    let message, color, onComplete

    if (roll < 0.33) {
      message = 'Trap! You lose 5 HP.'
      color = 0xe74c3c
      onComplete = () => {
        this.player.hp = Math.max(0, this.player.hp - 5)
        this.completeTile(tile)
      }
    } else if (roll < 0.66) {
      message = 'Relief! You recover 5 HP.'
      color = 0x2ecc71
      onComplete = () => {
        this.player.hp = Math.min(this.player.maxHp, this.player.hp + 5)
        this.completeTile(tile)
      }
    } else {
      message = 'Lucky! Instant win.'
      color = 0xf1c40f
      onComplete = () => this.completeTile(tile)
    }

    this.showEventOverlay(message, color, onComplete)
  }

  completeTile(tile) {
    this.player.completeTile(tile.id)
    this.player.saveLoadout()

    if (this.player.hp <= 0) {
      this.player.hp = this.player.maxHp
      this.player.restartMap()
      this.scene.start('MapScene', { player: this.player })
      return
    }

    this.scene.start('MapScene', { player: this.player })
  }

  showEventOverlay(message, color, onComplete) {
    const overlay = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)

    const bg = this.add.rectangle(0, 0, 400, 180, 0x000000, 0.85)
    bg.setStrokeStyle(2, color)
    overlay.add(bg)

    const text = this.add.text(0, -30, message, {
      fontFamily: 'Arial',
      fontSize: '20px',
      color: '#ecf0f1',
      align: 'center',
      wordWrap: { width: 360 },
    }).setOrigin(0.5)
    overlay.add(text)

    const buttonBg = this.add.rectangle(0, 40, 140, 44, color)
    buttonBg.setInteractive()
    overlay.add(buttonBg)

    const buttonText = this.add.text(0, 40, 'Continue', {
      fontFamily: 'Arial',
      fontSize: '16px',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5)
    overlay.add(buttonText)

    buttonBg.on('pointerdown', () => {
      overlay.destroy()
      onComplete()
    })
  }

}
