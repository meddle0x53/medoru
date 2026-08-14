import { GAME_CONFIG, FONTS } from '../config.js'
import { formatAbilityRequirements } from '../data/actions.js'

/**
 * Shared hover / long-press tooltip for ability/skill descriptions.
 *
 * - Desktop: hover with the pointer to show a tooltip near the cursor.
 * - Mobile/touch: hold for ~500 ms to show the tooltip; a short tap is left
 *   for the normal click action.
 *
 * When a long-press tooltip is shown, the helper sets
 * `abilityTooltipSuppressClick` on the game object so the caller's
 * `pointerup` handler can ignore the release and leave the tooltip open.
 */
export default class AbilityTooltip {
  constructor(scene) {
    this.scene = scene
    this.container = null
    this.hideListener = null
    this.longPressTimer = null
    this.width = 0
    this.height = 0
    this._worldPoint = { x: 0, y: 0 }
  }

  attach(gameObject, action) {
    if (!gameObject || !action) return

    gameObject.setData('abilityTooltipSuppressClick', false)
    gameObject.setData('abilityTooltipLongPress', false)

    gameObject.on('pointerover', (pointer) => {
      if (this.isTouch(pointer)) return
      this.show(action, pointer.x, pointer.y)
    })

    gameObject.on('pointerout', () => {
      if (!this.isTouch(this.scene.input.activePointer)) {
        this.hide()
      }
    })

    gameObject.on('pointermove', (pointer) => {
      if (this.container?.visible && !this.isTouch(pointer)) {
        this.setPosition(pointer.x, pointer.y)
      }
    })

    gameObject.on('pointerdown', (pointer) => {
      if (!this.isTouch(pointer)) return
      gameObject.setData('abilityTooltipLongPress', false)
      this.longPressTimer = this.scene.time.delayedCall(500, () => {
        gameObject.setData('abilityTooltipLongPress', true)
        gameObject.setData('abilityTooltipSuppressClick', true)
        this.show(action, pointer.x, pointer.y)
      })
    })

    gameObject.on('pointerup', () => {
      if (this.longPressTimer) {
        this.longPressTimer.remove()
        this.longPressTimer = null
      }
      gameObject.setData('abilityTooltipLongPress', false)
    })
  }

  isTouch(pointer) {
    if (!pointer) return false
    return pointer.pointerType === 'touch' || pointer.isTouch === true
  }

  show(action, x, y) {
    this.hide()

    const scene = this.scene
    const pad = 10
    const maxW = 260

    const container = scene.add.container(0, 0).setDepth(10000)

    const nameText = scene.add.text(pad, pad, action.name || '', {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ffffff',
      fontStyle: 'bold',
      wordWrap: { width: maxW - pad * 2 },
    })
    container.add(nameText)
    let nextY = pad + nameText.height + 4

    const subParts = [
      `${(action.type || 'ability').toUpperCase()}`,
      `${action.rarity || 'normal'}`,
    ]
    if (typeof action.staminaCost === 'number') {
      subParts.push(`${action.staminaCost} STA`)
    }
    const subText = scene.add.text(
      pad,
      nextY,
      subParts.join(' · '),
      { ...FONTS.default, fontSize: '10px', color: '#bdc3c7' }
    )
    container.add(subText)
    nextY += subText.height + 4

    const reqs = formatAbilityRequirements(action)
    if (reqs && reqs !== 'None') {
      const reqText = scene.add.text(pad, nextY, `Req: ${reqs}`, {
        ...FONTS.default,
        fontSize: '10px',
        color: '#95a5a6',
        wordWrap: { width: maxW - pad * 2 },
      })
      container.add(reqText)
      nextY += reqText.height + 6
    }

    if (action.description) {
      const descText = scene.add.text(pad, nextY, action.description, {
        ...FONTS.default,
        fontSize: '12px',
        color: '#ecf0f1',
        align: 'left',
        wordWrap: { width: maxW - pad * 2 },
      })
      container.add(descText)
      nextY += descText.height
    }

    const bgW = maxW
    const bgH = nextY + pad
    const bg = scene.add.rectangle(0, 0, bgW, bgH, 0x1a1a2e, 0.95).setOrigin(0)
    bg.setStrokeStyle(1, 0xf39c12)
    container.addAt(bg, 0)

    this.container = container
    this.width = bgW
    this.height = bgH
    this.setPosition(x, y)

    this.hideListener = () => this.hide()
    scene.input.once('pointerdown', this.hideListener)
  }

  setPosition(x, y) {
    if (!this.container) return

    // Pointer coordinates are in screen space; the high-DPI camera zooms and
    // scrolls the world, so convert to logical world coordinates before placing
    // a world-space UI element.
    const cam = this.scene.cameras.main
    const wp = cam.getWorldPoint(x, y, this._worldPoint)

    const margin = 6
    const offset = 8
    const maxX = GAME_CONFIG.width - this.width - margin
    const maxY = GAME_CONFIG.height - this.height - margin

    let cx = wp.x + offset
    let cy = wp.y + offset

    // Keep the tooltip inside the 960x540 logical canvas.
    if (cx > maxX) cx = wp.x - this.width - offset
    if (cy > maxY) cy = wp.y - this.height - offset
    cx = Math.max(margin, Math.min(cx, maxX))
    cy = Math.max(margin, Math.min(cy, maxY))

    this.container.setPosition(cx, cy)
  }

  hide() {
    if (this.hideListener) {
      this.scene.input.off('pointerdown', this.hideListener)
      this.hideListener = null
    }
    if (this.longPressTimer) {
      this.longPressTimer.remove()
      this.longPressTimer = null
    }
    if (this.container) {
      this.container.destroy()
      this.container = null
      this.width = 0
      this.height = 0
    }
  }
}
