import { GAME_CONFIG, COLORS, FONTS } from '../config.js'
import WordChallengeSystem from '../systems/WordChallengeSystem.js'
import { ITEMS } from '../data/items.js'
import { CHARMS, getCharmsByType, getCharmById } from '../data/charms.js'
import { getRewardPool, pickRewardAbilities } from '../data/abilityRewards.js'
import { ALL_ACTIONS } from '../data/actions.js'
import { setupHighDPIWorld } from '../highDpi.js'

const GRID_COLS = 5
const GRID_ROWS = 4
const CARD_W = 90
const CARD_H = 100
const GAP_X = 10
const GAP_Y = 10

function getMaxAttempts(luck = 0) {
  if (luck >= 100) return 15
  if (luck >= 90) return 12
  if (luck >= 70) return 11
  if (luck >= 50) return 10
  if (luck >= 35) return 9
  if (luck >= 25) return 8
  if (luck >= 15) return 7
  if (luck >= 10) return 6
  return 5
}

const RARITY_WEIGHTS = {
  common: 5,
  uncommon: 3,
  rare: 1,
  normal: 5,
}

function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min
}

function shuffle(array) {
  const arr = [...array]
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[arr[i], arr[j]] = [arr[j], arr[i]]
  }
  return arr
}

function weightedPick(array, weightFn = (item) => RARITY_WEIGHTS[item.rarity] || 1) {
  if (!array || array.length === 0) return null
  const weights = array.map(weightFn)
  const total = weights.reduce((a, b) => a + b, 0)
  if (total <= 0) return array[Math.floor(Math.random() * array.length)]
  let roll = Math.random() * total
  for (let i = 0; i < array.length; i++) {
    roll -= weights[i]
    if (roll <= 0) return array[i]
  }
  return array[array.length - 1]
}

/**
 * Memories! map event — a memory-card mini-game built from the player's
 * learned words. Match pairs, then type the meaning to claim the card and
 * earn a part-of-speech based reward.
 */
export default class MemoryScene extends Phaser.Scene {
  constructor() {
    super({ key: 'MemoryScene' })
  }

  init(data) {
    this.player = data.player
    this.tile = data.tile
    this.mapIndex = data.mapIndex
    this.returnScene = data.returnScene || 'MapScene'
    this.skipCompleteTile = data.skipCompleteTile || false

    this.cards = []
    this.flippedCards = []
    this.inputLocked = false
    this.matchedPairs = 0
    this.totalPairs = 10
    this.wrongAttempts = 0
    this.maxAttempts = getMaxAttempts(this.player?.luck || 0)
    this.rewards = []
    this.challenge = null
    this.overlay = null
    this.rewardPanel = null
    this.attemptsText = null
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()
    this.createHeader()

    this.challenge = new WordChallengeSystem(this, {
      title: 'Memories!',
      promptForMeaning: 'Type the meaning of this word to claim the pair:',
      timeLimit: 20000,
      hangOnWrong: 1200,
      hangOnCorrect: 800,
      showCorrectAnswer: false,
    })

    const words = this.selectWords()
    if (!words) return

    this.createGrid(words)
    this.createRewardPanel()
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createHeader() {
    this.add.text(GAME_CONFIG.width / 2, 28, 'Memories!', {
      ...FONTS.title,
      fontSize: '28px',
      color: '#f39c12',
    }).setOrigin(0.5)

    this.attemptsText = this.add.text(GAME_CONFIG.width - 20, 24, this.attemptsLabel(), {
      ...FONTS.default,
      fontSize: '14px',
      color: '#e74c3c',
    }).setOrigin(1, 0)

    this.add.text(20, 24, 'Match pairs, then type the meaning.', {
      ...FONTS.default,
      fontSize: '13px',
      color: '#bdc3c7',
    })
  }

  attemptsLabel() {
    return `Wrong: ${this.wrongAttempts}/${this.maxAttempts}`
  }

  updateAttemptsText() {
    if (this.attemptsText) {
      this.attemptsText.setText(this.attemptsLabel())
    }
  }

  selectWords() {
    const list = this.player?.wordList || []
    if (list.length < this.totalPairs) {
      this.showNoWordsOverlay()
      return null
    }
    return shuffle(list).slice(0, this.totalPairs)
  }

  createGrid(words) {
    const pairs = shuffle([...words, ...words])
    const gridW = GRID_COLS * CARD_W + (GRID_COLS - 1) * GAP_X
    const startX = (GAME_CONFIG.width - gridW) / 2 + CARD_W / 2
    const startY = 63 + CARD_H / 2

    pairs.forEach((word, i) => {
      const col = i % GRID_COLS
      const row = Math.floor(i / GRID_COLS)
      const x = startX + col * (CARD_W + GAP_X)
      const y = startY + row * (CARD_H + GAP_Y)
      this.cards.push(this.createCard(x, y, word))
    })
  }

  createCard(x, y, word) {
    const container = this.add.container(x, y)
    container.setSize(CARD_W, CARD_H)

    const bg = this.add.rectangle(0, 0, CARD_W, CARD_H, 0x3498db).setStrokeStyle(2, 0x2980b9)
    const qText = this.add.text(0, 0, '?', {
      fontFamily: 'Arial',
      fontSize: '28px',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5)

    const hitArea = this.add.rectangle(0, 0, CARD_W, CARD_H, 0x000000, 0).setInteractive({ useHandCursor: true })
    container.add([bg, qText, hitArea])

    const card = {
      container,
      word,
      bg,
      qText,
      hitArea,
      frontText: null,
      readingText: null,
      faceUp: false,
      matched: false,
    }
    container.card = card

    hitArea.on('pointerdown', () => this.onCardClick(card))
    hitArea.on('pointerover', () => bg.setStrokeStyle(3, 0xf1c40f))
    hitArea.on('pointerout', () => bg.setStrokeStyle(2, 0x2980b9))

    return card
  }

  onCardClick(card) {
    if (this.inputLocked || card.faceUp || card.matched || this.flippedCards.length >= 2) return
    this.flipCard(card)
    this.flippedCards.push(card)

    if (this.flippedCards.length === 2) {
      this.inputLocked = true
      this.time.delayedCall(500, () => this.checkMatch())
    }
  }

  flipCard(card) {
    this.tweens.add({
      targets: card.container,
      scaleX: 0,
      duration: 120,
      onComplete: () => {
        card.faceUp = !card.faceUp
        if (card.faceUp) {
          card.bg.setFillStyle(0x1e3a28)
          card.qText.setVisible(false)
          if (!card.frontText) {
            card.frontText = this.add.text(0, -10, card.word.word, {
              ...FONTS.kanji,
              fontSize: '24px',
              color: '#fff0f3',
            }).setOrigin(0.5)
            card.readingText = this.add.text(0, 22, card.word.reading || '', {
              ...FONTS.default,
              fontSize: '14px',
              color: '#ffcce0',
            }).setOrigin(0.5)
            card.container.add([card.frontText, card.readingText])
          }
          card.frontText.setVisible(true)
          card.frontText.setColor('#fff0f3')
          card.readingText.setVisible(true)
          card.readingText.setColor('#ffcce0')
        } else {
          card.bg.setFillStyle(0x3498db)
          card.qText.setVisible(true)
          if (card.frontText) card.frontText.setVisible(false)
          if (card.readingText) card.readingText.setVisible(false)
        }
        this.tweens.add({ targets: card.container, scaleX: 1, duration: 120 })
      },
    })
  }

  checkMatch() {
    const [a, b] = this.flippedCards
    if (a.word.word === b.word.word) {
      this.startMeaningChallenge(a.word)
    } else {
      this.wrongAttempts++
      this.updateAttemptsText()
      this.time.delayedCall(600, () => {
        this.flipCard(a)
        this.flipCard(b)
        this.flippedCards = []

        if (this.wrongAttempts >= this.maxAttempts) {
          this.showGameOver(false)
        } else {
          this.inputLocked = false
        }
      })
    }
  }

  startMeaningChallenge(word) {
    this.inputLocked = true
    this.challenge.start(word, {
      promptType: 'meaning',
      onComplete: ({ success }) => this.handleChallengeResult(success),
    })
  }

  handleChallengeResult(success) {
    const [a, b] = this.flippedCards

    if (success) {
      a.matched = true
      b.matched = true
      a.bg.setFillStyle(0x2d6a4f)
      b.bg.setFillStyle(0x2d6a4f)
      if (a.hitArea) a.hitArea.disableInteractive()
      if (b.hitArea) b.hitArea.disableInteractive()
      this.matchedPairs++

      const reward = this.generateReward(a.word)
      this.applyReward(reward)
      this.rewards.push(reward)
      this.showRewardOverlay(reward)
    } else {
      this.wrongAttempts++
      this.updateAttemptsText()
      this.time.delayedCall(500, () => {
        this.flipCard(a)
        this.flipCard(b)
      })

      if (this.wrongAttempts >= this.maxAttempts) {
        this.time.delayedCall(1500, () => this.showGameOver(false))
      } else {
        this.flippedCards = []
        this.inputLocked = false
      }
    }
  }

  generateReward(word) {
    const pos = word.word_type || this.inferWordType(word)
    const baseGold = randInt(10, 30)
    const reward = {
      gold: baseGold,
      items: [],
      charms: [],
      abilities: [],
      messages: [`+${baseGold} gold`],
    }

    switch (pos) {
      case 'verb': {
        const ability = this.pickUnknownAbility()
        if (ability) {
          reward.abilities.push(ability)
          reward.messages.push(`Learned ${ability.name}`)
        } else {
          const bonus = randInt(20, 50)
          reward.gold += bonus
          reward.messages.push(`+${bonus} gold`)
        }
        break
      }
      case 'noun': {
        const count = randInt(1, 3)
        for (let i = 0; i < count; i++) {
          const item = weightedPick(ITEMS)
          if (item) reward.items.push(item)
        }
        if (reward.items.length > 0) {
          reward.messages.push(`${count} item${count > 1 ? 's' : ''}`)
        }
        break
      }
      case 'adjective': {
        const type = Math.random() < 0.2 ? 'hero' : 'weapon'
        const pool = getCharmsByType(type)
        const charm = weightedPick(pool)
        if (charm) {
          reward.charms.push(charm)
          reward.messages.push(charm.name)
        }
        break
      }
      default: {
        const category = weightedPick([
          { value: 'gold', weight: 40 },
          { value: 'items', weight: 30 },
          { value: 'charm', weight: 20 },
          { value: 'ability', weight: 10 },
        ], (item) => item.weight).value

        if (category === 'gold') {
          const bonus = randInt(5, 25)
          reward.gold += bonus
          reward.messages.push(`+${bonus} gold`)
        } else if (category === 'items') {
          const item = weightedPick(ITEMS)
          if (item) {
            reward.items.push(item)
            reward.messages.push(item.name)
          }
        } else if (category === 'charm') {
          const charm = weightedPick(CHARMS)
          if (charm) {
            reward.charms.push(charm)
            reward.messages.push(charm.name)
          }
        } else if (category === 'ability') {
          const ability = this.pickUnknownAbility()
          if (ability) {
            reward.abilities.push(ability)
            reward.messages.push(`Learned ${ability.name}`)
          } else {
            const bonus = randInt(10, 30)
            reward.gold += bonus
            reward.messages.push(`+${bonus} gold`)
          }
        }
        break
      }
    }

    return reward
  }

  inferWordType(word) {
    // Prefer the explicit type from the server if it exists.
    if (word.word_type && typeof word.word_type === 'string') {
      return word.word_type
    }

    const reading = (word.reading || '').toLowerCase()
    const text = (word.word || '').toLowerCase()
    const lastKana = reading.slice(-1) || text.slice(-1)

    // Common dictionary-form verb endings (godan + ichidan).
    const verbEndings = new Set(['う', 'く', 'す', 'つ', 'ぬ', 'ふ', 'む', 'る', 'ぐ', 'ぶ'])
    if (verbEndings.has(lastKana)) return 'verb'
    if (lastKana === 'い') return 'adjective'
    if (/^\d+$/.test(text)) return 'counter'
    return 'noun'
  }

  pickUnknownAbility() {
    const combatCount = this.player.countCombatAbilities()
    if (combatCount >= 10) return null

    const pool = getRewardPool(this.player)
    const picks = pickRewardAbilities(pool, 1, this.player.loadout?.knownActionIds || [], this.tile)
    if (!picks || picks.length === 0) return null

    const action = ALL_ACTIONS.find((a) => a.id === picks[0])
    if (!action || this.player.hasAbility(action.id)) return null
    return action
  }

  applyReward(reward) {
    if (reward.gold > 0) this.player.addGold(reward.gold)
    for (const item of reward.items) {
      this.player.addItem(item.id, 1)
    }
    for (const charm of reward.charms) {
      this.player.addCharm(charm.id)
    }
    for (const ability of reward.abilities) {
      this.player.learnAbility(ability.id)
    }
    this.player.saveLoadout()
  }

  createRewardPanel() {
    this.rewardPanel = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height - 20)
    const bg = this.add.rectangle(0, 0, GAME_CONFIG.width - 40, 28, 0x000000, 0.5).setStrokeStyle(1, 0x7f8c8d)
    this.rewardPanel.add(bg)
    this.rewardPanelText = this.add.text(0, 0, 'Match pairs and type meanings to earn rewards.', {
      ...FONTS.default,
      fontSize: '12px',
      color: '#bdc3c7',
      align: 'center',
      wordWrap: { width: GAME_CONFIG.width - 60 },
    }).setOrigin(0.5)
    this.rewardPanel.add(this.rewardPanelText)
  }

  updateRewardPanel(text) {
    if (this.rewardPanelText) {
      this.rewardPanelText.setText(text)
    }
  }

  showRewardOverlay(reward) {
    this.inputLocked = true
    this.showOverlay({
      title: 'Pair Claimed!',
      color: 0x2ecc71,
      lines: reward.messages,
      button: 'Continue',
      onClick: () => {
        this.hideOverlay()
        this.updateRewardPanel(reward.messages.join('  •  '))
        this.flippedCards = []
        if (this.matchedPairs >= this.totalPairs) {
          this.showGameOver(true)
        } else {
          this.inputLocked = false
        }
      },
    })
  }

  showGameOver(won) {
    this.inputLocked = true
    const totalGold = this.rewards.reduce((sum, r) => sum + (r.gold || 0), 0)
    const totalItems = this.rewards.reduce((sum, r) => sum + (r.items?.length || 0), 0)
    const totalCharms = this.rewards.reduce((sum, r) => sum + (r.charms?.length || 0), 0)
    const totalAbilities = this.rewards.reduce((sum, r) => sum + (r.abilities?.length || 0), 0)

    const lines = []
    if (won) lines.push('All pairs remembered!')
    else lines.push('Too many wrong answers.')
    lines.push(`Gold earned: ${totalGold}`)
    if (totalItems > 0) lines.push(`Items found: ${totalItems}`)
    if (totalCharms > 0) lines.push(`Charms found: ${totalCharms}`)
    if (totalAbilities > 0) lines.push(`Abilities learned: ${totalAbilities}`)

    this.showOverlay({
      title: won ? 'Victory!' : 'Memories Faded',
      color: won ? 0x2ecc71 : 0xe74c3c,
      lines,
      button: 'Return to Map',
      onClick: () => {
        this.hideOverlay()
        this.completeTile()
      },
    })
  }

  showNoWordsOverlay() {
    this.inputLocked = true
    this.showOverlay({
      title: 'No Memories Yet',
      color: 0xf39c12,
      lines: ['Learn at least 10 words to unlock this event.'],
      button: 'Return to Map',
      onClick: () => {
        this.hideOverlay()
        this.completeTile()
      },
    })
  }

  showOverlay({ title, color, lines, button, onClick }) {
    this.hideOverlay()

    const overlay = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2)
    overlay.setDepth(300)

    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.85).setOrigin(0.5)
    overlay.add(backdrop)

    const panel = this.add.rectangle(0, 0, 420, 280, 0x1a1a2e).setStrokeStyle(2, color).setOrigin(0.5)
    overlay.add(panel)

    overlay.add(this.add.text(0, -100, title, {
      ...FONTS.title,
      fontSize: '22px',
      color: '#f39c12',
    }).setOrigin(0.5))

    const body = lines.join('\n')
    overlay.add(this.add.text(0, -20, body, {
      ...FONTS.default,
      fontSize: '15px',
      color: '#ecf0f1',
      align: 'center',
      wordWrap: { width: 360 },
    }).setOrigin(0.5))

    const buttonBg = this.add.rectangle(0, 90, 160, 44, color).setInteractive({ useHandCursor: true }).setOrigin(0.5)
    const buttonText = this.add.text(0, 90, button, {
      ...FONTS.default,
      fontSize: '16px',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5)
    buttonBg.on('pointerdown', onClick)
    buttonBg.on('pointerover', () => buttonBg.setFillStyle(lighten(color)))
    buttonBg.on('pointerout', () => buttonBg.setFillStyle(color))
    overlay.add(buttonBg)
    overlay.add(buttonText)

    this.overlay = overlay
  }

  hideOverlay() {
    if (this.overlay) {
      this.overlay.destroy()
      this.overlay = null
    }
  }

  completeTile() {
    if (this.tile?.id && !this.skipCompleteTile) {
      this.player.completeTile(this.tile.id)
    }
    this.player.saveLoadout()
    this.scene.start(this.returnScene, { player: this.player })
  }

  shutdown() {
    this.hideOverlay()
    if (this.challenge) {
      this.challenge.destroy()
      this.challenge = null
    }
  }
}

function lighten(color) {
  // Simple lightening for hover feedback.
  const r = (color >> 16) & 0xff
  const g = (color >> 8) & 0xff
  const b = color & 0xff
  const clamp = (v) => Math.min(255, Math.floor(v * 1.15))
  return (clamp(r) << 16) | (clamp(g) << 8) | clamp(b)
}
