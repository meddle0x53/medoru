import { GAME_CONFIG, FONTS } from '../config.js'
import Player, { getUpgradeCost } from '../entities/Player.js'
import { getWindowGameData } from '../api.js'

const HEROES = [
  {
    id: 'warrior',
    name: 'Warrior',
    nameJa: '戦士',
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
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x1a1a2e)
  }

  createTitle() {
    this.add.text(GAME_CONFIG.width / 2, 50, 'Choose Your Hero', {
      ...FONTS.title,
      fontSize: '32px',
      color: '#f1c40f',
    }).setOrigin(0.5)
  }

  createHeroCards() {
    const startX = GAME_CONFIG.width / 2
    const startY = GAME_CONFIG.height / 2

    HEROES.forEach((hero, index) => {
      const x = startX + (index - HEROES.length / 2 + 0.5) * 240
      const card = this.add.container(x, startY)

      const bg = this.add.rectangle(0, 0, 200, 260, 0x16213e).setStrokeStyle(2, 0x3498db).setOrigin(0.5)
      const portrait = this.add.circle(0, -60, 50, hero.color)
      const icon = this.add.text(0, -60, '⚔️', { fontSize: '40px' }).setOrigin(0.5)
      const name = this.add.text(0, 20, hero.name, {
        ...FONTS.default,
        fontSize: '20px',
        color: '#ecf0f1',
      }).setOrigin(0.5)
      const desc = this.add.text(0, 70, hero.description, {
        ...FONTS.default,
        fontSize: '12px',
        color: '#bdc3c7',
        align: 'center',
        wordWrap: { width: 170 },
      }).setOrigin(0.5)

      const btn = this.add.rectangle(0, 130, 160, 40, 0x27ae60).setInteractive({ useHandCursor: true }).setOrigin(0.5)
      const btnText = this.add.text(0, 130, 'Start Journey', {
        ...FONTS.default,
        fontSize: '14px',
        color: '#ffffff',
      }).setOrigin(0.5)

      btn.on('pointerdown', () => this.selectHero(hero))
      btn.on('pointerover', () => btn.setFillStyle(0x2ecc71))
      btn.on('pointerout', () => btn.setFillStyle(0x27ae60))

      card.add([bg, portrait, icon, name, desc, btn, btnText])
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

    if (player.getCurrentMap()) {
      this.scene.start('MapScene', { player })
    } else {
      this.scene.start('LoadoutScene', { player, mode: 'map', returnScene: 'MapScene' })
    }
  }
}
