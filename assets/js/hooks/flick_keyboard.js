const flickKeys = {
  "あ": {
    center: "あ", up: "い", right: "う", down: "え", left: "お",
    small: { center: "ぁ", up: "ぃ", right: "ぅ", down: "ぇ", left: "ぉ" }
  },
  "か": {
    center: "か", up: "き", right: "く", down: "け", left: "こ",
    dakuten: { center: "が", up: "ぎ", right: "ぐ", down: "げ", left: "ご" }
  },
  "さ": {
    center: "さ", up: "し", right: "す", down: "せ", left: "そ",
    dakuten: { center: "ざ", up: "じ", right: "ず", down: "ぜ", left: "ぞ" }
  },
  "た": {
    center: "た", up: "ち", right: "つ", down: "て", left: "と",
    dakuten: { center: "だ", up: "ぢ", right: "づ", down: "で", left: "ど" }
  },
  "な": {
    center: "な", up: "に", right: "ぬ", down: "ね", left: "の"
  },
  "は": {
    center: "は", up: "ひ", right: "ふ", down: "へ", left: "ほ",
    dakuten: { center: "ば", up: "び", right: "ぶ", down: "べ", left: "ぼ" },
    handakuten: { center: "ぱ", up: "ぴ", right: "ぷ", down: "ぺ", left: "ぽ" }
  },
  "ま": {
    center: "ま", up: "み", right: "む", down: "め", left: "も"
  },
  "や": {
    center: "や", up: "ゆ", right: "よ", down: "ゃ", left: "ゅ"
  },
  "ら": {
    center: "ら", up: "り", right: "る", down: "れ", left: "ろ"
  },
  "わ": {
    center: "わ", up: "を", right: "ん", down: "っ", left: "ょ"
  },
}

const FlickKeyboard = {
  mounted() {
    this.keys = this.el.querySelectorAll("[data-flick-base]")
    this.modifiers = { dakuten: false, handakuten: false, small: false }
    this.activeKey = null
    this.selectedValue = null
    this.popup = null

    this.keys.forEach((key) => {
      key.addEventListener("pointerdown", (e) => this.onPointerDown(e, key))
    })

    this.onPointerUp = this.onPointerUp.bind(this)
    this.onPointerMove = this.onPointerMove.bind(this)
    document.addEventListener("pointerup", this.onPointerUp)
    document.addEventListener("pointermove", this.onPointerMove)

    // Modifier buttons
    this.el.querySelectorAll("[data-modifier]").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation()
        const mod = btn.dataset.modifier
        if (mod === "dakuten" || mod === "handakuten" || mod === "small") {
          this.toggleModifier(mod)
        } else if (mod === "backspace") {
          this.pushEvent("key_pressed", { key: "Backspace" })
        } else if (mod === "enter") {
          this.pushEvent("key_pressed", { key: "Enter" })
        }
      })
    })
  },

  toggleModifier(mod) {
    // handakuten and dakuten are mutually exclusive
    if (mod === "dakuten" && this.modifiers.handakuten) {
      this.modifiers.handakuten = false
    }
    if (mod === "handakuten" && this.modifiers.dakuten) {
      this.modifiers.dakuten = false
    }
    this.modifiers[mod] = !this.modifiers[mod]
    this.updateModifierVisuals()
  },

  updateModifierVisuals() {
    this.el.querySelectorAll("[data-modifier]").forEach((btn) => {
      const mod = btn.dataset.modifier
      if (this.modifiers[mod]) {
        btn.classList.add("flick-modifier-active")
      } else {
        btn.classList.remove("flick-modifier-active")
      }
    })
  },

  resolveChar(base, direction) {
    const keyData = flickKeys[base]
    if (!keyData) return null

    let charMap = keyData
    if (this.modifiers.small && keyData.small) {
      charMap = keyData.small
    } else if (this.modifiers.handakuten && keyData.handakuten) {
      charMap = keyData.handakuten
    } else if (this.modifiers.dakuten && keyData.dakuten) {
      charMap = keyData.dakuten
    }

    return charMap[direction] || charMap.center || null
  },

  onPointerDown(e, key) {
    e.preventDefault()
    this.activeKey = key
    const rect = key.getBoundingClientRect()
    this.startX = rect.left + rect.width / 2
    this.startY = rect.top + rect.height / 2
    const base = key.dataset.flickBase
    this.selectedValue = this.resolveChar(base, "center")
    this.showPopup(rect, base)
  },

  onPointerMove(e) {
    if (!this.activeKey) return

    const dx = e.clientX - this.startX
    const dy = e.clientY - this.startY
    const dist = Math.sqrt(dx * dx + dy * dy)

    if (dist < 12) {
      const base = this.activeKey.dataset.flickBase
      this.selectedValue = this.resolveChar(base, "center")
      this.highlightVariant(null)
      return
    }

    const angle = Math.atan2(dy, dx)
    let direction
    if (angle >= -Math.PI / 4 && angle < Math.PI / 4) {
      direction = "right"
    } else if (angle >= Math.PI / 4 && angle < (3 * Math.PI) / 4) {
      direction = "down"
    } else if (angle >= (3 * Math.PI) / 4 || angle < (-3 * Math.PI) / 4) {
      direction = "left"
    } else {
      direction = "up"
    }

    const base = this.activeKey.dataset.flickBase
    this.selectedValue = this.resolveChar(base, direction)
    this.highlightVariant(direction)
  },

  onPointerUp(e) {
    if (!this.activeKey) return

    if (this.selectedValue) {
      this.pushEvent("key_pressed", { key: this.selectedValue })
    }
    this.hidePopup()
    this.activeKey = null
  },

  showPopup(rect, base) {
    if (this.popup) this.popup.remove()

    const keyData = flickKeys[base]
    if (!keyData) return

    let charMap = keyData
    if (this.modifiers.small && keyData.small) {
      charMap = keyData.small
    } else if (this.modifiers.handakuten && keyData.handakuten) {
      charMap = keyData.handakuten
    } else if (this.modifiers.dakuten && keyData.dakuten) {
      charMap = keyData.dakuten
    }

    const popupSize = 140
    const cellSize = popupSize / 3

    let popupLeft = rect.left + rect.width / 2 - popupSize / 2
    let popupTop = rect.top + rect.height / 2 - popupSize / 2

    // Keep popup within viewport
    popupLeft = Math.max(8, Math.min(popupLeft, window.innerWidth - popupSize - 8))
    popupTop = Math.max(8, Math.min(popupTop, window.innerHeight - popupSize - 8))

    this.popup = document.createElement("div")
    this.popup.className = "flick-popup"
    this.popup.style.cssText = `
      position: fixed;
      z-index: 100;
      pointer-events: none;
      width: ${popupSize}px;
      height: ${popupSize}px;
      left: ${popupLeft}px;
      top: ${popupTop}px;
    `

    const cells = [
      { pos: "up", x: 1, y: 0, char: charMap.up },
      { pos: "left", x: 0, y: 1, char: charMap.left },
      { pos: "center", x: 1, y: 1, char: charMap.center },
      { pos: "right", x: 2, y: 1, char: charMap.right },
      { pos: "down", x: 1, y: 2, char: charMap.down },
    ]

    cells.forEach((cell) => {
      if (!cell.char) return
      const el = document.createElement("div")
      el.className = `flick-popup-cell flick-popup-${cell.pos}`
      el.textContent = cell.char
      el.style.cssText = `
        position: absolute;
        width: ${cellSize - 4}px;
        height: ${cellSize - 4}px;
        left: ${cell.x * cellSize + 2}px;
        top: ${cell.y * cellSize + 2}px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(255,255,255,0.95);
        border-radius: 8px;
        font-size: 18px;
        font-weight: bold;
        color: #333;
        box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        border: 2px solid transparent;
      `
      el.dataset.direction = cell.pos
      this.popup.appendChild(el)
    })

    document.body.appendChild(this.popup)
  },

  hidePopup() {
    if (this.popup) {
      this.popup.remove()
      this.popup = null
    }
  },

  highlightVariant(direction) {
    if (!this.popup) return
    this.popup.querySelectorAll(".flick-popup-cell").forEach((el) => {
      if (el.dataset.direction === direction) {
        el.style.background = "#3b82f6"
        el.style.color = "#fff"
        el.style.borderColor = "#2563eb"
      } else {
        el.style.background = "rgba(255,255,255,0.95)"
        el.style.color = "#333"
        el.style.borderColor = "transparent"
      }
    })
  },

  destroyed() {
    document.removeEventListener("pointerup", this.onPointerUp)
    document.removeEventListener("pointermove", this.onPointerMove)
    this.hidePopup()
  },
}

export default FlickKeyboard
