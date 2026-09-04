import { GAME_CONFIG, FONTS } from '../config.js'
import Player, { getUpgradeCost } from '../entities/Player.js'
import { setupHighDPIWorld } from '../highDpi.js'
import { CHARMS, CHARM_TYPES } from '../data/charms.js'
import { ALL_SOCKET_CHARMS } from '../data/socketCharms.js'
import { ALL_ACTIONS, getAbilityRarityColor } from '../data/actions.js'
import { ITEMS } from '../data/items.js'
import AbilityTooltip from '../ui/AbilityTooltip.js'

/**
 * Shop / Smith scene.
 * Offers weapon/shield upgrades plus a randomized stock of hero charms,
 * sword/shield socket charms, abilities, and consumable items.
 */

const RARITY_WEIGHTS = [
  { rarity: 'common', weight: 0.50, min: 30, max: 50 },
  { rarity: 'uncommon', weight: 0.30, min: 50, max: 70 },
  { rarity: 'rare', weight: 0.15, min: 70, max: 90 },
  { rarity: 'epic', weight: 0.05, min: 90, max: 130 },
]

const ITEM_RANGES = {
  health_potion: { min: 20, max: 30 },
  other: { min: 30, max: 50 },
}

export default class ShopScene extends Phaser.Scene {
  constructor() {
    super({ key: 'ShopScene' })
  }

  init(data) {
    this.player = data.player
    this.tile = data.tile
    this.mapIndex = data.mapIndex
    this.stock = this.generateStock()
  }

  create() {
    setupHighDPIWorld(this)
    this.tooltip = new AbilityTooltip(this)
    this.createBackground()
    this.createHeader()
    this.createEquipmentPanel()
    this.createEquipmentButtons()
    this.createStockPanel()
    this.createLeaveButton()
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createHeader() {
    this.add.text(GAME_CONFIG.width / 2, 28, 'Smithy', {
      ...FONTS.title,
      fontSize: '28px',
      color: '#f39c12',
    }).setOrigin(0.5)

    this.goldText = this.add.text(GAME_CONFIG.width - 20, 24, `Gold: ${this.player.loadout.gold || 0}`, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#f1c40f',
    }).setOrigin(1, 0)
  }

  createEquipmentPanel() {
    this.weaponText = this.add.text(220, 70, this.formatEquipment(this.player.weapon, 'baseDamage'), {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
      align: 'center',
      wordWrap: { width: 360 },
    }).setOrigin(0.5)

    this.shieldText = this.add.text(220, 260, this.formatEquipment(this.player.shield, 'baseDefense'), {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
      align: 'center',
      wordWrap: { width: 360 },
    }).setOrigin(0.5)
  }

  formatEquipment(item, baseStatKey) {
    if (!item) return 'None'
    const base = item[baseStatKey] ?? 0
    const level = item.level ?? 0
    const max = item.maxLevel ?? 0
    const cost = level >= max ? 'MAX' : getUpgradeCost(level)
    const scaling = item.scaling
      ? Object.entries(item.scaling).map(([stat, grade]) => `${stat.toUpperCase()} ${grade}`).join(' · ')
      : ''
    const sockets = item.name === 'Long Sword'
      ? this.player.getWeaponCharmSlots()
      : this.player.getShieldCharmSlots()
    return `${item.name} +${level}\nBase ${baseStatKey === 'baseDamage' ? 'ATK' : 'DEF'}: ${base}\nScaling: ${scaling}\nSockets: ${sockets}/4\nUpgrade: ${cost}G`
  }

  createEquipmentButtons() {
    this.weaponBtn = this.createButton(220, 170, 'Upgrade Weapon', () => this.onUpgradeWeapon())
    this.shieldBtn = this.createButton(220, 360, 'Upgrade Shield', () => this.onUpgradeShield())
    this.updateButtonStates()
  }

  createLeaveButton() {
    this.leaveBtn = this.createButton(GAME_CONFIG.width / 2, 490, 'Leave', () => this.completeTile(), 0x7f8c8d)
  }

  createButton(x, y, label, onClick, color = 0x2980b9) {
    const container = this.add.container(x, y)
    const bg = this.add.rectangle(0, 0, 200, 44, color).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: '16px',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5)
    container.add([bg, text])

    bg.on('pointerdown', () => {
      if (bg.input.enabled) onClick()
    })
    bg.on('pointerover', () => { if (bg.input.enabled) bg.setFillStyle(lighten(color)) })
    bg.on('pointerout', () => { if (bg.input.enabled) bg.setFillStyle(color) })

    return { container, bg, text, color }
  }

  createSmallButton(label, onClick, color = 0x2980b9) {
    const container = this.add.container(0, 0)
    const bg = this.add.rectangle(0, 0, 60, 24, color).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: '12px',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5)
    container.add([bg, text])

    bg.on('pointerdown', () => {
      if (bg.input.enabled) onClick()
    })
    bg.on('pointerover', () => { if (bg.input.enabled) bg.setFillStyle(lighten(color)) })
    bg.on('pointerout', () => { if (bg.input.enabled) bg.setFillStyle(color) })

    return { container, bg, text, color, setEnabled: (enabled) => {
      bg.input.enabled = enabled
      bg.setFillStyle(enabled ? color : 0x555555)
      text.setColor(enabled ? '#ffffff' : '#aaaaaa')
    }}
  }

  updateButtonStates() {
    this.setButtonEnabled(this.weaponBtn, this.canUpgrade(this.player.weapon))
    this.setButtonEnabled(this.shieldBtn, this.canUpgrade(this.player.shield))
  }

  canUpgrade(item) {
    if (!item) return false
    if (item.level >= item.maxLevel) return false
    return (this.player.loadout.gold || 0) >= getUpgradeCost(item.level)
  }

  setButtonEnabled(btn, enabled) {
    btn.bg.input.enabled = enabled
    btn.bg.setFillStyle(enabled ? btn.color : 0x555555)
    btn.text.setColor(enabled ? '#ffffff' : '#aaaaaa')
  }

  onUpgradeWeapon() {
    const result = this.player.upgradeWeapon()
    this.handleUpgradeResult(result, this.weaponText, 'baseDamage')
  }

  onUpgradeShield() {
    const result = this.player.upgradeShield()
    this.handleUpgradeResult(result, this.shieldText, 'baseDefense')
  }

  handleUpgradeResult(result, textObj, baseStatKey) {
    if (result.ok) {
      this.showToast(`${result.level > 0 ? '+' + result.level : ''} upgrade complete!`)
      textObj.setText(this.formatEquipment(baseStatKey === 'baseDamage' ? this.player.weapon : this.player.shield, baseStatKey))
    } else {
      this.showToast(result.reason)
    }
    this.goldText.setText(`Gold: ${this.player.loadout.gold || 0}`)
    this.updateButtonStates()
    this.refreshStockButtons()
  }

  // ---------- Stock generation ----------

  generateStock() {
    const stock = []
    const ownedCharms = new Set(this.player.loadout.ownedCharmIds || [])
    const ownedSocketCharms = new Set(this.player.loadout.ownedSocketCharmIds || [])
    const knownActions = new Set(this.player.loadout.knownActionIds || [])

    // 1-2 hero charms
    const heroPool = shuffle(CHARMS.filter(
      c => c.type === CHARM_TYPES.HERO && !ownedCharms.has(c.id)
    ))
    for (let i = 0; i < Math.min(randomInt(1, 2), heroPool.length); i++) {
      const charm = heroPool[i]
      const rarity = charm.rarity || pickRarity()
      const range = RARITY_WEIGHTS.find(r => r.rarity === rarity) || RARITY_WEIGHTS[0]
      stock.push({
        type: 'heroCharm',
        data: charm,
        price: randomInt(range.min, range.max),
        qty: 1,
      })
    }

    // 1-3 sword/shield charms
    const socketPool = shuffle(ALL_SOCKET_CHARMS.filter(
      c => !ownedSocketCharms.has(c.id)
    ))
    for (let i = 0; i < Math.min(randomInt(1, 3), socketPool.length); i++) {
      const charm = socketPool[i]
      const rarity = charm.rarity || pickRarity()
      const range = RARITY_WEIGHTS.find(r => r.rarity === rarity) || RARITY_WEIGHTS[0]
      stock.push({
        type: 'socketCharm',
        data: charm,
        price: randomInt(range.min, range.max),
        qty: 1,
      })
    }

    // 2-5 abilities
    const abilityPool = shuffle(ALL_ACTIONS.filter(
      a => a.id !== 'use_item' && (!knownActions.has(a.id) || a.singleUse)
    ))
    for (let i = 0; i < Math.min(randomInt(2, 5), abilityPool.length); i++) {
      const action = abilityPool[i]
      const rarity = action.rarity || pickRarity()
      const range = RARITY_WEIGHTS.find(r => r.rarity === rarity) || RARITY_WEIGHTS[0]
      stock.push({
        type: 'ability',
        data: action,
        price: randomInt(range.min, range.max),
        qty: 1,
      })
    }

    // Health potions, 1-5
    const potionCount = randomInt(1, 5)
    const potion = ITEMS.find(i => i.id === 'health_potion')
    if (potion) {
      stock.push({
        type: 'item',
        data: potion,
        price: randomInt(ITEM_RANGES.health_potion.min, ITEM_RANGES.health_potion.max),
        qty: potionCount,
      })
    }

    // Other items, 2-5
    const otherPool = shuffle(ITEMS.filter(i => i.id !== 'health_potion' && i.id !== 'large_health_potion'))
    const otherCount = randomInt(2, 5)
    for (let i = 0; i < Math.min(otherCount, otherPool.length); i++) {
      const item = otherPool[i]
      stock.push({
        type: 'item',
        data: item,
        price: randomInt(ITEM_RANGES.other.min, ITEM_RANGES.other.max),
        qty: 1,
      })
    }

    return stock
  }

  // ---------- Stock rendering ----------

  createStockPanel() {
    const startX = 600
    const startY = 70
    const rowHeight = 26

    this.add.text(startX, 48, 'Wares', {
      ...FONTS.default,
      fontSize: '16px',
      color: '#f39c12',
      fontStyle: 'bold',
    }).setOrigin(0.5)

    this.stockRows = []

    if (this.stock.length === 0) {
      this.add.text(startX, startY + 20, 'Nothing for sale.', {
        ...FONTS.default,
        fontSize: '14px',
        color: '#95a5a6',
      }).setOrigin(0.5)
      return
    }

    this.stock.forEach((entry, index) => {
      const y = startY + index * rowHeight
      const row = this.createStockRow(startX, y, entry)
      this.stockRows.push(row)
    })
  }

  createStockRow(x, y, entry) {
    const container = this.add.container(x, y)
    const name = this.entryName(entry)
    const label = entry.qty > 1 ? `${name} x${entry.qty}` : name
    const rarity = entry.data.rarity || 'common'
    const rarityColor = hexToCss(getAbilityRarityColor(rarity).main)

    const kanji = this.entryKanji(entry)
    const kanjiText = this.add.text(-200, 0, kanji, {
      ...FONTS.kanji,
      fontSize: '16px',
      color: rarityColor,
      fontStyle: 'bold',
    }).setOrigin(0.5)

    const nameText = this.add.text(-170, 0, label, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ecf0f1',
    }).setOrigin(0, 0.5)

    const priceText = this.add.text(-10, 0, `${entry.price}G`, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#f1c40f',
    }).setOrigin(0.5)

    const buyBtn = this.createSmallButton('Buy', () => this.onBuy(entry), 0x27ae60)
    buyBtn.container.x = 70
    container.add([kanjiText, nameText, priceText, buyBtn.container])

    const tooltipData = this.buildTooltipData(entry)
    kanjiText.setInteractive({ useHandCursor: true })
    nameText.setInteractive({ useHandCursor: true })
    this.tooltip.attach(kanjiText, tooltipData)
    this.tooltip.attach(nameText, tooltipData)

    const row = { container, nameText, priceText, buyBtn, entry }
    this.refreshRow(row)
    return row
  }

  entryKanji(entry) {
    if (entry.type === 'item') return entry.data.icon || '•'
    return entry.data.kanji || '◆'
  }

  buildTooltipData(entry) {
    switch (entry.type) {
      case 'heroCharm': {
        const charm = entry.data
        return {
          name: charm.name,
          type: 'Hero Charm',
          rarity: charm.rarity || 'common',
          description: this.formatCharmEffect(charm),
        }
      }
      case 'socketCharm': {
        const charm = entry.data
        return {
          name: charm.name,
          type: charm.equipmentType === 'secondary_weapon' ? 'Shield Charm' : 'Weapon Charm',
          rarity: charm.rarity || 'common',
          description: charm.description || '',
        }
      }
      case 'ability': {
        const action = entry.data
        return {
          name: action.name,
          type: action.type || 'ability',
          rarity: action.rarity || 'common',
          staminaCost: action.staminaCost,
          description: action.description || '',
        }
      }
      case 'item': {
        const item = entry.data
        return {
          name: item.name,
          type: 'Item',
          rarity: item.rarity || 'common',
          description: item.description || '',
        }
      }
      default:
        return { name: entry.data.name || '???', type: '???', rarity: 'common', description: '' }
    }
  }

  formatCharmEffect(charm) {
    if (!charm.effect) return ''
    if (Array.isArray(charm.effect.stats)) {
      return charm.effect.stats.map(s => `+${charm.effect.value} ${s}`).join(', ')
    }
    if (charm.effect.stat) {
      return `+${charm.effect.value} ${charm.effect.stat}`
    }
    return ''
  }

  entryName(entry) {
    switch (entry.type) {
      case 'heroCharm': return entry.data.name
      case 'socketCharm': return entry.data.name
      case 'ability': return entry.data.name
      case 'item': return entry.data.name
      default: return '???'
    }
  }

  onBuy(entry) {
    if ((this.player.loadout.gold || 0) < entry.price) {
      this.showToast('Not enough gold.')
      return
    }

    let ok = false
    let message = ''

    switch (entry.type) {
      case 'heroCharm':
        this.player.loadout.gold -= entry.price
        this.player.addCharm(entry.data.id)
        ok = true
        message = `Acquired ${entry.data.name}!`
        break
      case 'socketCharm':
        this.player.loadout.gold -= entry.price
        this.player.addSocketCharm(entry.data.id)
        ok = true
        message = `Acquired ${entry.data.name}!`
        break
      case 'ability':
        this.player.loadout.gold -= entry.price
        this.player.addAbilityCharges(entry.data.id, 1)
        ok = true
        message = `Learned ${entry.data.name}!`
        break
      case 'item':
        this.player.loadout.gold -= entry.price
        this.player.addItem(entry.data.id, entry.qty)
        ok = true
        message = entry.qty > 1 ? `Bought ${entry.qty}x ${entry.data.name}.` : `Bought ${entry.data.name}.`
        break
    }

    if (!ok) return

    this.player.saveLoadout()
    this.goldText.setText(`Gold: ${this.player.loadout.gold || 0}`)
    this.showToast(message)
    this.updateButtonStates()
    this.refreshStockButtons()

    // Mark this row as sold out.
    const row = this.stockRows.find(r => r.entry === entry)
    if (row) {
      row.entry.sold = true
      row.nameText.setText(`${this.entryName(row.entry)} — SOLD`)
      row.nameText.setColor('#7f8c8d')
      row.buyBtn.setEnabled(false)
    }
  }

  refreshStockButtons() {
    if (!this.stockRows) return
    const gold = this.player.loadout.gold || 0
    this.stockRows.forEach(row => {
      if (row.entry.sold) return
      row.buyBtn.setEnabled(gold >= row.entry.price)
    })
  }

  refreshRow(row) {
    const gold = this.player.loadout.gold || 0
    row.buyBtn.setEnabled(!row.entry.sold && gold >= row.entry.price)
  }

  showToast(message) {
    if (this.toast) this.toast.destroy()
    this.toast = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 80)
    const bg = this.add.rectangle(0, 0, 340, 40, 0x000000, 0.85).setStrokeStyle(1, 0xf39c12).setOrigin(0.5)
    const text = this.add.text(0, 0, message, { ...FONTS.default, fontSize: '14px', color: '#f39c12' }).setOrigin(0.5)
    this.toast.add([bg, text])
    this.time.delayedCall(1500, () => {
      if (this.toast) {
        this.toast.destroy()
        this.toast = null
      }
    })
  }

  completeTile() {
    if (this.tile?.id) this.player.completeTile(this.tile.id)
    this.player.saveLoadout()
    this.scene.start('MapScene', { player: this.player })
  }
}

function lighten(color) {
  const r = (color >> 16) & 0xff
  const g = (color >> 8) & 0xff
  const b = color & 0xff
  const clamp = (v) => Math.min(255, Math.floor(v * 1.15))
  return (clamp(r) << 16) | (clamp(g) << 8) | clamp(b)
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min
}

function shuffle(array) {
  const arr = [...array]
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[arr[i], arr[j]] = [arr[j], arr[i]]
  }
  return arr
}

function pickRarity() {
  const roll = Math.random()
  let cumulative = 0
  for (const entry of RARITY_WEIGHTS) {
    cumulative += entry.weight
    if (roll < cumulative) return entry.rarity
  }
  return 'common'
}

function hexToCss(hex) {
  const num = typeof hex === 'number' ? hex : parseInt(String(hex).replace('#', ''), 16)
  const r = (num >> 16) & 0xff
  const g = (num >> 8) & 0xff
  const b = num & 0xff
  return `rgb(${r}, ${g}, ${b})`
}
