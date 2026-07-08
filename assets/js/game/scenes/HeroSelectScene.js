import { GAME_CONFIG, FONTS } from '../config.js'
import Player, { getUpgradeCost } from '../entities/Player.js'
import { getWindowGameData } from '../api.js'

const HEROES = [
  {
    id: 'warrior',
    name: 'The Anomaly',
    nameJa: '異常存在',
    description: 'A balanced fighter with sword and shield.',
    color: 0xc0392b,
  },
]

export default class HeroSelectScene extends Phaser.Scene {
  constructor() {
    super({ key: 'HeroSelectScene' })
  }

  create() {
    this.createBackground()
    this.createTitle()
    this.createHeroCards()
  }

  createBackground() {
    this.add.image(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, 'hero_select_background')
      .setOrigin(0.5)
      .setDisplaySize(GAME_CONFIG.width, GAME_CONFIG.height)
  }

  createTitle() {
    // Darken the top area so the title stays readable over the bright artwork.
    this.add.rectangle(GAME_CONFIG.width / 2, 50, GAME_CONFIG.width, 90, 0x000000, 0.45)

    this.add.text(GAME_CONFIG.width / 2, 50, 'Choose Your Hero', {
      ...FONTS.title,
      fontSize: '32px',
      color: '#f1c40f',
    }).setOrigin(0.5)
  }

  createHeroCards() {
    const startX = GAME_CONFIG.width / 2
    const startY = GAME_CONFIG.height / 2 + 20
    const cardWidth = 220
    const cardHeight = 330
    const overlayHeight = 120

    HEROES.forEach((hero, index) => {
      const x = startX + (index - HEROES.length / 2 + 0.5) * 280
      const card = this.add.container(x, startY)

      // The portrait fills the entire selectable rectangle.
      const portrait = this.add.image(0, 0, 'hero_portrait')
        .setDisplaySize(cardWidth, cardHeight)
        .setOrigin(0.5)
        .setInteractive({ useHandCursor: true })

      // Subtle border.
      const border = this.add.rectangle(0, 0, cardWidth + 4, cardHeight + 4, 0x000000, 0)
        .setStrokeStyle(2, 0xf1c40f)
        .setOrigin(0.5)

      // Dark overlay at the bottom for text readability.
      const overlay = this.add.rectangle(
        0,
        cardHeight / 2 - overlayHeight / 2,
        cardWidth,
        overlayHeight,
        0x000000,
        0.65,
      ).setOrigin(0.5)

      const name = this.add.text(0, cardHeight / 2 - overlayHeight + 30, hero.name, {
        ...FONTS.default,
        fontSize: '22px',
        color: '#f1c40f',
      }).setOrigin(0.5)

      const desc = this.add.text(0, cardHeight / 2 - overlayHeight + 62, hero.description, {
        ...FONTS.default,
        fontSize: '12px',
        color: '#ecf0f1',
        align: 'center',
        wordWrap: { width: cardWidth - 20 },
      }).setOrigin(0.5)

      const hint = this.add.text(0, cardHeight / 2 - overlayHeight + 92, 'Click to begin', {
        ...FONTS.default,
        fontSize: '12px',
        color: '#bdc3c7',
      }).setOrigin(0.5)

      portrait.on('pointerover', () => portrait.setTint(0xdddddd))
      portrait.on('pointerout', () => portrait.clearTint())
      portrait.on('pointerdown', () => this.selectHero(hero))

      card.add([portrait, border, overlay, name, desc, hint])
    })
  }

  selectHero(hero) {
    const userData = getWindowGameData()
    const player = new Player(userData)

    // Only start a fresh run if there is no saved map in progress.
    // Refreshing the page should resume at the current map tile.
    if (!player.getCurrentMap()) {
      player.resetToFreshHero()
    }

    const returnScene = player.getCurrentMap() ? 'MapScene' : 'LoadoutScene'
    this.scene.start('KanjiLibraryScene', { player, returnScene })
  }
}
