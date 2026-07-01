import { GAME_CONFIG, COLORS, FONTS } from '../config.js'

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
    this.timeLimit = 5000
    this.onComplete = null
    this.challenge = null
  }

  start(challenge, onComplete) {
    this.challenge = challenge
    this.onComplete = onComplete
    this.input = ''
    this.active = true
    this.timeLimit = challenge.timeLimit || 5000
    this.startTime = Date.now()

    // Enemy ability challenges are always word/meaning prompts.
    this.challenge.promptType = 'meaning'
    this.challenge.prompt = 'Type the meaning of this word:'

    this.createOverlay()
    this.createHiddenInput()

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
        this.input += event.key
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
    document.body.appendChild(this.inputEl)
    this.inputEl.focus()

    this.inputHandler = () => {
      this.input = this.inputEl.value
      this.updateInputDisplay()
    }
    this.inputEl.addEventListener('input', this.inputHandler)
  }

  updateInputDisplay() {
    if (this.inputText) {
      this.inputText.setText(this.input)
    }
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
  }

  destroy() {
    this.removeHandlers()
    if (this.overlay) {
      this.overlay.destroy()
      this.overlay = null
    }
  }
}
