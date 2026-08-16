import { GAME_CONFIG, FONTS, COLORS } from '../config.js'
import { TILE_TYPES } from '../data/tileTypes.js'
import { getWindowGameData } from '../api.js'
import { ITEMS } from '../data/items.js'
import { ALL_ACTIONS } from '../data/actions.js'
import { getRewardPool, pickRewardAbilities } from '../data/abilityRewards.js'
import { isChallengeWord } from '../systems/EnemyChallengePicker.js'
import { setupHighDPIWorld } from '../highDpi.js'

const GAME_DURATION_MS = 60000
const SPEED_INCREASE_INTERVAL_MS = 20000
const LIVES = 3
const WORD_GOLD = 5
const ROWS_TO_DANGER = 20
const MIN_SPAWN_INTERVAL = 800

// Tick interval per row, copied from the site Kana Cascade game.
const SPEED_TO_MS = {
  1: 2000,
  2: 1800,
  3: 1500,
  4: 1200,
  5: 1000,
  6: 900,
  7: 700,
  8: 600,
  9: 500,
  10: 300,
}

const KEYBOARD_ROWS = [
  ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
  ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
  ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
  ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ['-'],
]

// Larger, simplified layout for touch devices (no number row, bigger keys).
const TOUCH_KEYBOARD_ROWS = [
  ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
  ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
  ['Z', 'X', 'C', 'V', 'B', 'N', 'M', '-'],
]

export default class CascadeScene extends Phaser.Scene {
  constructor() {
    super({ key: 'CascadeScene' })
  }

  init(data) {
    this.player = data.player
    this.tile = data.tile
    this.mapIndex = data.mapIndex
    this.returnScene = data.returnScene || 'MapScene'
    this.skipCompleteTile = data.skipCompleteTile || false
  }

  create() {
    setupHighDPIWorld(this)
    this.wordList = this.buildWordList()
    this.speedLevel = Math.min(10, this.tile?.col || 1)
    this.baseSpeedLevel = this.speedLevel
    this.wordsDestroyed = 0
    this.wordIndex = 0
    this.lives = LIVES
    this.goldEarned = 0
    this.itemsEarned = []
    this.abilitiesEarned = []
    this.pendingChoices = []
    this.currentWord = null
    this.inputBuffer = ''
    this.keyboardVisible = true
    this.gameActive = false
    this.gameStarted = false
    this.gameEnded = false
    this.lastSpawnTime = 0
    this.lastTickTime = 0
    this.gameStartTime = 0
    this.lastSpeedIncreaseTime = 0

    this.createBackground()
    this.createHud()
    this.createInputDisplay()
    this.createKeyboard()
    this.createKeyboardToggleButton()
    this.setupPhysicalInput()

    this.recalculateGeometry()
    this.spawnInterval = this.getSpawnInterval()

    this.time.addEvent({
      delay: 1000,
      callback: this.updateTimer,
      callbackScope: this,
      loop: true,
    })

    this.createStartOverlay()
    this.autoStartEvent = this.time.delayedCall(2000, this.startGame, [], this)
  }

  createStartOverlay() {
    this.startOverlayVisible = true
    this.startOverlay = this.add.container(0, 0)
    this.startOverlay.setDepth(300)

    const backdrop = this.add.rectangle(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      GAME_CONFIG.width,
      GAME_CONFIG.height,
      0x000000,
      0.75,
    ).setOrigin(0.5)
    backdrop.setInteractive({ useHandCursor: true })
    backdrop.on('pointerdown', () => this.startGame())
    this.startOverlay.add(backdrop)

    const title = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 30, 'Get Ready', {
      ...FONTS.title,
      fontSize: '32px',
      color: '#f1c40f',
    }).setOrigin(0.5)
    this.startOverlay.add(title)

    const hint = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 20, 'Click or press any key to start', {
      ...FONTS.default,
      fontSize: '18px',
      color: '#ecf0f1',
    }).setOrigin(0.5)
    this.startOverlay.add(hint)
  }

  startGame() {
    if (this.gameStarted) return
    this.gameStarted = true
    this.startOverlayVisible = false

    if (this.autoStartEvent) {
      this.autoStartEvent.remove()
      this.autoStartEvent = null
    }

    if (this.startOverlay) {
      this.startOverlay.destroy()
      this.startOverlay = null
    }

    this.gameActive = true
    this.gameStartTime = this.time.now
    this.lastSpawnTime = this.time.now
    this.lastTickTime = this.time.now
    this.lastSpeedIncreaseTime = 0
  }

  buildWordList() {
    const rawWords = this.player?.getChallengeWordList?.() || getWindowGameData()?.word_list || []
    const words = rawWords
      .filter(w => w && (w.word || w.text) && w.meaning && isChallengeWord(w))
      .map(w => ({
        id: w.word || w.text,
        text: w.word || w.text,
        reading: w.reading || '',
        meaning: w.meaning,
        answers: this.extractAnswers(w.meaning),
      }))

    if (words.length === 0) {
      // Fallback so the game never launches with zero words.
      return [
        {
          id: 'hello',
          text: 'こんにちは',
          reading: 'konnichiwa',
          meaning: 'hello',
          answers: ['hello'],
        },
        {
          id: 'cat',
          text: '猫',
          reading: 'neko',
          meaning: 'cat',
          answers: ['cat'],
        },
        {
          id: 'water',
          text: '水',
          reading: 'mizu',
          meaning: 'water',
          answers: ['water'],
        },
      ]
    }

    return this.shuffle(words)
  }

  extractAnswers(meaning) {
    if (!meaning) return []
    return meaning
      .split(/[,;/|()]+/)
      .map(s => s.trim().toLowerCase())
      .filter(s => s.length > 0)
  }

  shuffle(array) {
    const arr = [...array]
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[arr[i], arr[j]] = [arr[j], arr[i]]
    }
    return arr
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createHud() {
    this.hud = {}

    this.hud.timer = this.add.text(20, 16, '60', {
      ...FONTS.title,
      fontSize: '28px',
      color: '#f1c40f',
    })

    this.hud.lives = this.add.text(GAME_CONFIG.width / 2, 24, this.heartString(), {
      ...FONTS.default,
      fontSize: '24px',
    }).setOrigin(0.5, 0)

    this.hud.words = this.add.text(GAME_CONFIG.width - 20, 16, 'Words: 0', {
      ...FONTS.default,
      fontSize: '18px',
      color: '#ecf0f1',
    }).setOrigin(1, 0)

    this.hud.speed = this.add.text(GAME_CONFIG.width - 20, 42, `Speed: ${this.speedLevel}`, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#bdc3c7',
    }).setOrigin(1, 0)

    this.hud.gold = this.add.text(20, 50, `+0 gold`, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#f1c40f',
    })
  }

  heartString() {
    return '❤️'.repeat(this.lives) + '🖤'.repeat(LIVES - this.lives)
  }

  createInputDisplay() {
    this.inputText = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height - 190, '', {
      ...FONTS.default,
      fontSize: '22px',
      color: '#a9cce3',
      backgroundColor: '#00000055',
      padding: { left: 12, right: 12, top: 6, bottom: 6 },
    }).setOrigin(0.5, 1)
      .setDepth(101)
  }

  setupPhysicalInput() {
    this.input.keyboard.on('keydown', (event) => {
      if (this.startOverlayVisible) {
        event.preventDefault()
        this.startGame()
        return
      }
      if (!this.gameActive || this.gameEnded) return

      const key = event.key
      const isGameKey =
        key === 'Backspace' ||
        key === 'Enter' ||
        key === ' ' ||
        key === 'ArrowDown' ||
        /^[a-zA-Z0-9-]$/.test(key)

      if (isGameKey) {
        event.preventDefault()
      }

      if (key === 'Backspace') {
        this.handleKey('BACKSPACE')
      } else if (key === 'Enter') {
        this.handleKey('ENTER')
      } else if (key === ' ') {
        this.handleKey('SPACE')
      } else if (key === 'ArrowDown') {
        this.skipWord()
      } else if (/^[a-zA-Z0-9-]$/.test(key)) {
        this.handleKey(key.toUpperCase())
      }
    })
  }

  createKeyboard() {
    this.keyboardContainer = this.add.container(0, 0)
    this.keyboardContainer.setDepth(100)
    this.keyboardKeys = []

    const isTouch = this.sys.game.device.input.touch
    // Use a larger, simplified layout on touch devices so keys are easier to hit.
    const rows = isTouch ? TOUCH_KEYBOARD_ROWS : KEYBOARD_ROWS
    const keySize = isTouch ? 30 : 22
    const keyGap = isTouch ? 4 : 3
    const keyboardHeight = isTouch ? 148 : 155
    this.keyboardStartY = GAME_CONFIG.height - keyboardHeight

    rows.forEach((row, rowIndex) => {
      const rowWidth = row.length * keySize + (row.length - 1) * keyGap
      const startX = (GAME_CONFIG.width - rowWidth) / 2 + keySize / 2
      row.forEach((char, colIndex) => {
        const x = startX + colIndex * (keySize + keyGap)
        const y = this.keyboardStartY + rowIndex * (keySize + keyGap)
        this.createKey(char, x, y, keySize, keySize)
      })
    })

    // Control row: backspace, space, enter, delete (clear).
    const controlY = this.keyboardStartY + rows.length * (keySize + keyGap) + 6
    const controls = [
      { label: '⌫', width: isTouch ? 54 : 40, key: 'BACKSPACE' },
      { label: 'SPACE', width: isTouch ? 120 : 100, key: 'SPACE' },
      { label: '⏎', width: isTouch ? 54 : 40, key: 'ENTER' },
      { label: 'DEL', width: isTouch ? 54 : 40, key: 'DELETE' },
    ]
    const controlGap = isTouch ? 6 : 5
    const controlsWidth = controls.reduce((sum, c) => sum + c.width, 0) + (controls.length - 1) * controlGap
    let controlX = (GAME_CONFIG.width - controlsWidth) / 2
    controls.forEach(({ label, width, key }) => {
      this.createKey(label, controlX + width / 2, controlY, width, keySize, key)
      controlX += width + controlGap
    })
  }

  createKey(label, x, y, width, height, emitKey = null) {
    const key = emitKey || label
    const bg = this.add.rectangle(0, 0, width, height, 0x2c3e50)
      .setStrokeStyle(1, 0x5d6d7e)
    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: label.length > 1 ? '12px' : '16px',
      color: '#ecf0f1',
    }).setOrigin(0.5)

    const container = this.add.container(x, y, [bg, text])
    container.setSize(width, height)

    const hitArea = this.add.rectangle(0, 0, width, height, 0x000000, 0)
    hitArea.setInteractive({ useHandCursor: true })
    container.add(hitArea)

    const pressKey = () => {
      bg.setFillStyle(0x3498db)
      container.setScale(0.92)
    }
    const releaseKey = () => {
      bg.setFillStyle(0x2c3e50)
      container.setScale(1)
    }

    hitArea.on('pointerdown', () => {
      pressKey()
      this.handleKey(key)
    })
    hitArea.on('pointerup', releaseKey)
    hitArea.on('pointerout', releaseKey)

    container.keyName = key
    this.keyboardContainer.add(container)
    this.keyboardKeys.push(container)
  }

  createKeyboardToggleButton() {
    const width = 80
    const height = 28
    const x = GAME_CONFIG.width - width / 2 - 10
    const y = this.keyboardStartY - 28

    const bg = this.add.rectangle(0, 0, width, height, 0x2c3e50)
      .setStrokeStyle(1, 0x5d6d7e)
    const text = this.add.text(0, 0, 'Hide', {
      ...FONTS.default,
      fontSize: '12px',
      color: '#ecf0f1',
    }).setOrigin(0.5)

    this.keyboardToggleButton = this.add.container(x, y, [bg, text])
    this.keyboardToggleButton.setSize(width, height)
    this.keyboardToggleButton.setDepth(100)

    const hitArea = this.add.rectangle(0, 0, width, height, 0x000000, 0)
    hitArea.setInteractive({ useHandCursor: true })
    this.keyboardToggleButton.add(hitArea)

    hitArea.on('pointerdown', () => {
      bg.setFillStyle(0x3498db)
      this.toggleKeyboard()
    })
    hitArea.on('pointerup', () => bg.setFillStyle(0x2c3e50))
    hitArea.on('pointerout', () => bg.setFillStyle(0x2c3e50))
  }

  handleKey(key) {
    if (!this.gameActive || this.gameEnded) return

    if (key === 'BACKSPACE') {
      this.inputBuffer = this.inputBuffer.slice(0, -1)
    } else if (key === 'DELETE') {
      this.inputBuffer = ''
    } else if (key === 'SPACE') {
      this.inputBuffer += ' '
    } else if (key === 'ENTER') {
      this.tryMatchExact()
    } else if (key.length === 1) {
      this.inputBuffer += key.toLowerCase()
    }

    this.updateInputDisplay()
    this.checkMatches()
  }

  tryMatchExact() {
    const buffer = this.inputBuffer.trim().toLowerCase()
    if (!buffer || !this.currentWord) return
    if (this.currentWord.wordData.answers.includes(buffer)) {
      this.destroyWord()
      this.inputBuffer = ''
      this.updateInputDisplay()
    }
  }

  checkMatches() {
    const buffer = this.inputBuffer.trim().toLowerCase()
    if (!buffer || !this.currentWord) return
    if (this.currentWord.wordData.answers.includes(buffer)) {
      this.destroyWord()
      this.inputBuffer = ''
      this.updateInputDisplay()
    }
  }

  updateInputDisplay() {
    this.inputText.setText(`> ${this.inputBuffer}`)
  }

  toggleKeyboard() {
    this.keyboardVisible = !this.keyboardVisible
    this.keyboardContainer.setVisible(this.keyboardVisible)
    this.recalculateGeometry()
  }

  updateKeyboardToggleButton() {
    if (!this.keyboardToggleButton) return
    const textObj = this.keyboardToggleButton.list.find(c => c.type === 'Text')
    if (textObj) textObj.setText(this.keyboardVisible ? 'Hide' : 'Show')
    this.keyboardToggleButton.y = this.keyboardVisible
      ? this.keyboardStartY - 28
      : GAME_CONFIG.height - 40
  }

  recalculateGeometry() {
    this.dangerY = this.keyboardVisible ? this.keyboardStartY - 12 : GAME_CONFIG.height - 60
    this.rowHeight = (this.dangerY - 90) / (ROWS_TO_DANGER - 1)
    this.inputText.y = this.keyboardVisible ? this.keyboardStartY - 50 : GAME_CONFIG.height - 50
    this.updateKeyboardToggleButton()

    // Reposition the current word by its row.
    if (this.currentWord && this.currentWord.wordData && this.currentWord.wordData.row) {
      this.currentWord.y = 90 + (this.currentWord.wordData.row - 1) * this.rowHeight
    }
  }

  getSpawnInterval() {
    // Only used for the initial spawn; respawns are immediate after a word ends.
    return 400
  }

  getTickInterval() {
    return SPEED_TO_MS[this.speedLevel] || 1000
  }

  update(time, delta) {
    if (!this.gameActive || this.gameEnded) return

    const elapsed = time - this.gameStartTime
    this.updateSpeed(elapsed)
    this.spawnWords(time)
    this.tickWords(time)
  }

  updateSpeed(elapsed) {
    const increases = Math.floor(elapsed / SPEED_INCREASE_INTERVAL_MS)
    const newSpeed = Math.min(10, this.baseSpeedLevel + increases)
    if (newSpeed !== this.speedLevel) {
      this.speedLevel = newSpeed
      this.spawnInterval = this.getSpawnInterval()
      this.hud.speed.setText(`Speed: ${this.speedLevel}`)
    }
  }

  spawnWords(time) {
    if (this.currentWord) return
    if (time - this.lastSpawnTime < this.spawnInterval) return

    this.lastSpawnTime = time
    const word = this.wordList[this.wordIndex % this.wordList.length]
    this.wordIndex += 1
    this.spawnWord(word)
  }

  spawnWord(word) {
    const x = Phaser.Math.Between(80, GAME_CONFIG.width - 80)
    const container = this.add.container(x, 90)

    const bg = this.add.rectangle(0, 0, 130, 58, 0x1a5276).setStrokeStyle(2, 0x5dade2)
    const text = this.add.text(0, -8, word.text, {
      ...FONTS.kanji,
      fontSize: '22px',
      color: '#ecf0f1',
    }).setOrigin(0.5)
    const reading = this.add.text(0, 14, word.reading, {
      ...FONTS.default,
      fontSize: '11px',
      color: '#aed6f1',
    }).setOrigin(0.5)

    container.add([bg, text, reading])
    container.wordData = { ...word, row: 1 }
    this.currentWord = container
  }

  tickWords(time) {
    const tickInterval = this.getTickInterval()
    if (time - this.lastTickTime < tickInterval) return
    this.lastTickTime = time

    if (!this.currentWord) return

    this.currentWord.wordData.row += 1
    this.currentWord.y = 90 + (this.currentWord.wordData.row - 1) * this.rowHeight

    if (this.currentWord.wordData.row >= ROWS_TO_DANGER) {
      this.crashWord()
    }
  }

  loseLife() {
    this.lives = Math.max(0, this.lives - 1)
    this.hud.lives.setText(this.heartString())
    this.cameras.main.shake(100, 0.005)
    this.inputBuffer = ''
    this.updateInputDisplay()
    if (this.lives <= 0) {
      this.endGame(false)
    } else {
      this.lastSpawnTime = 0
    }
  }

  skipWord() {
    if (!this.gameActive || this.gameEnded || !this.currentWord) return
    this.crashWord()
  }

  crashWord() {
    if (!this.currentWord) return
    const wordData = this.currentWord.wordData
    this.showAnswer(wordData)
    this.currentWord.destroy()
    this.currentWord = null
    this.loseLife()
  }

  showAnswer(wordData) {
    if (this.answerText) {
      this.answerText.destroy()
    }

    const meaning = (wordData.meaning || '').slice(0, 80)
    const reading = wordData.reading || ''
    const label = reading ? `${meaning} (${reading})` : meaning

    this.answerText = this.add.text(GAME_CONFIG.width / 2, this.dangerY - 30, `Answer: ${label}`, {
      ...FONTS.default,
      fontSize: '16px',
      color: '#e74c3c',
      backgroundColor: '#000000aa',
      padding: { left: 10, right: 10, top: 6, bottom: 6 },
    }).setOrigin(0.5).setDepth(120)

    this.tweens.add({
      targets: this.answerText,
      alpha: 0,
      duration: 1000,
      delay: 3500,
      onComplete: () => {
        if (this.answerText) {
          this.answerText.destroy()
          this.answerText = null
        }
      },
    })
  }

  destroyWord() {
    const container = this.currentWord
    this.currentWord = null
    if (!container) return

    // Pop effect.
    this.tweens.add({
      targets: container,
      scale: 1.3,
      alpha: 0,
      duration: 150,
      onComplete: () => container.destroy(),
    })

    this.wordsDestroyed += 1
    this.goldEarned += WORD_GOLD
    this.hud.words.setText(`Words: ${this.wordsDestroyed}`)
    this.hud.gold.setText(`+${this.goldEarned} gold`)
    this.lastSpawnTime = 0

    this.checkRewards()
  }

  checkRewards() {
    if (this.wordsDestroyed % 10 === 0) {
      this.grantRandomItem()
    }
    if (this.wordsDestroyed % 20 === 0) {
      this.offerAbilityChoice()
    }
    if (this.wordsDestroyed % 30 === 0) {
      this.offerUpgradeChoice()
    }
  }

  grantRandomItem() {
    const item = Phaser.Math.RND.pick(ITEMS)
    this.player.addItem(item.id, 1)
    this.itemsEarned.push(item.name)
    this.showToast(`Item: ${item.icon} ${item.name}`)
  }

  offerAbilityChoice() {
    this.pauseGame()
    const pool = getRewardPool(this.player)
    const options = pickRewardAbilities(pool, 3, this.player.loadout.knownActionIds || [])
      .slice(0, 3)
      .map(id => this.findAbility(id))
      .filter(Boolean)

    if (options.length === 0) {
      this.resumeGame()
      return
    }

    this.showChoiceDialog('Choose an ability', options, (choice) => {
      this.player.learnAbility(choice.id)
      this.abilitiesEarned.push(choice.name)
      this.showToast(`Learned: ${choice.name}`)
      this.resumeGame()
    })
  }

  offerUpgradeChoice() {
    this.pauseGame()
    const options = [
      { id: 'weapon', name: 'Upgrade Weapon', icon: '⚔️' },
      { id: 'shield', name: 'Upgrade Shield', icon: '🛡️' },
      { id: 'heal', name: 'Heal 50% HP', icon: '❤️' },
    ]
    this.showChoiceDialog('Choose a reward', options, (choice) => {
      if (choice.id === 'weapon') {
        this.player.weapon.level = (this.player.weapon.level || 0) + 1
        this.showToast('Weapon upgraded!')
      } else if (choice.id === 'shield') {
        this.player.shield.level = (this.player.shield.level || 0) + 1
        this.showToast('Shield upgraded!')
      } else {
        const heal = Math.floor(this.player.maxHp * 0.5)
        this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal)
        this.showToast(`Healed ${heal} HP`)
      }
      this.resumeGame()
    })
  }

  findAbility(id) {
    return ALL_ACTIONS.find(a => a.id === id)
  }

  pauseGame() {
    this.gameActive = false
  }

  resumeGame() {
    if (this.gameEnded) return
    this.gameActive = true
    this.lastSpawnTime = this.time.now
    this.lastTickTime = this.time.now
  }

  showChoiceDialog(title, options, onSelect) {
    if (this.choiceDialog) this.choiceDialog.destroy()

    const container = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    container.setDepth(200)

    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.7).setOrigin(0.5)
    backdrop.setInteractive()
    container.add(backdrop)

    const panel = this.add.rectangle(0, 0, 420, 280, 0x16213e).setStrokeStyle(2, 0x3498db).setOrigin(0.5)
    container.add(panel)

    const titleText = this.add.text(0, -100, title, {
      ...FONTS.title,
      fontSize: '22px',
      color: '#f1c40f',
    }).setOrigin(0.5)
    container.add(titleText)

    options.forEach((option, index) => {
      const y = -40 + index * 60
      const btn = this.add.rectangle(0, y, 360, 44, 0x2980b9).setInteractive({ useHandCursor: true }).setOrigin(0.5)
      const label = this.add.text(0, y, `${option.icon || ''} ${option.name || option.nameJa || option.id}`, {
        ...FONTS.default,
        fontSize: '16px',
        color: '#ffffff',
      }).setOrigin(0.5)

      btn.on('pointerdown', () => {
        container.destroy()
        this.choiceDialog = null
        onSelect(option)
      })
      btn.on('pointerover', () => btn.setFillStyle(0x3498db))
      btn.on('pointerout', () => btn.setFillStyle(0x2980b9))

      container.add([btn, label])
    })

    this.choiceDialog = container
  }

  showToast(message) {
    const toast = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 - 80, message, {
      ...FONTS.default,
      fontSize: '18px',
      color: '#f1c40f',
      backgroundColor: '#000000aa',
      padding: { left: 12, right: 12, top: 6, bottom: 6 },
    }).setOrigin(0.5).setDepth(150)

    this.tweens.add({
      targets: toast,
      y: toast.y - 40,
      alpha: 0,
      duration: 1200,
      onComplete: () => toast.destroy(),
    })
  }

  updateTimer() {
    if (!this.gameActive || this.gameEnded) return
    const elapsed = Math.floor((this.time.now - this.gameStartTime) / 1000)
    const remaining = Math.max(0, GAME_DURATION_MS / 1000 - elapsed)
    this.hud.timer.setText(String(remaining))
    if (remaining <= 0) {
      this.endGame(true)
    }
  }

  endGame(timeUp) {
    if (this.gameEnded) return
    this.gameEnded = true
    this.gameActive = false

    this.player.addGold(this.goldEarned)
    this.player.saveLoadout()

    this.showResults(timeUp)
  }

  showResults(timeUp) {
    const container = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    container.setDepth(200)

    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.8).setOrigin(0.5)
    backdrop.setInteractive()
    container.add(backdrop)

    const panel = this.add.rectangle(0, 0, 440, 360, 0x16213e).setStrokeStyle(2, 0x3498db).setOrigin(0.5)
    container.add(panel)

    const title = timeUp ? 'Time is up!' : 'Cascade Failed'
    const titleText = this.add.text(0, -140, title, {
      ...FONTS.title,
      fontSize: '26px',
      color: timeUp ? '#2ecc71' : '#e74c3c',
    }).setOrigin(0.5)
    container.add(titleText)

    const lines = [
      `Words destroyed: ${this.wordsDestroyed}`,
      `Gold earned: ${this.goldEarned}`,
      `Items found: ${this.itemsEarned.join(', ') || 'none'}`,
      `Abilities learned: ${this.abilitiesEarned.join(', ') || 'none'}`,
    ]

    lines.forEach((line, i) => {
      container.add(this.add.text(0, -80 + i * 32, line, {
        ...FONTS.default,
        fontSize: '16px',
        color: '#ecf0f1',
      }).setOrigin(0.5))
    })

    const btn = this.add.rectangle(0, 120, 180, 44, 0x27ae60).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const btnText = this.add.text(0, 120, 'Continue', {
      ...FONTS.default,
      fontSize: '18px',
      color: '#ffffff',
    }).setOrigin(0.5)

    btn.on('pointerdown', () => {
      container.destroy()
      this.completeTile()
    })
    btn.on('pointerover', () => btn.setFillStyle(0x2ecc71))
    btn.on('pointerout', () => btn.setFillStyle(0x27ae60))

    container.add([btn, btnText])
  }

  completeTile() {
    if (this.tile?.id && !this.skipCompleteTile) {
      this.player.completeTile(this.tile.id)
    }
    this.scene.start(this.returnScene, { player: this.player })
  }
}
