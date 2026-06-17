import { GAME_CONFIG, COLORS, FONTS } from '../config.js'

const KANA_ROMAJI = {
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

function kanaToRomaji(input) {
  if (!input) return ''
  let result = ''
  const s = input.trim()
  for (let i = 0; i < s.length; i++) {
    const two = s[i] + (s[i + 1] || '')
    if (KANA_ROMAJI[two]) {
      result += KANA_ROMAJI[two]
      i++
    } else if (KANA_ROMAJI[s[i]]) {
      result += KANA_ROMAJI[s[i]]
    } else {
      result += s[i]
    }
  }
  return result.toLowerCase()
}

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

    const displayValue = this.challenge.type === 'word'
      ? this.challenge.word.word
      : this.challenge.kanji
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
    const input = normalize(this.input)

    if (this.challenge.type === 'word') {
      const word = this.challenge.word
      if (this.challenge.promptType === 'meaning') {
        const accepted = String(word.meaning || '')
          .split('/')
          .map(s => s.trim().toLowerCase())
          .filter(Boolean)
        return accepted.includes(input)
      } else {
        const accepted = [
          normalize(word.reading || ''),
          normalize(word.word || ''),
          kanaToRomaji(word.reading || ''),
        ]
        return accepted.includes(input)
      }
    }

    if (this.challenge.type === 'kanji') {
      const accepted = (this.challenge.readings || []).map(r => normalize(r))
      const inputRomaji = kanaToRomaji(this.input)
      return accepted.includes(input) || accepted.includes(inputRomaji)
    }

    return false
  }

  submit(timedOut = false) {
    if (!this.active) return

    const isCorrect = !timedOut && this.evaluate()
    this.active = false

    if (isCorrect) {
      this.inputText.setColor('#2ecc71')
      this.feedbackText.setText('Correct! Ability weakened/cancelled.')
      this.feedbackText.setColor('#2ecc71')
    } else {
      this.inputText.setColor('#e74c3c')
      this.feedbackText.setText(timedOut ? "Time's up!" : 'Wrong! Ability resolves fully.')
      this.feedbackText.setColor('#e74c3c')
    }

    this.removeHandlers()

    this.scene.time.delayedCall(1200, () => {
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
