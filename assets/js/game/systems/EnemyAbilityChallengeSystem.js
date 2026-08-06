import { GAME_CONFIG, COLORS, FONTS } from '../config.js'
import { lockGameWrapper, unlockGameWrapper } from './challengeKeyboardLock.js'
import { getWordChallengeTimeLimit } from './challengeTime.js'

function normalize(input) {
  return input.trim().toLowerCase()
}

export default class EnemyAbilityChallengeSystem {
  constructor(scene) {
    this.scene = scene
    this.overlay = null
    this.input = ''
    this.active = false
    this.timerEvent = null
    this.keyboardHandler = null
    this.startTime = 0
    this.timeLimit = 13000
    this.onComplete = null
    this.challenge = null
  }

  start(challenge, onComplete) {
    this.challenge = challenge
    this.onComplete = onComplete
    this.input = ''
    this.active = true
    this.timeLimit = getWordChallengeTimeLimit(this.scene, challenge.timeLimit || 13000)
    this.startTime = Date.now()

    // Enemy ability challenges are always word/meaning prompts.
    this.challenge.promptType = 'meaning'
    this.challenge.prompt = 'Type the meaning of this word:'

    this.createOverlay()

    if (this.scene.sys.game.device.input.touch) {
      this.createTouchKeyboard()
      lockGameWrapper()
    } else {
      this.createHiddenInput()
    }

    this.keyboardHandler = (event) => {
      if (!this.active) return
      const isTypingKey = event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey
      if (event.key === 'Enter' || event.key === 'Backspace' || isTypingKey) {
        event.preventDefault()
      }
      if (event.key === 'Enter') {
        this.submit(false)
      } else if (event.key === 'Backspace') {
        this.input = this.input.slice(0, -1)
      } else if (isTypingKey) {
        this.input += event.key.toLowerCase()
      }
      this.updateInputDisplay()
    }

    this.scene.input.keyboard.on('keydown', this.keyboardHandler)

    this.timerEvent = this.scene.time.addEvent({
      delay: 50,
      callback: () => this.updateTimer(),
      loop: true,
    })
  }

  createOverlay() {
    const cx = GAME_CONFIG.width / 2
    const cy = GAME_CONFIG.height / 2

    this.overlay = this.scene.add.container(cx, cy).setDepth(200)

    const backdrop = this.scene.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.75).setOrigin(0.5)
    this.overlay.add(backdrop)

    const panel = this.scene.add.rectangle(0, 0, 460, 340, COLORS.panelBg).setStrokeStyle(2, COLORS.warning).setOrigin(0.5)
    this.overlay.add(panel)

    const title = this.challenge.abilityName
      ? `${this.challenge.abilityName} Challenge`
      : 'Enemy Ability Challenge'
    this.titleText = this.scene.add.text(0, -120, title, { ...FONTS.title, fontSize: '20px', color: '#f39c12' }).setOrigin(0.5)
    this.overlay.add(this.titleText)

    const prompt = this.challenge.prompt || 'Answer quickly!'
    this.promptText = this.scene.add.text(0, -80, prompt, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.overlay.add(this.promptText)

    const displayValue = this.challenge.word?.word || ''
    this.targetText = this.scene.add.text(0, -30, displayValue, { ...FONTS.kanji, fontSize: '42px' }).setOrigin(0.5)
    this.overlay.add(this.targetText)

    this.hintText = this.scene.add.text(0, 25, this.challenge.hint || '', { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.overlay.add(this.hintText)

    this.inputText = this.scene.add.text(0, 55, '', { ...FONTS.default, fontSize: '22px', color: '#f1c40f' }).setOrigin(0.5)
    this.overlay.add(this.inputText)

    const barBg = this.scene.add.rectangle(0, 95, 320, 12, COLORS.hpBg).setOrigin(0.5)
    this.overlay.add(barBg)
    this.timerBar = this.scene.add.rectangle(-160, 95, 320, 12, COLORS.warning).setOrigin(0, 0.5)
    this.overlay.add(this.timerBar)

    this.timerText = this.scene.add.text(0, 115, `${(this.timeLimit / 1000).toFixed(1)}s`, { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.overlay.add(this.timerText)

    this.feedbackText = this.scene.add.text(0, 140, 'Press Enter to submit', { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.overlay.add(this.feedbackText)
  }

  createHiddenInput() {
    this.inputEl = document.createElement('input')
    this.inputEl.type = 'text'
    this.inputEl.style.position = 'fixed'
    this.inputEl.style.opacity = '0'
    this.inputEl.style.pointerEvents = 'none'
    this.inputEl.style.bottom = '0'
    this.inputEl.style.left = '0'
    this.inputEl.style.width = '1px'
    this.inputEl.style.height = '1px'
    this.inputEl.style.fontSize = '16px'
    this.inputEl.autocomplete = 'off'
    this.inputEl.autocorrect = 'off'
    this.inputEl.autocapitalize = 'off'
    this.inputEl.spellcheck = false
    document.body.appendChild(this.inputEl)
    this.inputEl.focus()
    lockGameWrapper()

    this.inputHandler = () => {
      this.input = this.inputEl.value.toLowerCase()
      this.updateInputDisplay()
    }
    this.inputEl.addEventListener('input', this.inputHandler)
  }

  updateInputDisplay() {
    if (this.inputText) {
      this.inputText.setText(this.input)
    }
  }

  createTouchKeyboard() {
    this.keyboardContainer = this.scene.add.container(0, 0)
    this.overlay.add(this.keyboardContainer)

    // Compact on-screen keyboard that fits below the 340px enemy-ability panel.
    const keySize = 26
    const keyGap = 3
    const startY = 162

    const rows = [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
    ]

    rows.forEach((row, rowIndex) => {
      const rowWidth = row.length * keySize + (row.length - 1) * keyGap
      const startX = -rowWidth / 2 + keySize / 2
      row.forEach((char, colIndex) => {
        const x = startX + colIndex * (keySize + keyGap)
        const y = startY + rowIndex * (keySize + keyGap)
        this.createKeyboardKey(char, x, y, keySize, keySize, char)
      })
    })

    // Control row: backspace, hyphen, space, enter
    const controlY = startY + rows.length * (keySize + keyGap) + 4
    const controls = [
      { label: '⌫', width: 42, key: 'BACKSPACE' },
      { label: '-', width: 26, key: '-' },
      { label: 'SPACE', width: 78, key: 'SPACE' },
      { label: '⏎', width: 42, key: 'ENTER' },
    ]
    const totalWidth = controls.reduce((sum, c) => sum + c.width, 0) + (controls.length - 1) * keyGap
    let x = -totalWidth / 2
    controls.forEach(({ label, width, key }) => {
      this.createKeyboardKey(label, x + width / 2, controlY, width, keySize, key)
      x += width + keyGap
    })
  }

  createKeyboardKey(label, x, y, width, height, keyName) {
    const bg = this.scene.add.rectangle(0, 0, width, height, 0x2c3e50).setStrokeStyle(1, 0x5d6d7e)
    const text = this.scene.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: label.length > 1 ? '12px' : '16px',
      color: '#ecf0f1',
    }).setOrigin(0.5)

    const container = this.scene.add.container(x, y, [bg, text])
    container.setSize(width, height)

    const hitArea = this.scene.add.rectangle(0, 0, width, height, 0x000000, 0)
    hitArea.setInteractive({ useHandCursor: true })
    container.add(hitArea)

    hitArea.on('pointerdown', () => {
      bg.setFillStyle(0x3498db)
      this.handleKeyboardKey(keyName)
    })
    hitArea.on('pointerup', () => bg.setFillStyle(0x2c3e50))
    hitArea.on('pointerout', () => bg.setFillStyle(0x2c3e50))

    this.keyboardContainer.add(container)
  }

  handleKeyboardKey(key) {
    if (!this.active) return
    if (key === 'BACKSPACE') {
      this.input = this.input.slice(0, -1)
    } else if (key === 'SPACE') {
      this.input += ' '
    } else if (key === 'ENTER') {
      this.submit(false)
      return
    } else {
      this.input += key.toLowerCase()
    }
    this.updateInputDisplay()
  }

  updateTimer() {
    if (!this.active || !this.timerBar) return
    const elapsed = Date.now() - this.startTime
    const remaining = Math.max(0, this.timeLimit - elapsed)
    const pct = this.timeLimit > 0 ? remaining / this.timeLimit : 0
    this.timerBar.setScale(pct, 1)
    if (this.timerText) {
      this.timerText.setText(`${(remaining / 1000).toFixed(1)}s`)
    }
    if (remaining <= 0) {
      this.submit(true)
    }
  }

  evaluate() {
    const word = this.challenge.word
    const input = normalize(this.input)
    const accepted = String(word.meaning || '')
      .split('/')
      .map(s => s.trim().toLowerCase())
      .filter(Boolean)
    return accepted.includes(input)
  }

  submit(timedOut = false) {
    if (!this.active) return

    const isCorrect = !timedOut && this.evaluate()
    this.active = false

    const correctAnswer = this.challenge.word?.meaning || ''

    if (isCorrect) {
      this.inputText.setColor('#2ecc71')
      this.feedbackText.setText('Correct! Ability weakened/cancelled.')
      this.feedbackText.setColor('#2ecc71')
    } else {
      this.inputText.setColor('#e74c3c')
      const baseMsg = timedOut ? "Time's up!" : 'Wrong!'
      this.feedbackText.setText(`${baseMsg} Answer: ${correctAnswer || '?'}`)
      this.feedbackText.setColor('#e74c3c')
    }

    this.removeHandlers()

    this.scene.time.delayedCall(1800, () => {
      this.destroy()
      if (this.onComplete) this.onComplete({ success: isCorrect, timedOut })
    })
  }

  removeHandlers() {
    if (this.timerEvent) {
      this.timerEvent.remove()
      this.timerEvent = null
    }
    if (this.keyboardHandler) {
      this.scene.input.keyboard.off('keydown', this.keyboardHandler)
      this.keyboardHandler = null
    }
    if (this.inputHandler && this.inputEl) {
      this.inputEl.removeEventListener('input', this.inputHandler)
      this.inputHandler = null
    }
    if (this.inputEl && this.inputEl.parentNode) {
      this.inputEl.parentNode.removeChild(this.inputEl)
      this.inputEl = null
    }
    unlockGameWrapper()
  }

  destroy() {
    this.removeHandlers()
    if (this.overlay) {
      this.overlay.destroy()
      this.overlay = null
    }
  }
}
