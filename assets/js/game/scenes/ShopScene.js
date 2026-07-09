import { GAME_CONFIG, FONTS } from '../config.js'
import Player, { getUpgradeCost } from '../entities/Player.js'
import { setupHighDPIWorld } from '../highDpi.js'

/**
 * Shop / Smith scene for upgrading weapon and shield.
 */
export default class ShopScene extends Phaser.Scene {
  constructor() {
    super({ key: 'ShopScene' })
  }

  init(data) {
    this.player = data.player
    this.tile = data.tile
    this.mapIndex = data.mapIndex
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()
    this.createHeader()
    this.createEquipmentPanel()
    this.createButtons()
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
    this.weaponText = this.add.text(GAME_CONFIG.width / 2, 90, this.formatEquipment(this.player.weapon, 'baseDamage'), {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
      align: 'center',
      wordWrap: { width: 400 },
    }).setOrigin(0.5)

    this.shieldText = this.add.text(GAME_CONFIG.width / 2, 170, this.formatEquipment(this.player.shield, 'baseDefense'), {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
      align: 'center',
      wordWrap: { width: 400 },
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

  createButtons() {
    this.weaponBtn = this.createButton(GAME_CONFIG.width / 2, 260, 'Upgrade Weapon', () => this.onUpgradeWeapon())
    this.shieldBtn = this.createButton(GAME_CONFIG.width / 2, 320, 'Upgrade Shield', () => this.onUpgradeShield())
    this.leaveBtn = this.createButton(GAME_CONFIG.width / 2, 400, 'Leave', () => this.completeTile(), 0x7f8c8d)
    this.updateButtonStates()
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
  }

  showToast(message) {
    if (this.toast) this.toast.destroy()
    this.toast = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 80)
    const bg = this.add.rectangle(0, 0, 320, 40, 0x000000, 0.85).setStrokeStyle(1, 0xf39c12).setOrigin(0.5)
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
