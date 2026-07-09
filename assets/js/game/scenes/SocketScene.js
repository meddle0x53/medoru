import { GAME_CONFIG, FONTS } from '../config.js'
import { getSocketCharmById, getSocketCharmsForSlot } from '../data/socketCharms.js'
import { setupHighDPIWorld } from '../highDpi.js'

const SLOT_RADIUS = 22
const SLOT_GAP = 56

/**
 * Socket management scene — equip/unequip socket charms on weapon and shield.
 */
export default class SocketScene extends Phaser.Scene {
  constructor() {
    super({ key: 'SocketScene' })
  }

  init(data) {
    this.player = data.player
    this.returnScene = data.returnScene || 'LoadoutScene'
    this.picker = null
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()
    this.createHeader()
    this.createEquipmentSection(120, this.player.weapon, 'primary_weapon')
    this.createEquipmentSection(320, this.player.shield, 'secondary_weapon')
    this.createLeaveButton()
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createHeader() {
    this.add.text(GAME_CONFIG.width / 2, 28, 'Socket Charms', {
      ...FONTS.title,
      fontSize: '28px',
      color: '#f39c12',
    }).setOrigin(0.5)
  }

  createEquipmentSection(y, equipment, type) {
    const title = equipment ? `${equipment.name} +${equipment.level || 0}` : 'None'
    this.add.text(GAME_CONFIG.width / 2, y, title, {
      ...FONTS.default,
      fontSize: '18px',
      color: '#ecf0f1',
      fontStyle: 'bold',
    }).setOrigin(0.5)

    const scaling = this.player.getEquipmentScaling(equipment)
    const scalingText = Object.entries(scaling)
      .map(([stat, grade]) => `${stat.toUpperCase()} ${grade}`)
      .join(' · ') || '—'
    this.add.text(GAME_CONFIG.width / 2, y + 26, scalingText, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#bdc3c7',
    }).setOrigin(0.5)

    const maxSlots = type === 'primary_weapon'
      ? this.player.getWeaponCharmSlots()
      : this.player.getShieldCharmSlots()
    const totalW = 4 * SLOT_RADIUS * 2 + (4 - 1) * SLOT_GAP
    const startX = (GAME_CONFIG.width - totalW) / 2 + SLOT_RADIUS

    for (let i = 0; i < 4; i++) {
      const x = startX + i * (SLOT_RADIUS * 2 + SLOT_GAP)
      this.createSocketSlot(x, y + 70, equipment, type, i, i < maxSlots)
    }
  }

  createSocketSlot(x, y, equipment, type, index, unlocked) {
    const container = this.add.container(x, y)

    const bg = this.add.circle(0, 0, SLOT_RADIUS, unlocked ? 0x2c3e50 : 0x1a1a1a)
      .setStrokeStyle(2, unlocked ? 0x3498db : 0x555555)
    container.add(bg)

    const charmId = equipment?.socketCharmIds?.[index]
    const charm = charmId ? getSocketCharmById(charmId) : null

    if (charm) {
      const colorHex = '#' + charm.color.toString(16).padStart(6, '0')
      const icon = this.add.text(0, 0, charm.kanji, {
        fontFamily: FONTS.kanji.fontFamily,
        fontSize: '18px',
        color: '#ffffff',
        stroke: colorHex,
        strokeThickness: 2,
      }).setOrigin(0.5)
      container.add(icon)
    } else if (!unlocked) {
      container.add(this.add.text(0, 0, '🔒', { fontSize: '14px' }).setOrigin(0.5))
    } else {
      container.add(this.add.text(0, 0, '+', { fontSize: '18px', color: '#7f8c8d' }).setOrigin(0.5))
    }

    if (unlocked) {
      const hitArea = this.add.circle(0, 0, SLOT_RADIUS + 6, 0x000000, 0)
        .setInteractive({ useHandCursor: true })
      hitArea.on('pointerdown', () => this.onSocketClick(equipment, type, index, charm))
      container.add(hitArea)
    }
  }

  onSocketClick(equipment, type, index, currentCharm) {
    if (currentCharm) {
      this.player.unequipSocketCharm(equipment, index)
      this.scene.start('SocketScene', { player: this.player, returnScene: this.returnScene })
      return
    }
    this.openPicker(equipment, type, index)
  }

  openPicker(equipment, type, index) {
    if (this.picker) this.picker.destroy()

    const options = (this.player.loadout.ownedSocketCharmIds || [])
      .map((id) => getSocketCharmById(id))
      .filter((charm) => charm && charm.equipmentType === type && charm.slot === index + 1)

    if (options.length === 0) {
      this.showToast('No socket charms available for this slot.')
      return
    }

    const picker = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    picker.setDepth(200)
    picker.add(this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.85).setOrigin(0.5))
    picker.add(this.add.rectangle(0, 0, 440, 360, 0x1a1a2e).setStrokeStyle(2, 0xf39c12).setOrigin(0.5))
    picker.add(this.add.text(0, -140, 'Choose a charm', { ...FONTS.title, fontSize: '18px', color: '#f39c12' }).setOrigin(0.5))

    options.forEach((charm, i) => {
      const y = -80 + i * 60
      const row = this.add.container(0, y)
      const bg = this.add.rectangle(0, 0, 360, 50, 0x2c3e50).setInteractive({ useHandCursor: true }).setOrigin(0.5)
      const colorHex = '#' + charm.color.toString(16).padStart(6, '0')
      const icon = this.add.text(-150, 0, charm.kanji, { fontFamily: FONTS.kanji.fontFamily, fontSize: '20px', color: colorHex }).setOrigin(0.5)
      const name = this.add.text(-110, -8, charm.name, { ...FONTS.default, fontSize: '14px', color: '#ecf0f1' }).setOrigin(0, 0)
      const desc = this.add.text(-110, 10, charm.description, { ...FONTS.default, fontSize: '11px', color: '#bdc3c7', wordWrap: { width: 300 } }).setOrigin(0, 0)
      row.add([bg, icon, name, desc])
      picker.add(row)

      bg.on('pointerdown', () => {
        this.player.equipSocketCharm(equipment, index, charm.id)
        this.picker.destroy()
        this.picker = null
        this.scene.start('SocketScene', { player: this.player, returnScene: this.returnScene })
      })
      bg.on('pointerover', () => bg.setFillStyle(0x34495e))
      bg.on('pointerout', () => bg.setFillStyle(0x2c3e50))
    })

    const closeBtn = this.createButton(0, 140, 'Close', () => {
      this.picker.destroy()
      this.picker = null
    }, 0x7f8c8d)
    picker.add(closeBtn.container)

    this.picker = picker
  }

  createLeaveButton() {
    const btn = this.createButton(GAME_CONFIG.width / 2, GAME_CONFIG.height - 40, 'Back', () => {
      this.scene.start(this.returnScene, { player: this.player })
    }, 0x7f8c8d)
  }

  createButton(x, y, label, onClick, color = 0x2980b9) {
    const container = this.add.container(x, y)
    const bg = this.add.rectangle(0, 0, 160, 40, color).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(0, 0, label, { ...FONTS.default, fontSize: '16px', color: '#ffffff', fontStyle: 'bold' }).setOrigin(0.5)
    container.add([bg, text])
    bg.on('pointerdown', onClick)
    bg.on('pointerover', () => bg.setFillStyle(lighten(color)))
    bg.on('pointerout', () => bg.setFillStyle(color))
    return { container, bg, text }
  }

  showToast(message) {
    if (this.toast) this.toast.destroy()
    this.toast = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 120)
    const bg = this.add.rectangle(0, 0, 320, 36, 0x000000, 0.85).setStrokeStyle(1, 0xf39c12).setOrigin(0.5)
    const text = this.add.text(0, 0, message, { ...FONTS.default, fontSize: '13px', color: '#f39c12' }).setOrigin(0.5)
    this.toast.add([bg, text])
    this.time.delayedCall(1500, () => {
      if (this.toast) {
        this.toast.destroy()
        this.toast = null
      }
    })
  }
}

function lighten(color) {
  const r = (color >> 16) & 0xff
  const g = (color >> 8) & 0xff
  const b = color & 0xff
  const clamp = (v) => Math.min(255, Math.floor(v * 1.15))
  return (clamp(r) << 16) | (clamp(g) << 8) | clamp(b)
}
