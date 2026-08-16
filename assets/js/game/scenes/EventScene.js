import { GAME_CONFIG, FONTS } from '../config.js'
import { setupHighDPIWorld } from '../highDpi.js'
import { ITEMS } from '../data/items.js'
import { CHARM_TYPES, CHARMS } from '../data/charms.js'
import { ALL_SOCKET_CHARMS } from '../data/socketCharms.js'
import { getRewardPool, pickRewardAbilities } from '../data/abilityRewards.js'

const EVENT_TYPES = {
  lost_memories: { name: 'Lost Memories', color: 0x9b59b6 },
}

function shuffle(array) {
  const arr = array.slice()
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[arr[i], arr[j]] = [arr[j], arr[i]]
  }
  return arr
}

export default class EventScene extends Phaser.Scene {
  constructor() {
    super({ key: 'EventScene' })
  }

  init(data) {
    this.player = data.player
    this.tile = data.tile
    this.mapIndex = data.mapIndex ?? 0
    this.eventType = data.eventType || 'lost_memories'
    this.devMode = data.devMode || false
    this.selectedWords = this.pickWords()
    this.currentWordIndex = 0
    this.results = []
  }

  preload() {
    for (const word of this.selectedWords) {
      if (word.image_path) {
        const url = word.image_path.startsWith('/') ? word.image_path : `/uploads/${word.image_path}`
        this.load.image(`word-img-${word.id}`, url)
      }
    }
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()

    if (this.selectedWords.length === 0) {
      this.showNoWordsMessage()
      return
    }

    this.showWordIntro()
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  pickWords() {
    const count = 1 + Math.floor(Math.random() * 4)
    return this.player.getCandidateEventWords(count).slice(0, count)
  }

  clearContent() {
    if (this.contentContainer) {
      this.contentContainer.destroy()
    }
    this.contentContainer = this.add.container(0, 0)
    this.contentContainer.setDepth(10)
  }

  showNoWordsMessage() {
    this.clearContent()
    const title = this.add.text(GAME_CONFIG.width / 2, 120, 'Lost Memories', {
      ...FONTS.title, fontSize: '28px', color: '#f1c40f',
    }).setOrigin(0.5)
    this.contentContainer.add(title)

    const msg = this.add.text(GAME_CONFIG.width / 2, 240, 'No unfamiliar words remain to recover.', {
      ...FONTS.default, fontSize: '16px', color: '#ecf0f1', align: 'center',
      wordWrap: { width: 520 },
    }).setOrigin(0.5)
    this.contentContainer.add(msg)

    this.addContinueButton(360, () => this.returnToMap())
  }

  showWordIntro() {
    this.clearContent()
    const word = this.selectedWords[this.currentWordIndex]

    const eventName = EVENT_TYPES[this.eventType]?.name || 'Event'
    const title = this.add.text(GAME_CONFIG.width / 2, 40, `${eventName} (${this.currentWordIndex + 1}/${this.selectedWords.length})`, {
      ...FONTS.title, fontSize: '24px', color: '#f1c40f',
    }).setOrigin(0.5)
    this.contentContainer.add(title)

    const yBase = 110
    let y = yBase

    if (word.image_path && this.textures.exists(`word-img-${word.id}`)) {
      const img = this.add.image(GAME_CONFIG.width / 2, y + 50, `word-img-${word.id}`)
        .setDisplaySize(120, 120)
        .setOrigin(0.5)
      this.contentContainer.add(img)
      y += 130
    }

    const wordText = this.add.text(GAME_CONFIG.width / 2, y, word.word || '', {
      ...FONTS.title, fontSize: '36px', color: '#ecf0f1',
    }).setOrigin(0.5)
    this.contentContainer.add(wordText)
    y += 44

    const readingText = this.add.text(GAME_CONFIG.width / 2, y, word.reading || '', {
      ...FONTS.default, fontSize: '18px', color: '#bdc3c7',
    }).setOrigin(0.5)
    this.contentContainer.add(readingText)
    y += 40

    const meaningText = this.add.text(GAME_CONFIG.width / 2, y, word.meaning || '', {
      ...FONTS.default, fontSize: '18px', color: '#2ecc71', align: 'center',
      wordWrap: { width: 520 },
    }).setOrigin(0.5)
    this.contentContainer.add(meaningText)
    y += 50

    const nLevel = word.difficulty ? `N${word.difficulty}` : '—'
    const metaText = this.add.text(GAME_CONFIG.width / 2, y, `Level: ${nLevel} · Frequency: ${word.usage_frequency ?? '—'}`, {
      ...FONTS.default, fontSize: '14px', color: '#95a5a6',
    }).setOrigin(0.5)
    this.contentContainer.add(metaText)
    y += 36

    if (word.example_reading || word.example_meaning) {
      const example = `"${word.example_reading || ''}" — ${word.example_meaning || ''}`
      const exampleText = this.add.text(GAME_CONFIG.width / 2, y, example, {
        ...FONTS.default, fontSize: '13px', color: '#bdc3c7', align: 'center',
        wordWrap: { width: 520 },
      }).setOrigin(0.5)
      this.contentContainer.add(exampleText)
    }

    const nextLabel = this.currentWordIndex < this.selectedWords.length - 1 ? 'NEXT WORD' : 'START TEST'
    this.addContinueButton(GAME_CONFIG.height - 60, () => {
      if (this.currentWordIndex < this.selectedWords.length - 1) {
        this.currentWordIndex++
        this.showWordIntro()
      } else {
        this.currentWordIndex = 0
        this.showTest()
      }
    }, nextLabel)
  }

  showTest() {
    this.clearContent()
    const word = this.selectedWords[this.currentWordIndex]

    const title = this.add.text(GAME_CONFIG.width / 2, 40, `Question ${this.currentWordIndex + 1}/${this.selectedWords.length}`, {
      ...FONTS.title, fontSize: '24px', color: '#f1c40f',
    }).setOrigin(0.5)
    this.contentContainer.add(title)

    const prompt = this.add.text(GAME_CONFIG.width / 2, 110, `What does "${word.word}" mean?`, {
      ...FONTS.default, fontSize: '20px', color: '#ecf0f1', align: 'center',
      wordWrap: { width: 520 },
    }).setOrigin(0.5)
    this.contentContainer.add(prompt)

    const reading = this.add.text(GAME_CONFIG.width / 2, 150, word.reading || '', {
      ...FONTS.default, fontSize: '16px', color: '#bdc3c7',
    }).setOrigin(0.5)
    this.contentContainer.add(reading)

    const options = this.buildOptions(word)
    const startY = 210
    const btnH = 46
    const gap = 12
    options.forEach((option, i) => {
      const y = startY + i * (btnH + gap)
      this.addOptionButton(GAME_CONFIG.width / 2, y, option.meaning, () => this.handleAnswer(word, option.correct))
    })
  }

  buildOptions(correctWord) {
    const known = this.player.getKnownWordList?.() || this.player.wordList || []
    const distractors = shuffle(known.filter(w => w.meaning && w.meaning !== correctWord.meaning)).slice(0, 3)
    while (distractors.length < 3) {
      distractors.push({ meaning: `Choice ${distractors.length + 1}` })
    }
    return shuffle([{ meaning: correctWord.meaning, correct: true }, ...distractors.map(w => ({ meaning: w.meaning, correct: false }))])
  }

  handleAnswer(word, correct) {
    if (correct) {
      this.player.addBeingLearnedWord(word)
      this.player.addOuroEssence(1)
      const rewardText = this.grantReward()
      this.results.push({ word: word.word, correct: true, reward: rewardText })
      this.showFeedback(true, `+1 Ouro Essence · ${rewardText}`)
    } else {
      this.player.hp = Math.max(0, this.player.hp - 4)
      this.results.push({ word: word.word, correct: false, damage: 4 })
      if (this.player.hp <= 0) {
        this.showDefeat()
      } else {
        this.showFeedback(false, '-4 HP')
      }
    }
  }

  grantReward() {
    const roll = Math.random()
    if (roll < 0.5) {
      this.player.loadout.gold = (this.player.loadout.gold || 0) + 50
      this.player.saveLoadout()
      return '+50 Gold'
    }
    if (roll < 0.7) {
      const pool = CHARMS.filter(c => c.type === CHARM_TYPES.HERO)
      const charm = pool[Math.floor(Math.random() * pool.length)]
      if (charm) this.player.addCharm(charm.id)
      return charm ? `Hero charm: ${charm.name}` : 'Hero charm'
    }
    if (roll < 0.8) {
      const pool = ALL_SOCKET_CHARMS.filter(c => c.equipmentType === 'primary_weapon')
      const charm = pool[Math.floor(Math.random() * pool.length)]
      if (charm) {
        if (!this.player.loadout.ownedSocketCharmIds) this.player.loadout.ownedSocketCharmIds = []
        if (!this.player.loadout.ownedSocketCharmIds.includes(charm.id)) {
          this.player.loadout.ownedSocketCharmIds.push(charm.id)
        }
        this.player.saveLoadout()
      }
      return charm ? `Weapon charm: ${charm.name}` : 'Weapon charm'
    }
    if (roll < 0.9) {
      const pool = getRewardPool(this.player)
      const ids = pickRewardAbilities(pool, 1, this.player.loadout.knownActionIds || [], this.tile)
      if (ids.length > 0) {
        const result = this.player.learnAbility(ids[0])
        if (result.ok) return `Ability: ${result.action?.name || ids[0]}`
      }
      this.player.loadout.gold = (this.player.loadout.gold || 0) + 25
      this.player.saveLoadout()
      return 'Ability slot full — +25 Gold'
    }
    const item1 = ITEMS[Math.floor(Math.random() * ITEMS.length)]
    const item2 = ITEMS[Math.floor(Math.random() * ITEMS.length)]
    this.player.addItem(item1.id, 1)
    this.player.addItem(item2.id, 1)
    return `Items: ${item1.name} + ${item2.name}`
  }

  showFeedback(correct, detail) {
    this.clearContent()
    const color = correct ? '#2ecc71' : '#e74c3c'
    const title = this.add.text(GAME_CONFIG.width / 2, 160, correct ? 'Correct!' : 'Wrong!', {
      ...FONTS.title, fontSize: '32px', color,
    }).setOrigin(0.5)
    this.contentContainer.add(title)

    const detailText = this.add.text(GAME_CONFIG.width / 2, 220, detail, {
      ...FONTS.default, fontSize: '18px', color: '#ecf0f1', align: 'center',
      wordWrap: { width: 520 },
    }).setOrigin(0.5)
    this.contentContainer.add(detailText)

    this.time.delayedCall(1200, () => {
      if (this.currentWordIndex < this.selectedWords.length - 1) {
        this.currentWordIndex++
        this.showTest()
      } else {
        this.showSummary()
      }
    })
  }

  showDefeat() {
    this.clearContent()
    const title = this.add.text(GAME_CONFIG.width / 2, 160, 'Defeat...', {
      ...FONTS.title, fontSize: '32px', color: '#e74c3c',
    }).setOrigin(0.5)
    this.contentContainer.add(title)

    const msg = this.add.text(GAME_CONFIG.width / 2, 220, 'The memory was too much to bear.', {
      ...FONTS.default, fontSize: '16px', color: '#ecf0f1', align: 'center',
      wordWrap: { width: 520 },
    }).setOrigin(0.5)
    this.contentContainer.add(msg)

    this.player.saveLoadout()
    this.time.delayedCall(1800, () => {
      // Report the ended run to the site (daily challenge, learned words, kanji).
      this.player.persistRunProgress('enemy')
      this.player.endRun(false)
      this.scene.start('HeroSelectScene', { player: this.player })
    })
  }

  showSummary() {
    this.clearContent()
    const title = this.add.text(GAME_CONFIG.width / 2, 60, 'Memory Recovered', {
      ...FONTS.title, fontSize: '28px', color: '#f1c40f',
    }).setOrigin(0.5)
    this.contentContainer.add(title)

    const correctCount = this.results.filter(r => r.correct).length
    const summary = this.add.text(GAME_CONFIG.width / 2, 110, `${correctCount}/${this.results.length} words learned`, {
      ...FONTS.default, fontSize: '18px', color: '#ecf0f1',
    }).setOrigin(0.5)
    this.contentContainer.add(summary)

    let y = 160
    for (const result of this.results) {
      const line = `${result.correct ? '✓' : '✗'} ${result.word} — ${result.correct ? result.reward : `-${result.damage} HP`}`
      const text = this.add.text(GAME_CONFIG.width / 2, y, line, {
        ...FONTS.default, fontSize: '14px', color: result.correct ? '#2ecc71' : '#e74c3c',
      }).setOrigin(0.5)
      this.contentContainer.add(text)
      y += 28
    }

    this.addContinueButton(GAME_CONFIG.height - 70, () => this.returnToMap())
  }

  returnToMap() {
    if (this.tile?.id) {
      this.player.completeTile(this.tile.id)
    }
    this.player.saveLoadout()
    this.scene.start('MapScene', { player: this.player, mapIndex: this.mapIndex })
  }

  addContinueButton(y, onClick, label = 'CONTINUE') {
    const w = 180
    const h = 44
    const x = GAME_CONFIG.width / 2
    const bg = this.add.rectangle(x, y, w, h, 0x2980b9).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(x, y, label, {
      ...FONTS.default, fontSize: '16px', color: '#ffffff', fontStyle: 'bold',
    }).setOrigin(0.5)
    bg.on('pointerover', () => bg.setFillStyle(0x3498db))
    bg.on('pointerout', () => bg.setFillStyle(0x2980b9))
    bg.on('pointerdown', onClick)
    this.contentContainer.add(bg)
    this.contentContainer.add(text)
  }

  addOptionButton(x, y, label, onClick) {
    const w = 420
    const h = 46
    const bg = this.add.rectangle(x, y, w, h, 0x2c3e50).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const text = this.add.text(x, y, label, {
      ...FONTS.default, fontSize: '15px', color: '#ecf0f1', align: 'center',
      wordWrap: { width: w - 20 },
    }).setOrigin(0.5)
    bg.on('pointerover', () => bg.setFillStyle(0x34495e))
    bg.on('pointerout', () => bg.setFillStyle(0x2c3e50))
    bg.on('pointerdown', onClick)
    this.contentContainer.add(bg)
    this.contentContainer.add(text)
  }
}
