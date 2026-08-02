import { GAME_CONFIG } from '../config.js'
import { TILE_TYPES, getTileConfig, isBattleTile } from '../data/tileTypes.js'
import Player from '../entities/Player.js'
import { getWindowGameData } from '../api.js'
import { updateReachability, findTileById, computeLayout, getMapName } from '../systems/MapGenerator.js'
import { ENEMY_DEFINITIONS, getEnemyDefinition } from '../data/enemies/index.js'
import { setupHighDPIWorld } from '../highDpi.js'

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
const FONT_LABEL = { fontFamily: 'Arial', fontSize: '11px', color: '#ffffff', fontStyle: 'bold', stroke: '#000000', strokeThickness: 3 }

// Dev test fight picker: Raijū first, then Tanuki and his clone, then the rest in registry order.
const TEST_FIGHT_ENEMIES = [...ENEMY_DEFINITIONS].sort((a, b) => {
  const rank = { hone_onna: -4, raiju_sekigan: -3, danzaburo_danuki: -2, tanuki_clone: -1 }
  return (rank[a.id] || 0) - (rank[b.id] || 0)
})

export default class MapScene extends Phaser.Scene {
  constructor() {
    super({ key: 'MapScene' })
  }

  init(data) {
    this.player = data.player || new Player(getWindowGameData())
    // Reset transition state when the scene is restarted (e.g. after an event).
    this.transitioning = false
  }

  create() {
    setupHighDPIWorld(this)
    this.setupMap()
    this.createBackground()
    this.createHud()
    this.drawMap()
    this.updateHud()
  }

  createBackground() {
    const bgCfg = this.map.background
    if (bgCfg?.image && this.textures.exists(bgCfg.image)) {
      const src = this.textures.get(bgCfg.image).getSourceImage()
      // Base scale fills the canvas; the JSON scale acts as a zoom multiplier.
      const baseScaleX = GAME_CONFIG.width / (src.width || GAME_CONFIG.width)
      const baseScaleY = GAME_CONFIG.height / (src.height || GAME_CONFIG.height)
      const scale = bgCfg.scale ?? 1
      const offsetLeft = bgCfg.offset?.left || 0
      const offsetTop = bgCfg.offset?.top || 0

      const bg = this.add.image(
        GAME_CONFIG.width / 2 + offsetLeft,
        GAME_CONFIG.height / 2 + offsetTop,
        bgCfg.image,
      )
      bg.setScale(baseScaleX * scale, baseScaleY * scale)
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

    // Safety reset: a missing cursor means the save is corrupted, so roll to a
    // fresh map. A completed cursor is normally a decision point (the outgoing
    // edges are the choices), so we only move it if the tile has no uncompleted
    // connections left — which happens when the boss is defeated or an old save
    // is stuck past a fully-cleared branch.
    let currentTile = this.map.columns.flat().find(t => t.id === this.player.loadout.mapState.currentTileId)
    if (!currentTile) {
      this.player.advanceMap()
      this.map = this.player.getCurrentMap()
      computeLayout(this.map)
      updateReachability(this.map, this.player.loadout.mapState.currentTileId)
    } else if (currentTile.completed) {
      const isBoss = currentTile.type === TILE_TYPES.BOSS
      const hasOpenConnection = currentTile.connections.some(id => {
        const next = findTileById(this.map, id)
        return next && !next.completed
      })

      if (isBoss || !hasOpenConnection) {
        const recoveredId = isBoss ? null : this.findFirstUncompletedTile(currentTile.id)

        if (recoveredId) {
          this.player.loadout.mapState.currentTileId = recoveredId
          this.player.saveLoadout()
        } else {
          this.player.advanceMap()
        }

        this.map = this.player.getCurrentMap()
        computeLayout(this.map)
        updateReachability(this.map, this.player.loadout.mapState.currentTileId)
      }
    }
  }

  findFirstUncompletedTile(startId, visited = new Set()) {
    const tile = findTileById(this.map, startId)
    if (!tile || visited.has(startId)) return null
    visited.add(startId)
    if (!tile.completed) return startId
    for (const nextId of tile.connections) {
      const found = this.findFirstUncompletedTile(nextId, visited)
      if (found) return found
    }
    return null
  }

  buildPathToCurrent(currentTile) {
    const path = [currentTile]
    let tile = currentTile
    while (tile.col > 0) {
      const prevColumn = this.map.columns[tile.col - 1]
      const prev = prevColumn.find(t => t.connections.includes(tile.id) && t.completed)
      if (!prev) break
      path.unshift(prev)
      tile = prev
    }
    return path
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

    this.hud.essenceIcon = this.add.image(20, 119, 'ouro_essence').setDisplaySize(18, 18).setOrigin(0, 0.5)
    this.hud.essence = this.add.text(42, 108, '', {
      fontFamily: 'Arial',
      fontSize: '16px',
      color: '#f1c40f',
      stroke: '#000000',
      strokeThickness: 3,
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

    // DEV ONLY: reset the current run back to hero select.
    this.hud.resetBtn = this.add.text(GAME_CONFIG.width - 16, 16, 'DEV: RESET RUN', {
      fontFamily: 'Arial',
      fontSize: '12px',
      color: '#ffffff',
      backgroundColor: '#c0392b',
      padding: { left: 8, right: 8, top: 4, bottom: 4 },
    }).setOrigin(1, 0).setInteractive({ useHandCursor: true })
    this.hud.resetBtn.on('pointerdown', () => {
      this.player.resetToFreshHero()
      this.scene.start('HeroSelectScene', { player: this.player })
    })

    // DEV ONLY: wipe all meta-progression and return to hero select.
    this.hud.hardResetBtn = this.add.text(GAME_CONFIG.width - 16, 46, 'DEV: HARD RESET', {
      fontFamily: 'Arial',
      fontSize: '12px',
      color: '#ffffff',
      backgroundColor: '#8e44ad',
      padding: { left: 8, right: 8, top: 4, bottom: 4 },
    }).setOrigin(1, 0).setInteractive({ useHandCursor: true })
    this.hud.hardResetBtn.on('pointerdown', () => {
      this.player.hardReset()
      this.scene.start('HeroSelectScene', { player: this.player })
    })

    // DEV ONLY: start a test fight with a chosen enemy and count.
    this.hud.testFightBtn = this.add.text(GAME_CONFIG.width - 16, 76, 'DEV: TEST FIGHT', {
      fontFamily: 'Arial',
      fontSize: '12px',
      color: '#ffffff',
      backgroundColor: '#2980b9',
      padding: { left: 8, right: 8, top: 4, bottom: 4 },
    }).setOrigin(1, 0).setInteractive({ useHandCursor: true })
    this.hud.testFightBtn.on('pointerdown', () => this.showTestFightDialog())
  }

  updateHud() {
    const userData = getWindowGameData()
    this.hud.title.setText(getMapName(this.map, userData?.level) || `Map ${this.map.index + 1}`)
    this.hud.hp.setText(`HP: ${this.player.hp}/${this.player.maxHp}`)
    this.hud.gold.setText(`Gold: ${this.player.loadout.gold || 0}`)
    this.hud.essence.setText(String(this.player.loadout.ouroEssence || 0))
  }

  showTestFightDialog() {
    if (this.testFightDialog) return

    this.testFightSelection = { enemyIndex: 0, count: 1 }

    const container = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    container.setDepth(100)

    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.7).setOrigin(0.5)
    backdrop.setInteractive()
    container.add(backdrop)

    const panel = this.add.rectangle(0, 0, 360, 260, 0x1a1a2e).setStrokeStyle(2, 0x3498db).setOrigin(0.5)
    container.add(panel)

    const title = this.add.text(0, -90, 'TEST FIGHT', {
      fontFamily: 'Arial', fontSize: '20px', color: '#f1c40f', fontStyle: 'bold',
    }).setOrigin(0.5)
    container.add(title)

    const createRow = (y, labelText, onClick) => {
      const bg = this.add.rectangle(0, y, 280, 36, 0x2c3e50).setInteractive({ useHandCursor: true }).setOrigin(0.5)
      const label = this.add.text(0, y, labelText, {
        fontFamily: 'Arial', fontSize: '14px', color: '#ecf0f1',
      }).setOrigin(0.5)
      bg.on('pointerdown', onClick)
      bg.on('pointerover', () => bg.setFillStyle(0x34495e))
      bg.on('pointerout', () => bg.setFillStyle(0x2c3e50))
      container.add(bg)
      container.add(label)
      return label
    }

    this.testFightEnemyLabel = createRow(-30, '', () => {
      this.testFightSelection.enemyIndex =
        (this.testFightSelection.enemyIndex + 1) % TEST_FIGHT_ENEMIES.length
      this.updateTestFightDialog()
    })

    this.testFightCountLabel = createRow(20, '', () => {
      this.testFightSelection.count = this.testFightSelection.count >= 3 ? 1 : this.testFightSelection.count + 1
      this.updateTestFightDialog()
    })

    const startBtn = this.add.rectangle(-70, 80, 120, 36, 0x27ae60).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const startText = this.add.text(-70, 80, 'START', { fontFamily: 'Arial', fontSize: '14px', color: '#ffffff' }).setOrigin(0.5)
    startBtn.on('pointerdown', () => this.startTestFight())
    startBtn.on('pointerover', () => startBtn.setFillStyle(0x2ecc71))
    startBtn.on('pointerout', () => startBtn.setFillStyle(0x27ae60))
    container.add(startBtn)
    container.add(startText)

    const cancelBtn = this.add.rectangle(70, 80, 120, 36, 0x7f8c8d).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const cancelText = this.add.text(70, 80, 'CANCEL', { fontFamily: 'Arial', fontSize: '14px', color: '#ffffff' }).setOrigin(0.5)
    cancelBtn.on('pointerdown', () => this.hideTestFightDialog())
    cancelBtn.on('pointerover', () => cancelBtn.setFillStyle(0x95a5a6))
    cancelBtn.on('pointerout', () => cancelBtn.setFillStyle(0x7f8c8d))
    container.add(cancelBtn)
    container.add(cancelText)

    this.testFightDialog = container
    this.updateTestFightDialog()
  }

  updateTestFightDialog() {
    if (!this.testFightDialog) return
    const def = TEST_FIGHT_ENEMIES[this.testFightSelection.enemyIndex]
    this.testFightEnemyLabel.setText(`Enemy: ${def.name}`)
    this.testFightCountLabel.setText(`Count: ${this.testFightSelection.count}`)
  }

  hideTestFightDialog() {
    if (this.testFightDialog) {
      this.testFightDialog.destroy()
      this.testFightDialog = null
      this.testFightEnemyLabel = null
      this.testFightCountLabel = null
    }
  }

  startTestFight() {
    const def = TEST_FIGHT_ENEMIES[this.testFightSelection.enemyIndex]
    const count = this.testFightSelection.count
    this.hideTestFightDialog()

    const tile = {
      type: def.roles[0] || TILE_TYPES.BATTLE,
      col: 5,
      mapIndex: this.map.index,
      enemyId: def.id,
      testFightCount: count,
    }

    this.scene.start('BattleScene', { player: this.player, tile, mapIndex: this.map.index })
  }

  drawMap() {
    this.drawConnections()
    this.drawTiles()
  }

  drawConnections() {
    const baseGraphics = this.add.graphics()
    const reachGraphics = this.add.graphics()
    const pathGraphics = this.add.graphics()

    const currentTile = findTileById(this.map, this.player.loadout.mapState.currentTileId)
    const path = currentTile ? this.buildPathToCurrent(currentTile) : []

    // Edges that are part of the travelled path and whose both ends are
    // completed are drawn in green.
    const passedEdges = new Set()
    for (let i = 0; i < path.length - 1; i++) {
      const a = path[i]
      const b = path[i + 1]
      if (a.completed && b.completed) {
        passedEdges.add(`${a.id}->${b.id}`)
      }
    }

    // The "current" decision node is the last completed tile. If the glowing
    // tile itself is completed (branching decision point), use it; otherwise
    // use the completed predecessor it was reached from.
    const decisionNode = currentTile?.completed
      ? currentTile
      : path[path.length - 2] || currentTile

    const choiceEdges = new Set()
    if (decisionNode) {
      for (const nextId of decisionNode.connections) {
        choiceEdges.add(`${decisionNode.id}->${nextId}`)
      }
    }

    for (const column of this.map.columns) {
      for (const tile of column) {
        const start = this.getTilePosition(tile)
        for (const nextId of tile.connections) {
          const next = findTileById(this.map, nextId)
          if (!next) continue
          const end = this.getTilePosition(next)
          const edgeKey = `${tile.id}->${next.id}`
          const isPassed = passedEdges.has(edgeKey)
          const isChoice = choiceEdges.has(edgeKey)

          // Draw a thick shadow line behind the visible path.
          baseGraphics.lineStyle(isPassed || isChoice ? 7 : 5, 0x000000, 0.5)
          baseGraphics.beginPath()
          baseGraphics.moveTo(start.x, start.y)
          baseGraphics.lineTo(end.x, end.y)
          baseGraphics.strokePath()

          if (isPassed) {
            pathGraphics.lineStyle(5, 0x2ecc71, 0.95)
            pathGraphics.beginPath()
            pathGraphics.moveTo(start.x, start.y)
            pathGraphics.lineTo(end.x, end.y)
            pathGraphics.strokePath()
          } else if (isChoice) {
            reachGraphics.lineStyle(5, 0xaed6f1, 0.95)
            reachGraphics.beginPath()
            reachGraphics.moveTo(start.x, start.y)
            reachGraphics.lineTo(end.x, end.y)
            reachGraphics.strokePath()
          } else {
            baseGraphics.lineStyle(4, 0x5d6d7e, 0.5)
            baseGraphics.beginPath()
            baseGraphics.moveTo(start.x, start.y)
            baseGraphics.lineTo(end.x, end.y)
            baseGraphics.strokePath()
          }
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

        // Current tile glow (behind the tile body). Completed tiles keep the
        // saved currentTileId so their outgoing paths stay reachable, but we
        // don't draw the active marker on them — the hero has moved on.
        if (tile.id === this.player.loadout.mapState.currentTileId && !tile.completed) {
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

        // Optional map-specific tile image (e.g. Japanese Fields).
        const tileImageConfig = this.map.tileImages?.[tile.type]
        const tileImageKey = tileImageConfig?.image

        if (tileImageKey && this.textures.exists(tileImageKey)) {
          // Keep the same metal rim the generated tiles use so the map stays
          // visually consistent even when art is shown.
          const outerRim = this.add.circle(0, 0, TILE_RADIUS + 5, 0x111111)
          bodyContainer.add(outerRim)
          const innerRim = this.add.circle(0, 0, TILE_RADIUS + 2, 0x7f8c8d)
          bodyContainer.add(innerRim)

          // Don't add the offset shadow for art tiles; it would peek out and
          // make the tile look off-center.
          const offsetLeft = tileImageConfig.offset?.left || 0
          const offsetTop = tileImageConfig.offset?.top || 0
          const img = this.add.image(offsetLeft, offsetTop, tileImageKey)
          const src = this.textures.get(tileImageKey).getSourceImage()
          const srcW = src.width
          const srcH = src.height

          // Base scale fits the image inside the tile circle. The JSON scale is
          // a multiplier on top of that, so 1.0 reproduces the current behavior.
          const baseScale = (TILE_RADIUS * 2) / Math.max(srcW, srcH)
          const configScale = tileImageConfig.scale ?? 1
          img.setScale(baseScale * configScale)

          if (Math.abs(srcW - srcH) > 2) {
            // Portrait/landscape art is masked so its corners don't spill past
            // the circular tile boundary.
            const maskShape = this.add.circle(0, 0, TILE_RADIUS, 0xffffff)
            maskShape.setOrigin(0.5)
            maskShape.setVisible(false)
            bodyContainer.add(maskShape)
            img.setMask(maskShape.createGeometryMask())
          }

          bodyContainer.add(img)
        } else {
          // Ground shadow for a raised look (only for generated tiles).
          const shadow = this.add.circle(3, 5, TILE_RADIUS, 0x000000, 0.4)
          bodyContainer.add(shadow)

          // Thick black-to-gray border ring
          const outerRim = this.add.circle(0, 0, TILE_RADIUS + 5, 0x111111)
          bodyContainer.add(outerRim)
          const innerRim = this.add.circle(0, 0, TILE_RADIUS + 2, 0x7f8c8d)
          bodyContainer.add(innerRim)
          const circle = this.add.circle(0, 0, TILE_RADIUS, config.color)
          bodyContainer.add(circle)
        }

        const label = this.add.text(0, 0, config.label, FONT_LABEL)
        label.setOrigin(0.5)
        container.add(label)

        container.tileId = tile.id
        container.tileLabel = label

        // Reachable tiles are interactive; others are blurred/masked.
        if (tile.reachable && !tile.completed) {
          // Add an invisible circle on top that is larger than the visible tile
          // so the whole circle (rim included) is easy to click/tap.
          const hitArea = this.add.circle(0, 0, TILE_RADIUS + 12, 0x000000, 0)
          hitArea.setInteractive({ useHandCursor: true })
          hitArea.on('pointerdown', () => this.onTileClick(tile))
          container.add(hitArea)

          this.input.setDefaultCursor('pointer')
          container.setAlpha(1)
        } else if (tile.completed) {
          bodyContainer.setAlpha(0.55)
          label.setAlpha(0.65)

          // Add a small completion checkmark so finished tiles are unambiguous.
          const check = this.add.text(0, TILE_RADIUS + 8, '✓', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#2ecc71',
            fontStyle: 'bold',
          }).setOrigin(0.5)
          container.add(check)
        } else {
          // Unreachable tiles are dimmed but not blurred (blur can clip the
          // generated circle shapes in some browsers).
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
    if (this.transitioning) return

    // Only the current tile can be entered until it is finished. Once the
    // current tile is completed (branching decision point), its forward
    // connections become valid choices. This prevents accidentally skipping
    // tiles, which made the map edges look like they pointed too far ahead.
    const currentTileId = this.player.loadout.mapState.currentTileId
    const currentTile = findTileById(this.map, currentTileId)
    const isCurrent = tile.id === currentTileId
    if (currentTile && !currentTile.completed && !isCurrent) return

    // The clicked tile becomes the active cursor. This keeps the map cursor in
    // sync with the tile the player is actually entering, so completeTile() can
    // reliably advance from it even if the player clicked a forward connection.
    this.player.loadout.mapState.currentTileId = tile.id
    this.player.saveLoadout()

    this.transitioning = true

    const container = this.tileContainers.find(c => c.tileId === tile.id)
    if (!container) {
      this.doTileAction(tile)
      return
    }

    // Disable all tile interactions during the transition.
    for (const c of this.tileContainers) {
      c.disableInteractive()
    }
    if (this.hud.resetBtn) {
      this.hud.resetBtn.disableInteractive()
    }
    if (this.hud.hardResetBtn) {
      this.hud.hardResetBtn.disableInteractive()
    }
    this.input.setDefaultCursor('default')

    // Bring the chosen tile to the front and hide its label so it doesn't
    // become a blurry giant blob during the zoom.
    container.setDepth(100)
    if (container.tileLabel) {
      this.tweens.add({ targets: container.tileLabel, alpha: 0, duration: 300 })
    }

    // Fade out the other tiles and the HUD.
    const others = this.tileContainers.filter(c => c !== container)
    this.tweens.add({ targets: others, alpha: 0, duration: 600 })
    if (this.hud) {
      this.tweens.add({ targets: Object.values(this.hud), alpha: 0, duration: 600 })
    }

    // Zoom the tile to the centre of the screen.
    this.tweens.add({
      targets: container,
      x: GAME_CONFIG.width / 2,
      y: GAME_CONFIG.height / 2,
      scale: 4.5,
      duration: 900,
      ease: 'Quad.easeInOut',
      onComplete: () => this.doTileAction(tile),
    })
  }

  doTileAction(tile) {
    // Defensive: never re-enter a completed tile (prevents repeated rewards).
    if (tile.completed) return

    if (isBattleTile(tile.type)) {
      this.scene.start('LoadoutScene', { player: this.player, tile, mapIndex: this.map.index })
      return
    }

    if (tile.type === TILE_TYPES.MEMORY) {
      this.scene.start('MemoryScene', { player: this.player, tile, mapIndex: this.map.index })
      return
    }

    if (tile.type === TILE_TYPES.SHOP) {
      this.scene.start('ShopScene', { player: this.player, tile, mapIndex: this.map.index })
      return
    }

    if (tile.type === TILE_TYPES.REST_CAMP) {
      this.scene.start('RestScene', { player: this.player, tile, mapIndex: this.map.index })
      return
    }

    if (tile.type === TILE_TYPES.SHORT_CASCADE) {
      this.scene.start('CascadeScene', { player: this.player, tile, mapIndex: this.map.index })
      return
    }

    if (tile.type === TILE_TYPES.CHEST) {
      this.scene.start('ChestScene', { player: this.player, tile, mapIndex: this.map.index })
      return
    }

    if (tile.type === TILE_TYPES.HOME) {
      this.scene.start('HomeShopScene', { player: this.player, tile, mapIndex: this.map.index })
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
    overlay.setDepth(200)

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
