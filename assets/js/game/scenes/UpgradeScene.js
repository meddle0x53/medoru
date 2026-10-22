import { GAME_CONFIG, FONTS } from '../config.js'
import { setupHighDPIWorld } from '../highDpi.js'
import { generateChoices } from '../systems/UpgradeGenerator.js'
import { apply, countUpgrade } from '../systems/UpgradeEngine.js'
import { getAbilityRarityColor } from '../data/actions.js'
import WinChallengeSystem from '../systems/WinChallengeSystem.js'

const TIER_LABELS = { common: 'Common', uncommon: 'Uncommon', rare: 'Rare', epic: 'Epic' }

/**
 * 3-card upgrade reward screen (Phases 3 + D12 revision).
 *
 * The screen's tier arrives via init data: a triggered roll (D12) passes its
 * tier after player.useRoll() consumed it; battle drops pass the tier rolled
 * by player.rollBattleRewardTier() (revised D4 — every win drops a screen).
 * Cards come from UpgradeGenerator at that tier; an optional kanji reroll
 * (1 per screen) regenerates at the SAME tier on pass and keeps the cards on
 * fail (D9). Choosing a card applies it via UpgradeEngine and returns to the
 * caller's scene.
 *
 * Decision logic lives in small methods (resolveTier / rollCards / reroll /
 * chooseCard) so it stays testable headless; rendering follows the existing
 * card patterns (see WinScene.createAbilityCard).
 */
export default class UpgradeScene extends Phaser.Scene {
  constructor() {
    super({ key: 'UpgradeScene' })
  }

  init(data) {
    this.player = data.player
    this.returnScene = data.returnScene || 'MapScene'
    this.returnData = data.returnData || null
    this.mapIndex = data.mapIndex ?? 0
    // The screen's tier comes from the caller (D12): a triggered roll passes
    // its tier; battle drops roll it via player.rollBattleRewardTier().
    this.tier = data.tier || 'common'
    this.rerollsLeft = 1
    this.challengeSystem = null
    this.cards = []
    this.chosen = false
  }

  create() {
    setupHighDPIWorld(this)
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x0f1525)

    this.cards = this.rollCards()
    if (this.cards.length === 0) {
      // Pool exhausted: skip cleanly back without a reward screen.
      this.exit()
      return
    }

    this.add.text(GAME_CONFIG.width / 2, 46, 'Choose an Upgrade', {
      ...FONTS.title,
      fontSize: '30px',
      color: '#f1c40f',
    }).setOrigin(0.5)

    const tierLabel = TIER_LABELS[this.tier] || 'Common'
    this.add.text(GAME_CONFIG.width / 2, 82, `Roll: ${tierLabel}`, {
      ...FONTS.default,
      fontSize: '15px',
      color: '#95a5a6',
    }).setOrigin(0.5)

    this.renderCards()

    this.rerollButton = this.createButton(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height - 96,
      `[REROLL — KANJI] (${this.rerollsLeft})`,
      () => this.startReroll(),
      260, 42, 0x8e44ad, 0x9b59b6
    )
  }

  shutdown() {
    if (this.challengeSystem) {
      this.challengeSystem.destroy()
      this.challengeSystem = null
    }
  }

  // ---------- Decision logic (headless-testable) ----------

  resolveTier() {
    return this.tier || 'common'
  }

  rollCards() {
    return generateChoices(this.player, this.tier || 'common')
  }

  // Apply the reroll outcome: pass regenerates at the same tier, fail keeps
  // the current cards. Returns { regenerated }.
  rerollOutcome(passed) {
    if (!passed) return { regenerated: false }
    this.cards = this.rollCards()
    return { regenerated: true }
  }

  chooseCard(card) {
    if (this.chosen) return { ok: false, reason: 'Already chosen.' }
    const result = apply(this.player, card.id)
    if (!result.ok) return result
    this.chosen = true
    return { ok: true, card, result }
  }

  exit() {
    this.scene.start(this.returnScene, this.returnData || { player: this.player, mapIndex: this.mapIndex })
  }

  // ---------- Rendering ----------

  renderCards() {
    if (this.cardContainer) this.cardContainer.destroy()
    this.cardContainer = this.add.container(0, 0)

    const cardW = 200
    const cardH = 220
    const gap = 24
    const totalW = this.cards.length * cardW + (this.cards.length - 1) * gap
    const startX = (GAME_CONFIG.width - totalW) / 2 + cardW / 2
    const y = GAME_CONFIG.height / 2 - 10

    this.cards.forEach((card, i) => {
      const x = startX + i * (cardW + gap)
      this.cardContainer.add(this.createCard(x, y, cardW, cardH, card))
    })
  }

  createCard(x, y, w, h, card) {
    const container = this.add.container(x, y)
    const colors = getAbilityRarityColor(card.rarity)

    const bg = this.add.graphics()
    bg.fillStyle(0x16213e, 0.95)
    bg.fillRoundedRect(-w / 2, -h / 2, w, h, 10)
    bg.lineStyle(2, colors.main, 0.9)
    bg.strokeRoundedRect(-w / 2, -h / 2, w, h, 10)
    container.add(bg)

    container.add(this.add.text(0, -h / 2 + 26, card.nameJa || '', {
      fontFamily: FONTS.kanji.fontFamily,
      fontSize: '22px',
      color: '#ffffff',
    }).setOrigin(0.5))

    container.add(this.add.text(0, -h / 2 + 58, card.name, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
    }).setOrigin(0.5))

    container.add(this.add.text(0, -h / 2 + 78, card.rarity || 'common', {
      ...FONTS.default,
      fontSize: '11px',
      color: '#' + colors.main.toString(16).padStart(6, '0'),
    }).setOrigin(0.5))

    container.add(this.add.text(0, 6, card.description || '', {
      ...FONTS.default,
      fontSize: '12px',
      color: '#bdc3c7',
      align: 'center',
      wordWrap: { width: w - 24 },
    }).setOrigin(0.5))

    const owned = countUpgrade(this.player, card.id)
    const maxStacks = card.maxStacks || 1
    if (maxStacks > 1) {
      container.add(this.add.text(0, h / 2 - 20, `Owned ${owned}/${maxStacks}`, {
        ...FONTS.default,
        fontSize: '10px',
        color: '#7f8c8d',
      }).setOrigin(0.5))
    }

    const hitArea = this.add.rectangle(0, 0, w, h, 0x000000, 0)
      .setInteractive({ useHandCursor: true })
      .on('pointerover', () => bg.setAlpha(1))
      .on('pointerout', () => bg.setAlpha(0.95))
      .on('pointerdown', () => this.onCardChosen(card))
    container.add(hitArea)

    return container
  }

  onCardChosen(card) {
    const result = this.chooseCard(card)
    if (!result.ok) {
      this.showToast(result.reason || 'Cannot apply this upgrade')
      return
    }
    this.cardContainer?.setVisible(false)
    this.rerollButton?.hitArea.disableInteractive()
    this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, `${card.name} acquired!`, {
      ...FONTS.title,
      fontSize: '24px',
      color: '#2ecc71',
    }).setOrigin(0.5)
    this.time.delayedCall(1100, () => this.exit())
  }

  // ---------- Reroll ----------

  startReroll() {
    if (this.rerollsLeft <= 0 || this.chosen) return
    this.rerollsLeft--
    this.rerollButton.text.setText(`[REROLL — KANJI] (${this.rerollsLeft})`)
    if (this.rerollsLeft <= 0) this.rerollButton.hitArea.disableInteractive()
    this.rerollButton.text.setText('Drawing kanji...')

    this.challengeSystem = new WinChallengeSystem(this, this.player)
    this.challengeSystem.runPassFail(
      () => {
        const { regenerated } = this.rerollOutcome(true)
        this.challengeSystem?.destroy()
        this.challengeSystem = null
        if (regenerated) this.renderCards()
        this.updateRerollLabel()
      },
      () => {
        this.challengeSystem?.destroy()
        this.challengeSystem = null
        this.updateRerollLabel()
      }
    )
  }

  updateRerollLabel() {
    if (!this.rerollButton) return
    this.rerollButton.text.setText(`[REROLL — KANJI] (${this.rerollsLeft})`)
  }

  // ---------- Helpers ----------

  createButton(x, y, label, onClick, width = 160, height = 40, color = 0x3498db, hoverColor = 0x2980b9) {
    const bg = this.add.graphics()
    bg.fillStyle(color, 0.95)
    bg.fillRoundedRect(x - width / 2, y - height / 2, width, height, 8)

    const text = this.add.text(x, y, label, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ffffff',
    }).setOrigin(0.5)

    const hitArea = this.add.rectangle(x, y, width, height, 0x000000, 0)
      .setInteractive({ useHandCursor: true })
      .on('pointerover', () => bg.setFillStyle(hoverColor, 0.95))
      .on('pointerout', () => bg.setFillStyle(color, 0.95))
      .on('pointerdown', onClick)

    return { bg, text, hitArea }
  }

  showToast(message) {
    const toast = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 40, message, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ffffff',
      backgroundColor: '#e74c3c',
    }).setOrigin(0.5).setDepth(400)

    this.tweens.add({
      targets: toast,
      y: toast.y - 30,
      alpha: 0,
      duration: 1200,
      ease: 'Quad.easeOut',
      onComplete: () => toast.destroy(),
    })
  }
}
