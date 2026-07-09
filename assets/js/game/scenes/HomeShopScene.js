import { GAME_CONFIG, FONTS } from '../config.js'
import { setupHighDPIWorld } from '../highDpi.js'

const SHOP_ITEMS = [
  { id: 'stat_point', name: '+1 Stat Point', icon: '🌟', costScales: 1, costSource: 0 },
  { id: 'chest', name: 'Open Chest', icon: '🎁', costScales: 2, costSource: 0 },
  { id: 'memory', name: 'Memory Game', icon: '🧠', costScales: 1, costSource: 0 },
  { id: 'cascade', name: 'Cascade Game', icon: '🌊', costScales: 1, costSource: 0 },
  { id: 'weapon_upgrade_run', name: 'Weapon Upgrade (this run)', icon: '⚔️', costScales: 1, costSource: 0 },
  { id: 'weapon_upgrade_permanent', name: 'Permanent Weapon Upgrade', icon: '💎', costScales: 5, costSource: 1 },
]

export default class HomeShopScene extends Phaser.Scene {
  constructor() {
    super({ key: 'HomeShopScene' })
  }

  init(data) {
    this.player = data.player
    this.tile = data.tile
    this.mapIndex = data.mapIndex
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()
    this.createTitle()
    this.createTokenDisplay()
    this.createBigEssenceCoin()
    this.createShopList()
    this.createPrepareButton()
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createTitle() {
    this.add.text(GAME_CONFIG.width / 2, 40, 'Home Camp', {
      ...FONTS.title,
      fontSize: '28px',
      color: '#f1c40f',
    }).setOrigin(0.5)
  }

  createTokenDisplay() {
    const scales = this.player.loadout.ouroScales || 0
    const source = this.player.loadout.ouroSource || 0

    const y = 80
    const gap = 100
    const startX = GAME_CONFIG.width / 2 - 50

    this.createCurrencyBadge(startX - gap, y, 'ouro_scale', scales)
    this.createCurrencyBadge(startX, y, 'ouro_source', source)
  }

  createBigEssenceCoin() {
    const essence = this.player.loadout.ouroEssence || 0
    const x = GAME_CONFIG.width - 90
    const y = 70
    const size = 80

    this.add.image(x, y, 'ouro_essence').setDisplaySize(size, size).setOrigin(0.5)
    this.add.text(x, y + size / 2 + 16, String(essence), {
      ...FONTS.default,
      fontSize: '20px',
      color: '#ecf0f1',
    }).setOrigin(0.5)

    this.createRound3dButton({
      x,
      y: y + size / 2 + 44,
      width: 150,
      height: 36,
      label: 'Essence Shop',
      baseColor: 0x9b59b6,
      hoverColor: 0x8e44ad,
      onClick: () => this.scene.start('OuroEssenceShopScene', { player: this.player, tile: this.tile, mapIndex: this.mapIndex }),
    })
  }

  createCurrencyBadge(x, y, iconKey, amount) {
    const icon = this.add.image(x - 10, y, iconKey).setDisplaySize(24, 24).setOrigin(0.5)
    const text = this.add.text(x + 10, y, String(amount), {
      ...FONTS.default,
      fontSize: '18px',
      color: '#ecf0f1',
    }).setOrigin(0, 0.5)
    this.add.container(0, 0, [icon, text])
  }

  createCostDisplay(x, y, item, canAfford, container = null) {
    const color = canAfford ? '#f1c40f' : '#bdc3c7'
    const iconSize = 16
    const fontSize = '14px'
    const parts = []
    if (item.costScales > 0) parts.push({ key: 'ouro_scale', amount: item.costScales })
    if (item.costSource > 0) parts.push({ key: 'ouro_source', amount: item.costSource })

    // Build right-to-left so the whole cost group is right-aligned at x.
    let cursorX = x
    const costObjects = []
    for (let i = parts.length - 1; i >= 0; i--) {
      const part = parts[i]
      const text = this.add.text(cursorX - 4, y, String(part.amount), {
        ...FONTS.default,
        fontSize,
        color,
      }).setOrigin(1, 0.5)
      const textWidth = text.width
      const iconX = cursorX - textWidth - 4 - iconSize / 2
      const icon = this.add.image(iconX, y, part.key).setDisplaySize(iconSize, iconSize).setOrigin(0.5)
      costObjects.push(text, icon)
      cursorX = iconX - iconSize / 2 - 6
    }
    if (container && costObjects.length > 0) {
      container.add(costObjects)
    }
  }

  createShopList() {
    const startY = 130
    const rowHeight = 52

    SHOP_ITEMS.forEach((item, index) => {
      const y = startY + index * rowHeight
      const canAfford = this.canAfford(item)
      const color = canAfford ? 0x2980b9 : 0x555555
      const hover = canAfford ? 0x3498db : 0x555555

      const row = this.createRound3dRow(GAME_CONFIG.width / 2, y, 420, 44, color, hover, () => this.buyItem(item), !canAfford)

      const icon = this.add.text(-180, 0, item.icon, { fontSize: '20px' }).setOrigin(0.5)
      const label = this.add.text(-130, 0, item.name, {
        ...FONTS.default,
        fontSize: '14px',
        color: '#ffffff',
      }).setOrigin(0, 0.5)
      row.add([icon, label])
      this.createCostDisplay(160, 0, item, canAfford, row)
    })
  }

  createPrepareButton() {
    this.createRound3dButton({
      x: GAME_CONFIG.width / 2,
      y: GAME_CONFIG.height - 50,
      width: 220,
      height: 46,
      label: 'Prepare for Battle',
      baseColor: 0x27ae60,
      hoverColor: 0x2ecc71,
      onClick: () => this.leaveShop(),
    })
  }

  createRound3dButton({ x, y, width, height, label, baseColor, hoverColor, onClick }) {
    const container = this.add.container(x, y)
    const radius = 10

    const shadow = this.add.graphics()
    shadow.fillStyle(0x000000, 0.35)
    shadow.fillRoundedRect(-width / 2 + 3, -height / 2 + 4, width, height, radius)
    container.add(shadow)

    const bg = this.add.graphics()
    const drawBg = (color) => {
      bg.clear()
      bg.fillStyle(color, 1)
      bg.fillRoundedRect(-width / 2, -height / 2, width, height, radius)
      bg.lineStyle(2, 0xffffff, 0.15)
      bg.strokeRoundedRect(-width / 2, -height / 2, width, height, radius)
    }
    drawBg(baseColor)
    container.add(bg)

    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ffffff',
    }).setOrigin(0.5)
    container.add(text)

    container.setSize(width, height)
    container.setInteractive({
      useHandCursor: true,
      hitArea: new Phaser.Geom.Rectangle(-width / 2, -height / 2, width, height),
      hitAreaCallback: Phaser.Geom.Rectangle.Contains,
    })
    container.on('pointerover', () => drawBg(hoverColor))
    container.on('pointerout', () => drawBg(baseColor))
    container.on('pointerdown', () => {
      text.y += 1
      bg.y += 1
    })
    container.on('pointerup', () => {
      text.y -= 1
      bg.y -= 1
      if (onClick) onClick()
    })

    return container
  }

  createRound3dRow(x, y, width, height, color, hoverColor, onClick, disabled = false) {
    const container = this.add.container(x, y)
    const radius = 8

    const shadow = this.add.graphics()
    shadow.fillStyle(0x000000, 0.25)
    shadow.fillRoundedRect(-width / 2 + 2, -height / 2 + 3, width, height, radius)
    container.add(shadow)

    const bg = this.add.graphics()
    const drawBg = (c) => {
      bg.clear()
      bg.fillStyle(c, 1)
      bg.fillRoundedRect(-width / 2, -height / 2, width, height, radius)
      bg.lineStyle(1, 0xffffff, 0.1)
      bg.strokeRoundedRect(-width / 2, -height / 2, width, height, radius)
    }
    drawBg(color)
    container.add(bg)

    if (!disabled) {
      container.setSize(width, height)
      container.setInteractive({
        useHandCursor: true,
        hitArea: new Phaser.Geom.Rectangle(-width / 2, -height / 2, width, height),
        hitAreaCallback: Phaser.Geom.Rectangle.Contains,
      })
      container.on('pointerover', () => drawBg(hoverColor))
      container.on('pointerout', () => drawBg(color))
      container.on('pointerdown', () => container.y += 1)
      container.on('pointerup', () => {
        container.y -= 1
        if (onClick) onClick()
      })
    }

    return container
  }

  canAfford(item) {
    return (this.player.loadout.ouroScales || 0) >= item.costScales &&
      (this.player.loadout.ouroSource || 0) >= item.costSource
  }

  buyItem(item) {
    if (!this.canAfford(item)) return

    switch (item.id) {
      case 'stat_point':
        this.player.loadout.permanentStatPointBonus = (this.player.loadout.permanentStatPointBonus || 0) + 1
        this.player.loadout.statPoints = (this.player.loadout.statPoints || 0) + 1
        this.player.saveLoadout()
        break
      case 'chest':
        this.spend(item)
        this.scene.start('ChestScene', { player: this.player, returnScene: 'HomeShopScene', skipCompleteTile: true })
        return
      case 'memory':
        this.spend(item)
        this.scene.start('MemoryScene', { player: this.player, returnScene: 'HomeShopScene', skipCompleteTile: true })
        return
      case 'cascade':
        this.spend(item)
        this.scene.start('CascadeScene', { player: this.player, returnScene: 'HomeShopScene', skipCompleteTile: true })
        return
      case 'weapon_upgrade_run':
        if (this.player.weapon && this.player.weapon.level < (this.player.weapon.maxLevel || 10)) {
          this.player.weapon.level = (this.player.weapon.level || 0) + 1
          this.player.weapon.baseDamage = (this.player.weapon.baseDamage || 0) + 2
          this.player.saveLoadout()
        }
        break
      case 'weapon_upgrade_permanent':
        this.player.loadout.permanentWeaponLevel = (this.player.loadout.permanentWeaponLevel || 0) + 1
        if (this.player.weapon) {
          this.player.weapon.level = (this.player.weapon.level || 0) + 1
          this.player.weapon.baseDamage = (this.player.weapon.baseDamage || 0) + 2
        }
        this.player.saveLoadout()
        break
      default:
        return
    }

    this.spend(item)
    this.scene.restart({ player: this.player, tile: this.tile, mapIndex: this.mapIndex })
  }

  spend(item) {
    this.player.loadout.ouroScales = (this.player.loadout.ouroScales || 0) - item.costScales
    this.player.loadout.ouroSource = (this.player.loadout.ouroSource || 0) - item.costSource
    this.player.saveLoadout()
  }

  leaveShop() {
    if (this.tile?.id) {
      this.player.completeTile(this.tile.id)
    }
    this.player.saveLoadout()
    this.scene.start('LoadoutScene', { player: this.player, mode: 'map', returnScene: 'MapScene' })
  }
}
