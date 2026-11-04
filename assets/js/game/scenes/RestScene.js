import { GAME_CONFIG, FONTS } from '../config.js'
import Player, { getUpgradeCost, ROLL_PRICES } from '../entities/Player.js'
import { ALL_ACTIONS } from '../data/actions.js'
import { setupHighDPIWorld } from '../highDpi.js'

const ROLL_TIERS = ['common', 'uncommon', 'rare', 'epic']

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

  // Camp Comfort (knowledge upgrade): each owned stack grants +1 action per
  // rest site visit.
  campComfortCount() {
    return (this.player.loadout?.runUpgrades || [])
      .filter(u => (u.upgradeId || u.id) === 'camp_comfort').length
  }

  create() {
    setupHighDPIWorld(this)
    this.actionsUsed = 0
    this.actionsAllowed = 1 + this.campComfortCount()
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
    this.weaponBtn = this.createButton(GAME_CONFIG.width * 0.25, 220, 'Upgrade Weapon', () => this.onUpgradeWeapon(), 0x2980b9)
    this.shieldBtn = this.createButton(GAME_CONFIG.width * 0.75, 220, 'Upgrade Shield', () => this.onUpgradeShield(), 0x2980b9)
    this.restBtn = this.createButton(GAME_CONFIG.width / 2, 300, 'Rest (heal 40% HP)', () => this.onRest(), 0x27ae60)
    this.createRollButtons()
    this.forgetBtn = this.createButton(GAME_CONFIG.width / 2, 442, 'Forget Ability (uses action)', () => this.onForgetAbility(), 0xc0392b)
    this.createButton(GAME_CONFIG.width / 2, 496, 'Leave', () => this.completeTile(), 0x7f8c8d)
  }

  // Forget an ability (and all its upgrades) to open up the build. Free, but
  // consumes one of the visit's actions — same economy as resting/upgrading.
  onForgetAbility() {
    if (this.actionsExhausted()) {
      this.showToast('No actions left here.')
      return
    }
    this.openForgetOverlay()
  }

  openForgetOverlay() {
    this.closeForgetOverlay()
    const overlay = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2).setDepth(100)
    overlay.add(this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.7).setInteractive())
    overlay.add(this.add.rectangle(0, 0, 420, 360, 0x1a1a2e).setStrokeStyle(2, 0xc0392b))

    overlay.add(this.add.text(0, -160, 'Forget Ability (upgrades lost)', {
      ...FONTS.default, fontSize: '16px', color: '#e74c3c',
    }).setOrigin(0.5))
    overlay.add(this.add.text(0, -136, 'Free at the rest camp, but uses your action.', {
      ...FONTS.default, fontSize: '11px', color: '#95a5a6',
    }).setOrigin(0.5))

    const knownIds = this.player.loadout.knownActionIds || []
    const upgradesFor = id => (this.player.loadout.runUpgrades || [])
      .filter(u => u.effect?.abilityId === id || (u.type === 'unlock_ability' && u.effect?.abilityId === id)).length

    const rowH = 26
    const maxRows = 11
    knownIds.slice(0, maxRows).forEach((id, i) => {
      const action = ALL_ACTIONS.find(a => a.id === id)
      if (!action) return
      const lost = upgradesFor(id)
      const label = `${action.kanji || ''} ${action.name}${lost > 0 ? `  (-${lost} upgrade${lost > 1 ? 's' : ''})` : ''}`
      const rowBg = this.add.rectangle(0, -110 + i * rowH, 380, rowH - 4, 0x2c3e50)
        .setInteractive({ useHandCursor: true })
      const rowText = this.add.text(0, -110 + i * rowH, label, {
        ...FONTS.default, fontSize: '12px', color: '#ecf0f1',
      }).setOrigin(0.5)
      rowBg.on('pointerover', () => rowBg.setFillStyle(0xc0392b))
      rowBg.on('pointerout', () => rowBg.setFillStyle(0x2c3e50))
      rowBg.on('pointerdown', () => {
        const result = this.player.forgetAbility(id)
        if (!result.ok) {
          this.showToast(result.reason)
          return
        }
        this.closeForgetOverlay()
        this.showToast(`${action.name} forgotten${result.removedUpgrades > 0 ? ` (+${result.removedUpgrades} upgrades lost)` : ''}.`)
        this.consumeAction()
      })
      overlay.add([rowBg, rowText])
    })
    if (knownIds.length > maxRows) {
      overlay.add(this.add.text(0, -110 + maxRows * rowH, `…and ${knownIds.length - maxRows} more`, {
        ...FONTS.default, fontSize: '11px', color: '#7f8c8d',
      }).setOrigin(0.5))
    }

    const closeBtn = this.add.rectangle(0, 158, 120, 30, 0x7f8c8d).setInteractive({ useHandCursor: true })
    const closeText = this.add.text(0, 158, 'Close', { ...FONTS.default, fontSize: '13px', color: '#ffffff' }).setOrigin(0.5)
    closeBtn.on('pointerdown', () => this.closeForgetOverlay())
    overlay.add([closeBtn, closeText])

    this.forgetOverlay = overlay
  }

  closeForgetOverlay() {
    if (this.forgetOverlay) {
      this.forgetOverlay.destroy()
      this.forgetOverlay = null
    }
  }

  // Gold-bought rolls share the inventory with scales-bought rolls. Buying
  // one consumes one of the visit's actions, exactly like resting or
  // upgrading equipment (actions-per-visit rule, +1 per Camp Comfort).
  createRollButtons() {
    this.add.text(GAME_CONFIG.width / 2, 348, 'Buy a roll (uses one action):', {
      ...FONTS.default,
      fontSize: '13px',
      color: '#95a5a6',
    }).setOrigin(0.5)

    this.rollBtns = ROLL_TIERS.map((tier, i) => {
      const owned = this.player.loadout.rollInventory?.[tier] || 0
      const price = ROLL_PRICES.gold[tier]
      const x = GAME_CONFIG.width / 2 + (i - 1.5) * 140
      const btn = this.createButton(x, 385, `${tier} ×${owned}\n${price}G`, () => this.onBuyRoll(tier), 0x8e44ad)
      btn.tier = tier
      return btn
    })
  }

  onBuyRoll(tier) {
    if (this.actionsUsed >= this.actionsAllowed) {
      this.showToast('No actions left here.')
      return
    }
    const result = this.player.buyRoll(tier, 'gold')
    if (!result.ok) {
      this.showToast(result.reason)
      return
    }
    // Buying only stores the roll (D12/Alt 2); it is triggered later from
    // the Prepare/Loadout roll chips.
    this.showToast(`${tier[0].toUpperCase()}${tier.slice(1)} Roll acquired! Trigger it from Prepare whenever you want your cards.`)
    this.goldText.setText(`Gold: ${this.player.loadout.gold || 0}`)
    const btn = (this.rollBtns || []).find(b => b.tier === tier)
    if (btn) btn.text.setText(`${tier} ×${this.player.loadout.rollInventory?.[tier] || 0}\n${ROLL_PRICES.gold[tier]}G`)
    this.consumeAction()
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

  // Spends one of the visit's actions; when they run out, the action buttons
  // grey out. Leave stays available so the player can exit early.
  consumeAction() {
    this.actionsUsed++
    if (this.actionsUsed < this.actionsAllowed) return
    ;[this.restBtn, this.weaponBtn, this.shieldBtn, this.forgetBtn, ...(this.rollBtns || [])].forEach((btn) => {
      if (!btn) return
      btn.bg.removeInteractive()
      btn.bg.setFillStyle(0x555555)
    })
  }

  actionsExhausted() {
    return this.actionsUsed >= this.actionsAllowed
  }

  onRest() {
    if (this.actionsExhausted()) {
      this.showToast('No actions left here.')
      return
    }
    if (this.player.hp >= this.player.maxHp) {
      this.showToast('You are already fully rested.')
      return
    }
    const heal = Math.floor(this.player.maxHp * 0.4)
    this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal)
    this.player.saveLoadout()
    this.showToast(`Recovered ${heal} HP`)
    this.updateInfo()
    this.consumeAction()
    // Auto-continue to the map only when the rest consumed the last action.
    if (this.actionsExhausted()) {
      this.time.delayedCall(800, () => this.completeTile())
    }
  }

  onUpgradeWeapon() {
    this.tryUpgrade(this.player.weapon, 'baseDamage')
  }

  onUpgradeShield() {
    this.tryUpgrade(this.player.shield, 'baseDefense')
  }

  tryUpgrade(item, baseStatKey) {
    if (this.actionsExhausted()) {
      this.showToast('No actions left here.')
      return
    }
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
      this.consumeAction()
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
