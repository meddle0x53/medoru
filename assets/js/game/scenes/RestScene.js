import { GAME_CONFIG, FONTS } from '../config.js'
import Player, { getUpgradeCost } from '../entities/Player.js'

/**
 * Rest Camp scene — recover HP or spend gold to upgrade equipment.
 */
export default class RestScene extends Phaser.Scene {
  constructor() {
    super({ key: 'RestScene' })
  }

  init(data) {
    this.player = data.player
    this.tile = data.tile
    this.mapIndex = data.mapIndex
  }

  create() {
    this.createBackground()
    this.createHeader()
    this.createInfoPanel()
    this.createButtons()
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createHeader() {
    this.add.text(GAME_CONFIG.width / 2, 28, 'Rest Camp', {
      ...FONTS.title,
      fontSize: '28px',
      color: '#2ecc71',
    }).setOrigin(0.5)

    this.goldText = this.add.text(GAME_CONFIG.width - 20, 24, `Gold: ${this.player.loadout.gold || 0}`, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#f1c40f',
    }).setOrigin(1, 0)
  }

  createInfoPanel() {
    const w = this.player.weapon
    const cost = w && w.level < w.maxLevel ? getUpgradeCost(w.level) : 'MAX'
    const info = [
      `HP: ${this.player.hp}/${this.player.maxHp}`,
      `${w?.name || 'Weapon'} +${w?.level || 0} · Upgrade: ${cost}G`,
    ].join('\n')

    this.infoText = this.add.text(GAME_CONFIG.width / 2, 100, info, {
      ...FONTS.default,
      fontSize: '15px',
      color: '#ecf0f1',
      align: 'center',
    }).setOrigin(0.5)
  }

  createButtons() {
    this.restBtn = this.createButton(GAME_CONFIG.width / 2, 200, 'Rest (heal 40% HP)', () => this.onRest(), 0x27ae60)
    this.upgradeBtn = this.createButton(GAME_CONFIG.width / 2, 270, 'Sharpen Weapon', () => this.onUpgradeWeapon(), 0x2980b9)
    this.leaveBtn = this.createButton(GAME_CONFIG.width / 2, 360, 'Leave', () => this.completeTile(), 0x7f8c8d)
    this.updateButtonStates()
  }

  createButton(x, y, label, onClick, color = 0x2980b9) {
    const container = this.add.container(x, y)
    const bg = this.add.rectangle(0, 0, 220, 44, color).setInteractive({ useHandCursor: true }).setOrigin(0.5)
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
    this.setButtonEnabled(this.restBtn, this.player.hp < this.player.maxHp)
    this.setButtonEnabled(this.upgradeBtn, this.canUpgradeWeapon())
  }

  canUpgradeWeapon() {
    const w = this.player.weapon
    if (!w) return false
    if (w.level >= w.maxLevel) return false
    return (this.player.loadout.gold || 0) >= getUpgradeCost(w.level)
  }

  setButtonEnabled(btn, enabled) {
    btn.bg.input.enabled = enabled
    btn.bg.setFillStyle(enabled ? btn.color : 0x555555)
    btn.text.setColor(enabled ? '#ffffff' : '#aaaaaa')
  }

  onRest() {
    const heal = Math.floor(this.player.maxHp * 0.4)
    this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal)
    this.player.saveLoadout()
    this.showToast(`Recovered ${heal} HP`)
    this.updateInfo()
    this.time.delayedCall(800, () => this.completeTile())
  }

  onUpgradeWeapon() {
    const result = this.player.upgradeWeapon()
    if (result.ok) {
      this.showToast(`Weapon upgraded to +${result.level}!`)
    } else {
      this.showToast(result.reason)
    }
    this.goldText.setText(`Gold: ${this.player.loadout.gold || 0}`)
    this.updateInfo()
    this.updateButtonStates()
  }

  updateInfo() {
    const w = this.player.weapon
    const cost = w && w.level < w.maxLevel ? getUpgradeCost(w.level) : 'MAX'
    this.infoText.setText([
      `HP: ${this.player.hp}/${this.player.maxHp}`,
      `${w?.name || 'Weapon'} +${w?.level || 0} · Upgrade: ${cost}G`,
    ].join('\n'))
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
