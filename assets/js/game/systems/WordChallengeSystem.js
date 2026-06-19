import { COLORS, FONTS, GAME_CONFIG } from '../config.js'

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
      timeLimit: 10000,
      hangOnWrong: 5000,
      hangOnCorrect: 0,
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
      promptType: 'reading',
      timeLimit: this.options.timeLimit,
      hangOnWrong: this.options.hangOnWrong,
      hangOnCorrect: this.options.hangOnCorrect,
      onStart: null,
      onResult: null,
      onComplete: null,
      ...options,
    }

    this.createOverlay()
    this.createHiddenInput()

    this.keyboardHandler = (event) => {
      if (!this.active) return
      if (event.key === 'Enter') {
        this.submit(false)
      } else if (event.key === 'Backspace') {
        this.input = this.input.slice(0, -1)
      } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
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

    const panel = this.scene.add.rectangle(0, 0, 460, 340, COLORS.panelBg).setStrokeStyle(2, COLORS.warning).setOrigin(0.5)
    this.overlay.add(panel)

    this.titleText = this.scene.add.text(0, -120, this.options.title, { ...FONTS.title, fontSize: '20px', color: '#f39c12' }).setOrigin(0.5)
    this.overlay.add(this.titleText)

    const prompt = this.currentOptions.promptType === 'meaning'
      ? this.options.promptForMeaning
      : this.options.promptForReading
    this.promptText = this.scene.add.text(0, -80, prompt, { ...FONTS.default, fontSize: '14px' }).setOrigin(0.5)
    this.overlay.add(this.promptText)

    this.wordText = this.scene.add.text(0, -30, this.word.word, { ...FONTS.kanji, fontSize: '42px' }).setOrigin(0.5)
    this.overlay.add(this.wordText)

    this.hintText = this.scene.add.text(0, 25, this.word.reading || '', { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.overlay.add(this.hintText)

    this.inputText = this.scene.add.text(0, 55, '', { ...FONTS.default, fontSize: '22px', color: '#f1c40f' }).setOrigin(0.5)
    this.overlay.add(this.inputText)

    const barBg = this.scene.add.rectangle(0, 95, 320, 12, COLORS.hpBg).setOrigin(0.5)
    this.overlay.add(barBg)
    this.timerBar = this.scene.add.rectangle(-160, 95, 320, 12, COLORS.warning).setOrigin(0, 0.5)
    this.overlay.add(this.timerBar)

    this.timerText = this.scene.add.text(0, 115, `${(this.currentOptions.timeLimit / 1000).toFixed(1)}s`, { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.overlay.add(this.timerText)

    this.feedbackText = this.scene.add.text(0, 140, 'Press Enter to submit', { ...FONTS.default, fontSize: '12px', color: '#7f8c8d' }).setOrigin(0.5)
    this.overlay.add(this.feedbackText)

    this.answerText = this.scene.add.text(0, 165, '', { ...FONTS.default, fontSize: '14px', color: '#2ecc71' }).setOrigin(0.5)
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

  submit(timedOut = false) {
    if (!this.word || this.hangEvent || !this.active) return

    const normalized = this.input.trim().toLowerCase()
    const accepted = this.currentOptions.promptType === 'meaning'
      ? String(this.word.meaning || '')
          .split('/')
          .map(s => s.trim().toLowerCase())
          .filter(Boolean)
      : this.getAcceptedReadings(this.word)

    const isCorrect = !timedOut && accepted.some(a => a === normalized)
    const correctAnswer = this.currentOptions.promptType === 'meaning'
      ? (this.word.meaning || '')
      : (this.word.reading || '')

    if (isCorrect) {
      this.inputText.setColor('#2ecc71')
      if (this.feedbackText) {
        this.feedbackText.setText('Correct!')
        this.feedbackText.setColor('#2ecc71')
      }
      if (this.answerText) {
        this.answerText.setText(`Answer: ${correctAnswer}`)
        this.answerText.setColor('#2ecc71')
      }
    } else {
      // Wrong answer: show correct answer and hang
      this.inputText.setColor('#e74c3c')
      if (this.feedbackText) {
        this.feedbackText.setText(timedOut ? "Time's up!" : 'Wrong answer')
        this.feedbackText.setColor('#e74c3c')
      }
      if (this.answerText) {
        this.answerText.setText(`Correct: ${correctAnswer}`)
        this.answerText.setColor('#2ecc71')
      }
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

  getAcceptedReadings(word) {
    const values = [word.reading, word.word].filter(Boolean)
    const normalized = values.map(s => s.trim().toLowerCase())
    const romaji = values.map(s => this.kanaToRomaji(s)).filter(Boolean)
    return [...new Set([...normalized, ...romaji])]
  }

  kanaToRomaji(input) {
    if (!input) return ''
    const map = {
      'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
      'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
      'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
      'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
      'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
      'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
      'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
      'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
      'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
      'わ': 'wa', 'を': 'wo', 'ん': 'n',
      'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
      'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
      'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
      'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
      'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
      'きゃ': 'kya', 'きゅ': 'kyu', 'きょ': 'kyo',
      'しゃ': 'sha', 'しゅ': 'shu', 'しょ': 'sho',
      'ちゃ': 'cha', 'ちゅ': 'chu', 'ちょ': 'cho',
      'にゃ': 'nya', 'にゅ': 'nyu', 'にょ': 'nyo',
      'ひゃ': 'hya', 'ひゅ': 'hyu', 'ひょ': 'hyo',
      'みゃ': 'mya', 'みゅ': 'myu', 'みょ': 'myo',
      'りゃ': 'rya', 'りゅ': 'ryu', 'りょ': 'ryo',
      'ぎゃ': 'gya', 'ぎゅ': 'gyu', 'ぎょ': 'gyo',
      'じゃ': 'ja', 'じゅ': 'ju', 'じょ': 'jo',
      'びゃ': 'bya', 'びゅ': 'byu', 'びょ': 'byo',
      'ぴゃ': 'pya', 'ぴゅ': 'pyu', 'ぴょ': 'pyo',
      'ア': 'a', 'イ': 'i', 'ウ': 'u', 'エ': 'e', 'オ': 'o',
      'カ': 'ka', 'キ': 'ki', 'ク': 'ku', 'ケ': 'ke', 'コ': 'ko',
      'サ': 'sa', 'シ': 'shi', 'ス': 'su', 'セ': 'se', 'ソ': 'so',
      'タ': 'ta', 'チ': 'chi', 'ツ': 'tsu', 'テ': 'te', 'ト': 'to',
      'ナ': 'na', 'ニ': 'ni', 'ヌ': 'nu', 'ネ': 'ne', 'ノ': 'no',
      'ハ': 'ha', 'ヒ': 'hi', 'フ': 'fu', 'ヘ': 'he', 'ホ': 'ho',
      'マ': 'ma', 'ミ': 'mi', 'ム': 'mu', 'メ': 'me', 'モ': 'mo',
      'ヤ': 'ya', 'ユ': 'yu', 'ヨ': 'yo',
      'ラ': 'ra', 'リ': 'ri', 'ル': 'ru', 'レ': 're', 'ロ': 'ro',
      'ワ': 'wa', 'ヲ': 'wo', 'ン': 'n',
      'ガ': 'ga', 'ギ': 'gi', 'グ': 'gu', 'ゲ': 'ge', 'ゴ': 'go',
      'ザ': 'za', 'ジ': 'ji', 'ズ': 'zu', 'ゼ': 'ze', 'ゾ': 'zo',
      'ダ': 'da', 'ヂ': 'ji', 'ヅ': 'zu', 'デ': 'de', 'ド': 'do',
      'バ': 'ba', 'ビ': 'bi', 'ブ': 'bu', 'ベ': 'be', 'ボ': 'bo',
      'パ': 'pa', 'ピ': 'pi', 'プ': 'pu', 'ペ': 'pe', 'ポ': 'po',
      'キャ': 'kya', 'キュ': 'kyu', 'キョ': 'kyo',
      'シャ': 'sha', 'シュ': 'shu', 'ショ': 'sho',
      'チャ': 'cha', 'チュ': 'chu', 'チョ': 'cho',
      'ニャ': 'nya', 'ニュ': 'nyu', 'ニョ': 'nyo',
      'ヒャ': 'hya', 'ヒュ': 'hyu', 'ヒョ': 'hyo',
      'ミャ': 'mya', 'ミュ': 'myu', 'ミョ': 'myo',
      'リャ': 'rya', 'リュ': 'ryu', 'リョ': 'ryo',
      'ギャ': 'gya', 'ギュ': 'gyu', 'ギョ': 'gyo',
      'ジャ': 'ja', 'ジュ': 'ju', 'ジョ': 'jo',
      'ビャ': 'bya', 'ビュ': 'byu', 'ビョ': 'byo',
      'ピャ': 'pya', 'ピュ': 'pyu', 'ピョ': 'pyo',
      'ー': '', 'ッ': '', 'っ': '',
    }

    let result = ''
    const s = input.trim()
    for (let i = 0; i < s.length; i++) {
      const two = s[i] + (s[i + 1] || '')
      if (map[two]) {
        result += map[two]
        i++
      } else if (map[s[i]]) {
        result += map[s[i]]
      } else {
        result += s[i]
      }
    }
    return result.toLowerCase()
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
