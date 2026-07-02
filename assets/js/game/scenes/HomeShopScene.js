import { GAME_CONFIG, FONTS } from '../config.js'

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
    this.createBackground()
    this.createTitle()
    this.createTokenDisplay()
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
    const essence = this.player.loadout.ouroEssence || 0

    const y = 80
    const gap = 100
    const startX = GAME_CONFIG.width / 2

    this.createCurrencyBadge(startX - gap, y, 'ouro_scale', scales)
    this.createCurrencyBadge(startX, y, 'ouro_source', source)
    this.createCurrencyBadge(startX + gap, y, 'ouro_essence', essence)
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

  createCostDisplay(x, y, item, canAfford) {
    const color = canAfford ? '#f1c40f' : '#bdc3c7'
    const iconSize = 16
    const fontSize = '14px'
    const parts = []
    if (item.costSource > 0) parts.push({ key: 'ouro_source', amount: item.costSource })
    if (item.costScales > 0) parts.push({ key: 'ouro_scale', amount: item.costScales })

    // Build right-to-left so the whole cost group is right-aligned at x.
    let cursorX = x
    for (let i = parts.length - 1; i >= 0; i--) {
      const part = parts[i]
      const text = this.add.text(cursorX - 4, y, String(part.amount), {
        ...FONTS.default,
        fontSize,
        color,
      }).setOrigin(1, 0.5)
      const textWidth = text.width
      const iconX = cursorX - textWidth - 4 - iconSize / 2
      this.add.image(iconX, y, part.key).setDisplaySize(iconSize, iconSize).setOrigin(0.5)
      cursorX = iconX - iconSize / 2 - 6
    }
  }

  createShopList() {
    const startY = 130
    const rowHeight = 52

    SHOP_ITEMS.forEach((item, index) => {
      const y = startY + index * rowHeight
      const canAfford = this.canAfford(item)
      const color = canAfford ? 0x2980b9 : 0x555555

      const bg = this.add.rectangle(GAME_CONFIG.width / 2, y, 420, 44, color).setInteractive({ useHandCursor: canAfford }).setOrigin(0.5)
      const icon = this.add.text(GAME_CONFIG.width / 2 - 180, y, item.icon, { fontSize: '20px' }).setOrigin(0.5)
      const label = this.add.text(GAME_CONFIG.width / 2 - 130, y, item.name, {
        ...FONTS.default,
        fontSize: '14px',
        color: '#ffffff',
      }).setOrigin(0, 0.5)
      this.createCostDisplay(GAME_CONFIG.width / 2 + 160, y, item, canAfford)

      if (canAfford) {
        bg.on('pointerdown', () => this.buyItem(item))
        bg.on('pointerover', () => bg.setFillStyle(0x3498db))
        bg.on('pointerout', () => bg.setFillStyle(0x2980b9))
      }

      this.add.container(0, 0, [bg, icon, label])
    })
  }

  createPrepareButton() {
    const btn = this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height - 50, 220, 46, 0x27ae60).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height - 50, 'Prepare for Battle', {
      ...FONTS.default,
      fontSize: '16px',
      color: '#ffffff',
    }).setOrigin(0.5)

    btn.on('pointerdown', () => this.leaveShop())
    btn.on('pointerover', () => btn.setFillStyle(0x2ecc71))
    btn.on('pointerout', () => btn.setFillStyle(0x27ae60))
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
