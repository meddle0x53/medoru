import { COLORS, FONTS, GAME_CONFIG } from '../config.js'
import { getAcceptedReadings, normalizeReadingInput } from './kanaUtils.js'
import { evaluateMeaningAnswer } from './wordChallengeUtils.js'
import { lockGameWrapper, unlockGameWrapper } from './challengeKeyboardLock.js'
import { getWordChallengeTimeLimit } from './challengeTime.js'

/**
 * Reusable word challenge component used by every scene.
 *
 * Supports reading or meaning prompts, a countdown timer bar,
 * latin/kana answer acceptance, and a configurable hang on wrong answers.
 *
 * Usage:
 *   const challenge = new WordChallengeSystem(scene, { title: '...', timeLimit: 10000 })
 *   challenge.start(wordData, {
 *     promptType: 'meaning',
 *     onStart: () => { ... },
 *     onResult: ({ success, timedOut, word, input, correctAnswer }) => { ... },
 *     onComplete: ({ success, timedOut, word }) => { ... },
 *   })
 */
export default class WordChallengeSystem {
  constructor(scene, options = {}) {
    this.scene = scene
    this.options = {
      title: 'Word Challenge',
      promptForReading: 'Type the reading of this word (latin or kana):',
      promptForMeaning: 'Type the meaning of this word:',
      timeLimit: 13000,
      hangOnWrong: 5000,
      hangOnCorrect: 0,
      showCorrectAnswer: true,
      ...options,
    }

    this.overlay = null
    this.titleText = null
    this.promptText = null
    this.wordText = null
    this.hintText = null
    this.inputText = null
    this.feedbackText = null
    this.answerText = null
    this.timerBar = null
    this.timerText = null

    this.inputEl = null
    this.keyboardHandler = null
    this.timerEvent = null
    this.hangEvent = null
    this.keyboardContainer = null

    this.word = null
    this.input = ''
    this.startTime = 0
    this.active = false
    this.currentOptions = null
  }

  isActive() {
    return this.active
  }

  destroy() {
    this.hide()
  }

  start(word, options = {}) {
    this.word = word
    this.input = ''
    this.startTime = Date.now()
    this.active = true
    this.currentOptions = {
      promptType: 'meaning',
      timeLimit: this.options.timeLimit,
      hangOnWrong: this.options.hangOnWrong,
      hangOnCorrect: this.options.hangOnCorrect,
      showCorrectAnswer: this.options.showCorrectAnswer,
      onStart: null,
      onResult: null,
      onComplete: null,
      ...options,
    }
    // For now every word challenge asks for meaning.
    this.currentOptions.promptType = 'meaning'

    // Give touch players more time to type on the on-screen keyboard.
    this.currentOptions.timeLimit = getWordChallengeTimeLimit(this.scene, this.currentOptions.timeLimit)

    this.createOverlay()

    if (this.scene.sys.game.device.input.touch) {
      this.createTouchKeyboard()
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

    if (this.currentOptions.onStart) {
      this.currentOptions.onStart({ word: this.word })
    }
  }

  updateTimer() {
    if (!this.overlay || !this.word || this.hangEvent || !this.active) return
    const elapsed = Date.now() - this.startTime
    const remaining = Math.max(0, this.currentOptions.timeLimit - elapsed)
    const pct = this.currentOptions.timeLimit > 0 ? remaining / this.currentOptions.timeLimit : 0
    if (this.timerBar) {
      this.timerBar.setScale(pct, 1)
    }
    if (this.timerText) {
      this.timerText.setText(`${(remaining / 1000).toFixed(1)}s`)
    }
    if (remaining <= 0) {
      this.submit(true)
    }
  }

  createOverlay() {
    const cx = GAME_CONFIG.width / 2
    const cy = GAME_CONFIG.height / 2

    this.overlay = this.scene.add.container(cx, cy).setDepth(200)

    const backdrop = this.scene.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.75).setOrigin(0.5)
    this.overlay.add(backdrop)

    const panel = this.scene.add.rectangle(0, 0, 460, 300, COLORS.panelBg).setStrokeStyle(2, COLORS.warning).setOrigin(0.5)
    this.overlay.add(panel)

    this.titleText = this.scene.add.text(0, -130, this.options.title, { ...FONTS.title, fontSize: '20px', color: '#f39c12' }).setOrigin(0.5)
    this.overlay.add(this.titleText)

    const prompt = this.currentOptions.promptType === 'meaning'
      ? this.options.promptForMeaning
      : this.options.promptForReading
    this.promptText = this.scene.add.text(0, -95, prompt, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.overlay.add(this.promptText)

    this.wordText = this.scene.add.text(0, -45, this.word.word, { ...FONTS.kanji, fontSize: '42px' }).setOrigin(0.5)
    this.overlay.add(this.wordText)

    this.hintText = this.scene.add.text(0, 0, this.word.reading || '', { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.overlay.add(this.hintText)

    this.inputText = this.scene.add.text(0, 30, '', { ...FONTS.default, fontSize: '22px', color: '#f1c40f' }).setOrigin(0.5)
    this.overlay.add(this.inputText)

    const barBg = this.scene.add.rectangle(0, 70, 320, 12, COLORS.hpBg).setOrigin(0.5)
    this.overlay.add(barBg)
    this.timerBar = this.scene.add.rectangle(-160, 70, 320, 12, COLORS.warning).setOrigin(0, 0.5)
    this.overlay.add(this.timerBar)

    this.timerText = this.scene.add.text(0, 88, `${(this.currentOptions.timeLimit / 1000).toFixed(1)}s`, { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.overlay.add(this.timerText)

    const feedbackLabel = this.scene.sys.game.device.input.touch
      ? 'Tap the keys below to type'
      : 'Press Enter to submit'
    this.feedbackText = this.scene.add.text(0, 108, feedbackLabel, { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.overlay.add(this.feedbackText)

    this.answerText = this.scene.add.text(0, 132, '', { ...FONTS.default, fontSize: '14px', color: '#2ecc71', align: 'center', wordWrap: { width: 420 } }).setOrigin(0.5)
    this.overlay.add(this.answerText)
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

    // Smaller keys so the full keyboard (including Enter) fits on 540px screens.
    const keySize = 26
    const keyGap = 3
    const startY = 166

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
    if (this.inputEl) this.inputEl.value = this.input
    this.updateInputDisplay()
  }

  submit(timedOut = false) {
    if (!this.word || this.hangEvent || !this.active) return

    let isCorrect = false
    if (!timedOut) {
      if (this.currentOptions.promptType === 'meaning') {
        isCorrect = evaluateMeaningAnswer(this.word, this.input)
      } else {
        const accepted = getAcceptedReadings(this.word)
        const normalized = normalizeReadingInput(this.input)
        isCorrect = accepted.includes(normalized)
      }
    }
    const correctAnswer = this.currentOptions.promptType === 'meaning'
      ? (this.word.meaning || '')
      : (this.word.reading || '')

    if (isCorrect) {
      this.inputText.setColor('#2ecc71')
      if (this.feedbackText) {
        this.feedbackText.setText('Correct!')
        this.feedbackText.setColor('#2ecc71')
      }
      if (this.answerText && this.currentOptions.showCorrectAnswer !== false) {
        this.answerText.setText(`Answer: ${correctAnswer}`)
        this.answerText.setColor('#2ecc71')
      }
    } else {
      // Wrong answer: optionally show correct answer and hang
      this.inputText.setColor('#e74c3c')
      if (this.feedbackText) {
        this.feedbackText.setText(timedOut ? "Time's up!" : 'Wrong answer')
        this.feedbackText.setColor('#e74c3c')
      }
      if (this.answerText && this.currentOptions.showCorrectAnswer !== false) {
        this.answerText.setText(`Correct: ${correctAnswer}`)
        this.answerText.setColor('#2ecc71')
      }
    }

    if (isCorrect) {
      this.animateSuccess()
    } else {
      this.animateFailure(timedOut, correctAnswer)
    }

    if (this.currentOptions.onResult) {
      this.currentOptions.onResult({
        success: isCorrect,
        timedOut,
        word: this.word,
        input: this.input,
        correctAnswer,
      })
    }

    this.removeInputHandlers()

    const hangTime = isCorrect ? this.currentOptions.hangOnCorrect : this.currentOptions.hangOnWrong
    this.hangEvent = this.scene.time.delayedCall(hangTime, () => {
      this.hangEvent = null
      this.finish({ success: isCorrect, timedOut, word: this.word })
    })
  }

  finish(result) {
    this.hide()
    this.active = false
    if (this.currentOptions?.onComplete) {
      this.currentOptions.onComplete(result)
    }
    this.currentOptions = null
  }

  animateSuccess() {
    if (!this.wordText) return
    const word = this.wordText
    word.setColor('#2ecc71')

    this.scene.tweens.add({
      targets: word,
      scaleX: 1.4,
      scaleY: 1.4,
      duration: 250,
      ease: 'Back.easeOut',
      yoyo: true,
      hold: 200,
    })

    this.scene.tweens.add({
      targets: word,
      y: word.y - 30,
      duration: 400,
      ease: 'Quad.easeOut',
      yoyo: true,
      hold: 200,
    })

    // Sparkle particles around the word
    for (let i = 0; i < 8; i++) {
      const angle = (Math.PI * 2 * i) / 8
      const dist = 60
      const px = word.x + Math.cos(angle) * dist
      const py = word.y + Math.sin(angle) * dist
      const p = this.scene.add.text(px, py, '✦', {
        fontFamily: FONTS.default.fontFamily,
        fontSize: '16px',
        color: '#2ecc71',
      }).setOrigin(0.5).setAlpha(0)
      if (this.overlay) this.overlay.add(p)

      this.scene.tweens.add({
        targets: p,
        alpha: { from: 0, to: 1 },
        scaleX: { from: 0.5, to: 1.2 },
        scaleY: { from: 0.5, to: 1.2 },
        duration: 200,
        ease: 'Quad.easeOut',
        onComplete: () => {
          this.scene.tweens.add({
            targets: p,
            alpha: 0,
            scaleX: 0,
            scaleY: 0,
            duration: 300,
            delay: 300,
            onComplete: () => p.destroy(),
          })
        },
      })
    }
  }

  animateFailure(timedOut, correctAnswer) {
    if (!this.wordText) return
    const word = this.wordText
    word.setColor('#e74c3c')

    this.scene.tweens.add({
      targets: word,
      x: { from: word.x - 8, to: word.x + 8 },
      duration: 60,
      repeat: 5,
      yoyo: true,
      ease: 'Linear',
    })

    this.scene.tweens.add({
      targets: word,
      y: word.y + 20,
      alpha: 0.3,
      duration: 500,
      ease: 'Quad.easeIn',
    })

    // Show "X" marks
    for (let i = 0; i < 3; i++) {
      const ox = word.x + (i - 1) * 40
      const oy = word.y - 50
      const xMark = this.scene.add.text(ox, oy, '✕', {
        fontFamily: FONTS.default.fontFamily,
        fontSize: '24px',
        color: '#e74c3c',
      }).setOrigin(0.5).setAlpha(0)
      if (this.overlay) this.overlay.add(xMark)

      this.scene.tweens.add({
        targets: xMark,
        alpha: { from: 0, to: 1 },
        scaleX: { from: 0.3, to: 1 },
        scaleY: { from: 0.3, to: 1 },
        duration: 150,
        delay: i * 80,
        ease: 'Back.easeOut',
        onComplete: () => {
          this.scene.tweens.add({
            targets: xMark,
            alpha: 0,
            duration: 300,
            delay: 400,
            onComplete: () => xMark.destroy(),
          })
        },
      })
    }
  }

  removeInputHandlers() {
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

  hide() {
    this.removeInputHandlers()
    if (this.hangEvent) {
      this.hangEvent.remove()
      this.hangEvent = null
    }
    if (this.overlay) {
      this.overlay.destroy()
      this.overlay = null
    }
    this.keyboardContainer = null
    this.word = null
    this.input = ''
    this.titleText = null
    this.promptText = null
    this.wordText = null
    this.hintText = null
    this.inputText = null
    this.feedbackText = null
    this.answerText = null
    this.timerBar = null
    this.timerText = null
  }
}
