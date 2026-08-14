import { GAME_CONFIG, FONTS } from '../config.js'
import Player, { getUpgradeCost } from '../entities/Player.js'
import { setupHighDPIWorld } from '../highDpi.js'

/**
 * Rest Camp scene — recover HP or spend gold to upgrade one piece of equipment.
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
    setupHighDPIWorld(this)
    this.actionTaken = false
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
    this.hpText = this.add.text(GAME_CONFIG.width / 2, 80, `HP: ${this.player.hp}/${this.player.maxHp}`, {
      ...FONTS.default,
      fontSize: '16px',
      color: '#ecf0f1',
      align: 'center',
    }).setOrigin(0.5)

    this.weaponInfoText = this.add.text(GAME_CONFIG.width * 0.25, 150, this.buildWeaponInfoText(), {
      ...FONTS.default,
      fontSize: '15px',
      color: '#ecf0f1',
      align: 'center',
    }).setOrigin(0.5)

    this.shieldInfoText = this.add.text(GAME_CONFIG.width * 0.75, 150, this.buildShieldInfoText(), {
      ...FONTS.default,
      fontSize: '15px',
      color: '#ecf0f1',
      align: 'center',
    }).setOrigin(0.5)
  }

  buildWeaponInfoText() {
    const w = this.player.weapon
    const cost = w && w.level < w.maxLevel ? getUpgradeCost(w.level) : 'MAX'
    return `${w?.name || 'Weapon'} +${w?.level || 0}\nUpgrade: ${cost}G`
  }

  buildShieldInfoText() {
    const s = this.player.shield
    const cost = s && s.level < s.maxLevel ? getUpgradeCost(s.level) : 'MAX'
    return `${s?.name || 'Shield'} +${s?.level || 0}\nUpgrade: ${cost}G`
  }

  createButtons() {
    this.weaponBtn = this.createButton(GAME_CONFIG.width * 0.25, 230, 'Upgrade Weapon', () => this.onUpgradeWeapon(), 0x2980b9)
    this.shieldBtn = this.createButton(GAME_CONFIG.width * 0.75, 230, 'Upgrade Shield', () => this.onUpgradeShield(), 0x2980b9)
    this.restBtn = this.createButton(GAME_CONFIG.width / 2, 320, 'Rest (heal 40% HP)', () => this.onRest(), 0x27ae60)
    this.createButton(GAME_CONFIG.width / 2, 400, 'Leave', () => this.completeTile(), 0x7f8c8d)
  }

  createButton(x, y, label, onClick, color = 0x2980b9) {
    const container = this.add.container(x, y)
    const bg = this.add.rectangle(0, 0, 220, 40, color).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: '15px',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5)
    container.add([bg, text])

    const hover = () => bg.setFillStyle(lighten(color))
    const out = () => bg.setFillStyle(color)
    bg.on('pointerdown', onClick)
    bg.on('pointerover', hover)
    bg.on('pointerout', out)

    return { bg, text, color, hover, out }
  }

  disableActionButtons() {
    if (this.actionTaken) return
    this.actionTaken = true
    ;[this.restBtn, this.weaponBtn, this.shieldBtn].forEach((btn) => {
      if (!btn) return
      btn.bg.removeInteractive()
      btn.bg.setFillStyle(0x555555)
    })
  }

  onRest() {
    if (this.player.hp >= this.player.maxHp) {
      this.showToast('You are already fully rested.')
      return
    }
    const heal = Math.floor(this.player.maxHp * 0.4)
    this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal)
    this.player.saveLoadout()
    this.showToast(`Recovered ${heal} HP`)
    this.updateInfo()
    this.disableActionButtons()
    this.time.delayedCall(800, () => this.completeTile())
  }

  onUpgradeWeapon() {
    this.tryUpgrade(this.player.weapon, 'baseDamage')
  }

  onUpgradeShield() {
    this.tryUpgrade(this.player.shield, 'baseDefense')
  }

  tryUpgrade(item, baseStatKey) {
    if (!item) {
      this.showToast('No equipment.')
      return
    }
    if (item.level >= item.maxLevel) {
      this.showToast('Already at max level.')
      return
    }
    const cost = getUpgradeCost(item.level)
    if ((this.player.loadout.gold || 0) < cost) {
      this.showToast(`Need ${cost} gold.`)
      return
    }
    const method = baseStatKey === 'baseDamage' ? 'upgradeWeapon' : 'upgradeShield'
    const result = this.player[method]()
    if (result.ok) {
      this.showToast(`${item.name} upgraded to +${result.level}!`)
      this.goldText.setText(`Gold: ${this.player.loadout.gold || 0}`)
      this.updateInfo()
      this.disableActionButtons()
    } else {
      this.showToast(result.reason)
    }
  }

  updateInfo() {
    this.hpText.setText(`HP: ${this.player.hp}/${this.player.maxHp}`)
    this.weaponInfoText.setText(this.buildWeaponInfoText())
    this.shieldInfoText.setText(this.buildShieldInfoText())
  }

  showToast(message) {
    if (this.toast) this.toast.destroy()
    this.toast = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 100)
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
