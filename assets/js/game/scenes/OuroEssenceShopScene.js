import { GAME_CONFIG, COLORS, FONTS } from '../config.js'
import SHOP_DATA from '../data/ouroEssenceShop.json'
import { SOCKET_1_CHARMS, getSocketCharmById } from '../data/socketCharms.js'
import { CHARMS, CHARM_TYPES, getCharmById } from '../data/charms.js'
import { setupHighDPIWorld } from '../highDpi.js'

const MAX_STARTING_GOLD_BONUS = 150
const MAX_STARTING_POTION_BONUS = 4
const ROW_HEIGHT = 40
const ROW_WIDTH = 840
const BUTTON_RADIUS = 10
const BUTTON_SHADOW_ALPHA = 0.35

export default class OuroEssenceShopScene extends Phaser.Scene {
  constructor() {
    super({ key: 'OuroEssenceShopScene' })
  }

  init(data) {
    this.player = data.player
    this.tile = data.tile || null
    this.mapIndex = data.mapIndex ?? 0
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()
    this.createHeader()
    this.createCurrencyDisplay()
    this.createShopList()
    this.createBackButton()
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createHeader() {
    this.add.text(GAME_CONFIG.width / 2, 40, 'Ouro Essence Shop', {
      ...FONTS.title,
      fontSize: '30px',
      color: '#9b59b6',
    }).setOrigin(0.5)

    this.add.text(GAME_CONFIG.width / 2, 78, 'Permanent upgrades for this hero', {
      ...FONTS.default,
      fontSize: '14px',
      color: '#bdc3c7',
    }).setOrigin(0.5)
  }

  createCurrencyDisplay() {
    const essence = this.player.loadout.ouroEssence || 0
    const x = GAME_CONFIG.width - 140
    const y = 40
    this.add.image(x, y, 'ouro_essence').setDisplaySize(28, 28).setOrigin(0.5)
    this.add.text(x + 22, y, String(essence), {
      ...FONTS.default,
      fontSize: '20px',
      color: '#ecf0f1',
    }).setOrigin(0, 0.5)
  }

  buildShopItems() {
    const items = []
    const loadout = this.player.loadout
    const ownedSocket = new Set(loadout.ownedSocketCharmIds || [])
    const ownedHero = new Set(loadout.ownedCharmIds || [])
    const unlockedSocket = new Set(loadout.unlockedSocketCharmIds || [])
    const unlockedHero = new Set(loadout.unlockedHeroCharmIds || [])
    const overrides = SHOP_DATA.overrides || {}
    const defaults = SHOP_DATA.defaults || {}

    // Socket 1 weapon/secondary weapon charms.
    for (const charm of SOCKET_1_CHARMS) {
      if (!unlockedSocket.has(charm.id) || ownedSocket.has(charm.id)) continue
      items.push({
        type: 'socketCharm',
        id: charm.id,
        name: charm.name,
        price: overrides[charm.id] ?? defaults.socketCharm ?? 100,
        color: charm.color || 0xecf0f1,
      })
    }

    // Hero charms.
    for (const charmId of unlockedHero) {
      if (ownedHero.has(charmId)) continue
      const charm = getCharmById(charmId)
      if (!charm || charm.type !== CHARM_TYPES.HERO) continue
      items.push({
        type: 'heroCharm',
        id: charm.id,
        name: charm.name,
        price: overrides[charm.id] ?? defaults.heroCharm ?? 150,
        kanji: charm.kanji || '✨',
        color: charm.color || 0xecf0f1,
      })
    }

    // Starting gold upgrade.
    const goldBonus = loadout.startingGoldBonus || 0
    if (goldBonus < MAX_STARTING_GOLD_BONUS) {
      items.push({
        type: 'startingGold',
        id: 'starting_gold',
        name: `+10 starting gold (${goldBonus}/${MAX_STARTING_GOLD_BONUS})`,
        price: defaults.startingGold ?? 100,
        icon: '🪙',
      })
    }

    // Starting potion upgrade.
    const potionBonus = loadout.startingPotionBonus || 0
    if (potionBonus < MAX_STARTING_POTION_BONUS) {
      items.push({
        type: 'startingPotion',
        id: 'starting_potion',
        name: `+1 starting potion (${potionBonus}/${MAX_STARTING_POTION_BONUS})`,
        price: defaults.startingPotion ?? 100,
        icon: '🧪',
      })
    }

    // Trade essence for other currencies.
    items.push({
      type: 'ouroScale',
      id: 'ouro_scale',
      name: '1 Ouro Scale',
      price: defaults.ouroScale ?? 200,
      iconKey: 'ouro_scale',
    })

    items.push({
      type: 'ouroSource',
      id: 'ouro_source',
      name: '1 Ouro Source',
      price: defaults.ouroSource ?? 1000,
      iconKey: 'ouro_source',
    })

    return items
  }

  createShopList() {
    const items = this.buildShopItems()
    const startY = 110
    const maxY = GAME_CONFIG.height - 90
    const availableHeight = maxY - startY
    const rowHeight = Math.min(ROW_HEIGHT, Math.floor(availableHeight / Math.max(1, items.length)))

    if (items.length === 0) {
      this.add.text(GAME_CONFIG.width / 2, startY + 80, 'Nothing for sale right now.', {
        ...FONTS.default,
        fontSize: '16px',
        color: '#7f8c7d',
      }).setOrigin(0.5)
      return
    }

    items.forEach((item, index) => {
      const y = startY + index * rowHeight + rowHeight / 2
      this.createShopRow(item, y, rowHeight)
    })
  }

  createShopRow(item, y, rowHeight) {
    const essence = this.player.loadout.ouroEssence || 0
    const canAfford = essence >= item.price
    const bgColor = canAfford ? 0x16213e : 0x1a1a2e
    const strokeColor = canAfford ? 0x3498db : 0x555555

    const container = this.add.container(GAME_CONFIG.width / 2, y)

    const bg = this.add.rectangle(0, 0, ROW_WIDTH, rowHeight - 4, bgColor)
      .setStrokeStyle(1, strokeColor)
      .setOrigin(0.5)
    container.add(bg)

    // Item icon.
    if (item.iconKey) {
      container.add(this.add.image(-ROW_WIDTH / 2 + 30, 0, item.iconKey).setDisplaySize(24, 24).setOrigin(0.5))
    } else if (item.kanji) {
      container.add(this.add.text(-ROW_WIDTH / 2 + 30, 0, item.kanji, {
        fontFamily: FONTS.kanji.fontFamily,
        fontSize: '20px',
        color: '#ffffff',
      }).setOrigin(0.5))
    } else if (item.icon) {
      container.add(this.add.text(-ROW_WIDTH / 2 + 30, 0, item.icon, { fontSize: '20px' }).setOrigin(0.5))
    } else if (item.color) {
      container.add(this.add.circle(-ROW_WIDTH / 2 + 30, 0, 10, item.color).setOrigin(0.5))
    }

    // Name.
    container.add(this.add.text(-ROW_WIDTH / 2 + 60, 0, item.name, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
    }).setOrigin(0, 0.5))

    // Price.
    const priceX = ROW_WIDTH / 2 - 135
    const priceColor = canAfford ? '#9b59b6' : '#7f8c8d'
    container.add(this.add.image(priceX - 10, 0, 'ouro_essence').setDisplaySize(18, 18).setOrigin(0.5))
    container.add(this.add.text(priceX + 8, 0, String(item.price), {
      ...FONTS.default,
      fontSize: '14px',
      color: priceColor,
    }).setOrigin(0, 0.5))

    // Buy button — enlarged for mobile touch targets.
    const btnWidth = 96
    const btnHeight = 40
    const btnX = ROW_WIDTH / 2 - 25
    const btnColor = canAfford ? 0x9b59b6 : 0x555555
    const btnHover = canAfford ? 0x8e44ad : 0x555555

    const buyBtn = this.createRound3dButton({
      x: btnX,
      y: 0,
      width: btnWidth,
      height: btnHeight,
      label: canAfford ? 'Buy' : 'Need',
      baseColor: btnColor,
      hoverColor: btnHover,
      disabled: !canAfford,
      onClick: () => this.buyItem(item),
    })
    container.add(buyBtn)
  }

  buyItem(item) {
    const essence = this.player.loadout.ouroEssence || 0
    if (essence < item.price) return

    this.player.spendOuroEssence(item.price)

    switch (item.type) {
      case 'socketCharm':
        if (!this.player.loadout.ownedSocketCharmIds) this.player.loadout.ownedSocketCharmIds = []
        this.player.loadout.ownedSocketCharmIds.push(item.id)
        this.autoEquipSocketCharm(item.id)
        break
      case 'heroCharm':
        this.player.addCharm(item.id)
        break
      case 'startingGold':
        this.player.loadout.startingGoldBonus = Math.min(
          MAX_STARTING_GOLD_BONUS,
          (this.player.loadout.startingGoldBonus || 0) + 10
        )
        break
      case 'startingPotion':
        this.player.loadout.startingPotionBonus = Math.min(
          MAX_STARTING_POTION_BONUS,
          (this.player.loadout.startingPotionBonus || 0) + 1
        )
        break
      case 'ouroScale':
        this.player.addOuroScales(1)
        break
      case 'ouroSource':
        this.player.addOuroSource(1)
        break
      default:
        break
    }

    this.player.saveLoadout()
    this.scene.restart({ player: this.player, tile: this.tile, mapIndex: this.mapIndex })
  }

  autoEquipSocketCharm(charmId) {
    const charm = getSocketCharmById(charmId)
    if (!charm) return
    const equipment = charm.equipmentType === 'secondary_weapon' ? this.player.shield : this.player.weapon
    if (equipment && equipment.socketCharmIds && !equipment.socketCharmIds[0]) {
      equipment.socketCharmIds[0] = charmId
    }
  }

  createBackButton() {
    this.createRound3dButton({
      x: GAME_CONFIG.width / 2,
      y: GAME_CONFIG.height - 50,
      width: 220,
      height: 46,
      label: 'Back to Home Camp',
      baseColor: 0x27ae60,
      hoverColor: 0x2ecc71,
      onClick: () => this.scene.start('HomeShopScene', { player: this.player, tile: this.tile, mapIndex: this.mapIndex }),
    })
  }

  createRound3dButton({ x, y, width, height, label, baseColor, hoverColor, disabled = false, onClick }) {
    const container = this.add.container(x, y)

    const shadow = this.add.graphics()
    shadow.fillStyle(0x000000, BUTTON_SHADOW_ALPHA)
    shadow.fillRoundedRect(-width / 2 + 3, -height / 2 + 4, width, height, BUTTON_RADIUS)
    container.add(shadow)

    const bg = this.add.graphics()
    const drawBg = (color) => {
      bg.clear()
      bg.fillStyle(color, 1)
      bg.fillRoundedRect(-width / 2, -height / 2, width, height, BUTTON_RADIUS)
      bg.lineStyle(2, 0xffffff, 0.15)
      bg.strokeRoundedRect(-width / 2, -height / 2, width, height, BUTTON_RADIUS)
    }
    drawBg(baseColor)
    container.add(bg)

    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ffffff',
    }).setOrigin(0.5)
    container.add(text)

    if (!disabled) {
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
    }

    return container
  }
}
