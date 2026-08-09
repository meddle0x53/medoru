import { GAME_CONFIG, COLORS, FONTS } from '../config.js'
import { ALL_ACTIONS, getActionTypeColor, getAbilityRarityColor, getMaxOverallAbilities, getMaxBattlePoolActions } from '../data/actions.js'
import { ITEMS } from '../data/items.js'
import { getCharmById } from '../data/charms.js'
import { rollEnemyDrops } from '../data/enemies/index.js'
import { getRewardPool, pickRewardAbilities } from '../data/abilityRewards.js'
import WinChallengeSystem from '../systems/WinChallengeSystem.js'
import AbilityTooltip from '../ui/AbilityTooltip.js'
import { setupHighDPIWorld } from '../highDpi.js'

export default class WinScene extends Phaser.Scene {
  constructor() {
    super({ key: 'WinScene' })
  }

  create() {
    setupHighDPIWorld(this)
    const data = this.scene.settings.data || {}
    this.player = data.player
    this.enemy = data.enemy
    this.tile = data.tile || null
    this.monster = this.enemy?.definition || null

    this.challengeSystem = null
    this.replaceDialog = null
    this.abilityTooltip = new AbilityTooltip(this)
    this.abilitySelected = false
    this.selectedAbilityAction = null
    this.bonusAbilityPending = false

    // Calculate base rewards
    this.baseAttributePoints = (this.monster?.level || 1) + (Math.random() < (this.player.luck || 0) / 50 ? 1 : 0)
    this.baseGold = Math.round((this.monster?.baseGold || 5) * (1 + (this.player.luck || 0) / 200))
    this.attributePoints = this.player.applyNgPlusMultiplier(this.baseAttributePoints)
    this.goldReward = this.player.applyNgPlusMultiplier(this.baseGold)

    this.challengePlayed = false
    this.challengeMultiplier = 1
    this.essenceGained = data.essenceGained || 0

    // Roll drops immediately
    this.drops = rollEnemyDrops(this.enemy, this.player.loadout.class || 'warrior', this.player.getNgPlusMultiplier())
    this.applyDrops()

    // Pick ability rewards
    this.rewardAbilities = this.generateAbilityRewards()

    this.createBackground()
    this.createVictoryHeader()
    this.createRewardSummary()
    this.abilityRewardsContainer = this.add.container(0, 0)
    this.createAbilityRewards()
    this.createDropsSection()
    this.createChallengeSection()
    this.createContinueButton()
  }

  shutdown() {
    if (this.challengeSystem) {
      this.challengeSystem.destroy()
      this.challengeSystem = null
    }
    this.closeReplaceDialog()
  }

  // ---------- Reward generation ----------

  generateAbilityRewards() {
    const pool = getRewardPool(this.player)
    const count = this.player.applyNgPlusMultiplier(3 + (Math.random() * 100 < (this.player.luck || 0) ? 1 : 0))
    return pickRewardAbilities(pool, Math.min(count, 6), this.player.loadout.knownActionIds || [], this.tile)
  }

  applyDrops() {
    for (const drop of this.drops) {
      if (drop.type === 'item') {
        this.player.addItem(drop.id, 1)
      } else if (drop.type === 'charm') {
        this.addCharmDrop(drop.id)
      }
    }
  }

  addCharmDrop(charmId) {
    const charm = getCharmById(charmId)
    if (!charm) return

    // Track ownership
    if (!this.player.loadout.ownedCharmIds) this.player.loadout.ownedCharmIds = []
    if (!this.player.loadout.ownedCharmIds.includes(charmId)) {
      this.player.loadout.ownedCharmIds.push(charmId)
    }

    // Auto-equip if a free slot exists
    const slotType = charm.type
    let equipped = false
    if (slotType === 'hero' && this.player.loadout.heroCharmIds.length < this.player.getHeroCharmSlots()) {
      this.player.loadout.heroCharmIds.push(charmId)
      equipped = true
    } else if (slotType === 'weapon' && this.player.loadout.weaponCharmIds.length < this.player.getWeaponCharmSlots()) {
      this.player.loadout.weaponCharmIds.push(charmId)
      equipped = true
    } else if (slotType === 'shield' && this.player.loadout.shieldCharmIds.length < this.player.getShieldCharmSlots()) {
      this.player.loadout.shieldCharmIds.push(charmId)
      equipped = true
    }

    if (equipped) {
      this.player._charmEffects = null
      this.player.recalcMaxHp()
    }
    this.player.saveLoadout()
  }

  // ---------- UI creation ----------

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x0f1525)
  }

  createVictoryHeader() {
    this.add.text(GAME_CONFIG.width / 2, 50, 'VICTORY!', {
      ...FONTS.title,
      fontSize: '36px',
      color: '#2ecc71',
    }).setOrigin(0.5)

    const enemyName = this.enemy?.name || this.monster?.name || 'Enemy'
    this.add.text(GAME_CONFIG.width / 2, 95, `You defeated the ${enemyName}`, {
      ...FONTS.default,
      fontSize: '16px',
      color: '#ecf0f1',
    }).setOrigin(0.5)
  }

  createRewardSummary() {
    const y = 140
    const panelW = 420
    const hasEssence = this.essenceGained > 0
    const panelH = hasEssence ? 90 : 70
    const panel = this.add.rectangle(GAME_CONFIG.width / 2, y, panelW, panelH, 0x1a1a2e).setStrokeStyle(2, 0x3498db)

    const leftX = GAME_CONFIG.width / 2 - panelW / 2 + 30
    const textStyle = { ...FONTS.default, fontSize: '16px', color: '#f1c40f' }
    const iconTextStyle = { ...FONTS.default, fontSize: '12px', color: '#1a1a2e', fontStyle: 'bold' }

    const pointsY = hasEssence ? y - 25 : y - 15
    const goldY = hasEssence ? y : y + 5
    const essenceY = y + 25

    // Attribute Points icon (gold circle with "P")
    this.add.circle(leftX, pointsY, 11, 0xf1c40f).setStrokeStyle(2, 0xffffff)
    this.add.text(leftX, pointsY, 'P', iconTextStyle).setOrigin(0.5)
    this.pointsText = this.add.text(leftX + 20, pointsY, `+${this.attributePoints}`, textStyle).setOrigin(0, 0.5)

    // Gold icon (gold coin with "$")
    this.add.circle(leftX, goldY, 11, 0xf1c40f).setStrokeStyle(2, 0xffffff)
    this.add.text(leftX, goldY, '$', iconTextStyle).setOrigin(0.5)
    this.goldText = this.add.text(leftX + 20, goldY, `+${this.goldReward}`, textStyle).setOrigin(0, 0.5)

    // Ouro Essence icon (real currency image)
    if (hasEssence) {
      this.essenceIcon = this.add.image(leftX, essenceY, 'ouro_essence').setDisplaySize(22, 22).setOrigin(0.5)
      this.essenceText = this.add.text(leftX + 20, essenceY, `+${this.essenceGained}`, {
        ...FONTS.default,
        fontSize: '16px',
        color: '#f1c40f',
        stroke: '#000000',
        strokeThickness: 3,
      }).setOrigin(0, 0.5)
    }
  }

  createAbilityRewards() {
    if (!this.abilityRewardsContainer) return
    this.abilityRewardsContainer.removeAll(true)

    const startY = 210

    if (this.abilitySelected) {
      this.abilityRewardsContainer.add(this.add.text(GAME_CONFIG.width / 2, startY, 'Ability reward claimed:', {
        ...FONTS.default,
        fontSize: '16px',
        color: '#3498db',
      }).setOrigin(0.5))
      const name = this.selectedAbilityName || 'Ability'
      this.abilityRewardsContainer.add(this.add.text(GAME_CONFIG.width / 2, startY + 40, name, {
        ...FONTS.default,
        fontSize: '18px',
        color: '#2ecc71',
      }).setOrigin(0.5))
      return
    }

    const headerText = this.bonusAbilityPending
      ? 'Choose an ability reward — you get a second matching ability!'
      : 'Choose an ability reward:'
    this.abilityRewardsContainer.add(this.add.text(GAME_CONFIG.width / 2, startY, headerText, {
      ...FONTS.default,
      fontSize: '16px',
      color: '#3498db',
    }).setOrigin(0.5))

    if (this.rewardAbilities.length === 0) {
      this.abilityRewardsContainer.add(this.add.text(GAME_CONFIG.width / 2, startY + 40, 'No new abilities to learn.', {
        ...FONTS.default,
        fontSize: '14px',
        color: '#7f8c8d',
      }).setOrigin(0.5))
      return
    }

    const cardW = 160
    const cardH = 90
    const gap = 20
    const totalW = this.rewardAbilities.length * cardW + (this.rewardAbilities.length - 1) * gap
    const startX = (GAME_CONFIG.width - totalW) / 2 + cardW / 2

    this.rewardAbilities.forEach((actionId, i) => {
      const action = ALL_ACTIONS.find(a => a.id === actionId)
      if (!action) return
      const x = startX + i * (cardW + gap)
      const y = startY + 60
      const card = this.createAbilityCard(x, y, cardW, cardH, action)
      this.abilityTooltip.attach(card.hitArea, action)
      card.hitArea.on('pointerup', (pointer) => {
        const moveDist = Math.hypot(pointer.x - pointer.downX, pointer.y - pointer.downY)
        if (card.hitArea.getData('abilityTooltipSuppressClick')) {
          card.hitArea.setData('abilityTooltipSuppressClick', false)
          return
        }
        if (moveDist < 8) this.onAbilitySelected(action)
      })
      this.abilityRewardsContainer.add(card.container)
    })
  }

  refreshAbilityRewards() {
    // Re-roll reward picks from the remaining unknown pool so the same
    // learned ability doesn't keep showing up.
    const pool = getRewardPool(this.player)
    const count = this.rewardAbilities.length
    this.rewardAbilities = pickRewardAbilities(pool, count, this.player.loadout.knownActionIds || [], this.tile)
    this.createAbilityRewards()
  }

  markAbilitySelected(actionName, bonusName = null) {
    this.abilitySelected = true
    this.selectedAbilityName = bonusName ? `${actionName} + ${bonusName}` : actionName
    this.createAbilityRewards()
  }

  createAbilityCard(x, y, w, h, action) {
    const container = this.add.container(x, y)
    const colors = getAbilityRarityColor(action.rarity)

    const bg = this.add.graphics()
    bg.fillStyle(0x16213e, 0.95)
    bg.fillRoundedRect(-w / 2, -h / 2, w, h, 10)
    bg.lineStyle(2, colors.main, 0.8)
    bg.strokeRoundedRect(-w / 2, -h / 2, w, h, 10)
    container.add(bg)

    container.add(this.add.text(0, -h / 2 + 18, action.kanji || '', {
      fontFamily: FONTS.kanji.fontFamily,
      fontSize: '24px',
      color: '#ffffff',
    }).setOrigin(0.5))

    container.add(this.add.text(0, -5, action.name, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ecf0f1',
    }).setOrigin(0.5))

    container.add(this.add.text(0, 15, `${action.type.toUpperCase()} · ${action.rarity || 'normal'}`, {
      ...FONTS.default,
      fontSize: '10px',
      color: '#7f8c8d',
    }).setOrigin(0.5))

    const known = this.player.hasAbility(action.id)
    const isSingleUse = action.singleUse
    const rewardLabel = isSingleUse && known ? '+1 Use' : known ? 'Known' : 'Click to learn'
    const rewardColor = isSingleUse && known ? '#f1c40f' : known ? '#e74c3c' : '#2ecc71'
    container.add(this.add.text(0, 32, rewardLabel, {
      ...FONTS.default,
      fontSize: '10px',
      color: rewardColor,
    }).setOrigin(0.5))

    const hitArea = this.add.rectangle(0, 0, w, h, 0x000000, 0).setInteractive({ useHandCursor: true })
    container.add(hitArea)

    return { container, bg, hitArea }
  }

  createDropsSection() {
    const startY = 330
    this.add.text(GAME_CONFIG.width / 2, startY, 'Loot:', {
      ...FONTS.default,
      fontSize: '16px',
      color: '#3498db',
    }).setOrigin(0.5)

    if (this.drops.length === 0) {
      this.add.text(GAME_CONFIG.width / 2, startY + 30, 'No drops this time.', {
        ...FONTS.default,
        fontSize: '14px',
        color: '#7f8c8d',
      }).setOrigin(0.5)
      return
    }

    let x = GAME_CONFIG.width / 2 - (this.drops.length * 110) / 2 + 55
    this.drops.forEach((drop) => {
      let label = ''
      let icon = ''
      if (drop.type === 'item') {
        const item = this.getItemData(drop.id)
        label = item?.name || drop.id
        icon = item?.icon || '📦'
      } else if (drop.type === 'charm') {
        const charm = getCharmById(drop.id)
        label = charm?.name || drop.id
        icon = charm?.kanji || '✨'
      }

      this.add.text(x, startY + 30, `${icon}\n${label}`, {
        ...FONTS.default,
        fontSize: '12px',
        color: '#ecf0f1',
        align: 'center',
      }).setOrigin(0.5)
      x += 110
    })
  }

  getItemData(itemId) {
    return ITEMS.find(i => i.id === itemId)
  }

  createChallengeSection() {
    const y = 430
    this.challengeButton = this.createButton(GAME_CONFIG.width / 2, y, 'Gamble Points & Gold', () => this.startChallenge(), 220, 40, 0x8e44ad, 0x9b59b6)
    this.challengeResultText = this.add.text(GAME_CONFIG.width / 2, y + 35, '', {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ecf0f1',
    }).setOrigin(0.5)
  }

  createContinueButton() {
    this.createButton(GAME_CONFIG.width / 2, 500, 'Continue', () => {
      this.player.loadout.statPoints = (this.player.loadout.statPoints || 0) + this.attributePoints
      this.player.addGold(this.goldReward)
      if (this.tile?.id) this.player.completeTile(this.tile.id)
      this.player.saveLoadout()
      this.scene.start('MapScene', { player: this.player })
    }, 180, 44, 0x27ae60, 0x2ecc71)
  }

  // ---------- Interactions ----------

  onAbilitySelected(action) {
    if (this.abilitySelected) return

    this.selectedAbilityAction = action

    // Single-use abilities can be collected again to gain extra charges.
    if (action.singleUse) {
      this.player.addAbilityCharges(action.id, 1)
      this.showToast(`${action.name} +1 use`)
      const bonusName = this.bonusAbilityPending ? this.grantBonusAbility(action.type) : null
      this.markAbilitySelected(`${action.name} +1 use`, bonusName)
      return
    }

    if (this.player.hasAbility(action.id)) {
      this.showToast('You already know this ability')
      this.selectedAbilityAction = null
      return
    }

    const capacity = this.player.capacity || 3
    const knownCount = this.player.countCombatAbilities()
    const maxOverall = getMaxOverallAbilities(capacity)

    if (knownCount >= maxOverall) {
      this.showReplaceDialog(action)
      return
    }

    const result = this.player.learnAbility(action.id)
    if (!result.ok) {
      this.showToast(result.reason)
      this.selectedAbilityAction = null
      return
    }

    const inBattle = this.player.loadout.selectedActionIds.includes(action.id)
    if (inBattle) {
      this.showToast(`${action.name} learned!`)
    } else {
      this.showToast(`${action.name} learned (added to reserve)`)
    }
    const bonusName = this.bonusAbilityPending ? this.grantBonusAbility(action.type) : null
    this.markAbilitySelected(action.name, bonusName)
  }

  /**
   * Grant a second ability of the chosen type as a gamble bonus.
   * Returns the bonus ability display name, or null if no match was possible.
   */
  grantBonusAbility(type) {
    const pool = this.rewardAbilities.filter(
      a => a.type === type && a.id !== this.selectedAbilityAction?.id
    )
    let bonus = pool.length > 0 ? pool[Math.floor(Math.random() * pool.length)] : null

    if (!bonus) {
      const fullPool = getRewardPool(this.player)
      const fallbackPool = [
        ...(fullPool.weapon || []),
        ...(fullPool.shield || []),
        ...(fullPool.class || []),
      ].filter(
        a => a.type === type && a.id !== this.selectedAbilityAction?.id && !this.player.hasAbility(a.id)
      )
      if (fallbackPool.length > 0) {
        bonus = fallbackPool[Math.floor(Math.random() * fallbackPool.length)]
      }
    }

    if (!bonus) {
      this.showToast('No matching bonus ability available')
      return null
    }

    if (bonus.singleUse) {
      this.player.addAbilityCharges(bonus.id, 1)
      this.showToast(`Bonus: ${bonus.name} +1 use`)
      return `${bonus.name} +1 use`
    }

    if (this.player.hasAbility(bonus.id)) {
      this.showToast('Bonus ability already known')
      return null
    }

    const capacity = this.player.capacity || 3
    const knownCount = this.player.countCombatAbilities()
    const maxOverall = getMaxOverallAbilities(capacity)

    if (knownCount >= maxOverall) {
      const knownIds = this.player.loadout.knownActionIds || []
      const replaceId = knownIds.find(id => id !== bonus.id && id !== 'use_item')
      if (replaceId) {
        this.player.replaceAbility(replaceId, bonus.id)
        this.showToast(`Bonus: ${bonus.name} learned (replaced)`)
        return bonus.name
      }
      this.showToast('No room for bonus ability')
      return null
    }

    const result = this.player.learnAbility(bonus.id)
    if (!result.ok) {
      this.showToast(result.reason)
      return null
    }
    this.showToast(`Bonus: ${bonus.name} learned!`)
    return bonus.name
  }

  closeReplaceDialog() {
    if (this.replaceDialog) {
      this.replaceDialog.destroy()
      this.replaceDialog = null
    }
    if (this.replaceWheelHandler) {
      this.game.canvas.removeEventListener('wheel', this.replaceWheelHandler)
      this.replaceWheelHandler = null
    }
    if (this.replaceDragCleanup) {
      this.replaceDragCleanup()
      this.replaceDragCleanup = null
    }
  }

  showReplaceDialog(newAction) {
    this.closeReplaceDialog()

    const dialog = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2).setDepth(300)
    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.7).setOrigin(0.5).setInteractive()
    backdrop.on('pointerdown', () => {}) // swallow clicks behind the dialog
    dialog.add(backdrop)
    dialog.add(this.add.rectangle(0, 0, 480, 500, 0x1a1a2e).setStrokeStyle(2, 0xe74c3c).setOrigin(0.5))
    dialog.add(this.add.text(0, -220, 'Ability Cap Reached', { ...FONTS.title, fontSize: '18px', color: '#e74c3c' }).setOrigin(0.5))
    dialog.add(this.add.text(0, -185, `Choose an ability to replace with ${newAction.name}:`, { ...FONTS.default, fontSize: '13px', color: '#ecf0f1' }).setOrigin(0.5))

    const listY = -160
    const listW = 440
    const listH = 330
    const rowH = 40

    const listContainer = this.add.container(0, listY)
    dialog.add(listContainer)

    // Clip rows to the visible list area
    const maskGraphics = this.make.graphics({ x: 0, y: 0, add: false })
    maskGraphics.fillStyle(0xffffff)
    maskGraphics.fillRect(
      GAME_CONFIG.width / 2 - listW / 2,
      GAME_CONFIG.height / 2 + listY,
      listW,
      listH,
    )
    listContainer.setMask(maskGraphics.createGeometryMask())

    const knownIds = this.player.loadout.knownActionIds || []
    const rowButtons = []
    knownIds.forEach((id, i) => {
      const action = ALL_ACTIONS.find(a => a.id === id)
      if (!action) return
      const onClick = () => {
        this.player.replaceAbility(id, newAction.id)
        this.showToast(`${newAction.name} learned!`)
        this.closeReplaceDialog()
        const bonusName = this.bonusAbilityPending ? this.grantBonusAbility(newAction.type) : null
        this.markAbilitySelected(newAction.name, bonusName)
      }
      const btn = this.createDialogButton(listContainer, 0, i * rowH, listW - 20, rowH - 4, `${action.kanji} ${action.name}`, 0x2c3e50, onClick)
      rowButtons.push({ ...btn, onClick })
    })

    // Invisible overlay for touch-drag scrolling (on top of the rows)
    const scrollHitArea = this.add.rectangle(0, listY + listH / 2, listW, listH, 0x000000, 0)
      .setInteractive({ useHandCursor: false })
    dialog.add(scrollHitArea)

    let scroll = 0
    const maxScroll = Math.max(0, knownIds.length * rowH - listH)
    const updateScroll = (target) => {
      scroll = Math.max(0, Math.min(maxScroll, target))
      listContainer.setY(listY - scroll)
      rowButtons.forEach(({ container, hitArea }) => {
        const relY = container.y - scroll
        const visible = relY + rowH > 0 && relY < listH
        container.setVisible(visible)
        if (hitArea.input) hitArea.input.enabled = visible
      })
    }

    this.replaceWheelHandler = (e) => {
      e.preventDefault()
      updateScroll(scroll + e.deltaY * 0.8)
    }
    this.game.canvas.addEventListener('wheel', this.replaceWheelHandler, { passive: false })

    // Touch-drag scrolling + tap-to-select
    let dragStartY = null
    let dragStartScroll = 0
    let dragged = false
    const DRAG_THRESHOLD = 8

    const onPointerDown = (pointer) => {
      dragStartY = pointer.y
      dragStartScroll = scroll
      dragged = false
    }
    const onPointerMove = (pointer) => {
      if (dragStartY === null) return
      const dy = pointer.y - dragStartY
      if (Math.abs(dy) > DRAG_THRESHOLD) dragged = true
      updateScroll(dragStartScroll - dy)
    }
    const onPointerUp = (pointer) => {
      if (dragStartY === null) return
      if (!dragged) {
        const relY = pointer.y - (listY - scroll)
        const index = Math.floor(relY / rowH)
        const row = rowButtons[index]
        if (row && row.onClick) row.onClick()
      }
      dragStartY = null
    }

    scrollHitArea.on('pointerdown', onPointerDown)
    scrollHitArea.on('pointermove', onPointerMove)
    scrollHitArea.on('pointerup', onPointerUp)
    scrollHitArea.on('pointerupoutside', onPointerUp)

    this.replaceDragCleanup = () => {
      scrollHitArea.off('pointerdown', onPointerDown)
      scrollHitArea.off('pointermove', onPointerMove)
      scrollHitArea.off('pointerup', onPointerUp)
      scrollHitArea.off('pointerupoutside', onPointerUp)
    }

    updateScroll(0)

    this.createDialogButton(dialog, 0, 210, 120, 36, 'Cancel', 0x7f8c8d, () => {
      this.closeReplaceDialog()
    })

    this.replaceDialog = dialog
  }

  createDialogButton(container, x, y, width, height, label, color, onClick) {
    const bg = this.add.graphics()
    bg.fillStyle(color, 0.95)
    bg.fillRoundedRect(-width / 2, -height / 2, width, height, 6)

    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ffffff',
    }).setOrigin(0.5)

    const hitArea = this.add.rectangle(0, 0, width, height, 0x000000, 0)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', onClick)

    const btnContainer = this.add.container(x, y)
    btnContainer.add([bg, text, hitArea])
    container.add(btnContainer)
    return { container: btnContainer, bg, text, hitArea }
  }

  startChallenge() {
    if (this.challengePlayed) return
    this.challengePlayed = true
    this.challengeButton.text.setText('Challenge in progress...')
    this.challengeButton.hitArea.disableInteractive()

    this.challengeSystem = new WinChallengeSystem(this, this.player)
    this.challengeSystem.run((result) => {
      this.challengeMultiplier = result.multiplier
      this.attributePoints = this.player.applyNgPlusMultiplier(Math.round(this.baseAttributePoints * this.challengeMultiplier))
      this.goldReward = this.player.applyNgPlusMultiplier(Math.round(this.baseGold * this.challengeMultiplier))

      this.pointsText.setText(`+${this.attributePoints}`)
      this.goldText.setText(`+${this.goldReward}`)

      if (this.essenceGained > 0) {
        const finalEssence = result.success ? this.essenceGained * 2 : Math.max(0, Math.floor(this.essenceGained / 2))
        const delta = finalEssence - this.essenceGained
        if (delta !== 0) {
          this.player.addOuroEssence(delta)
          this.essenceGained = finalEssence
        }
        if (this.essenceText) this.essenceText.setText(`+${this.essenceGained}`)
        if (finalEssence === 0 && this.essenceIcon) {
          this.essenceIcon.setVisible(false)
          this.essenceText.setVisible(false)
        }
      }

      let status = result.success ? 'Won!' : 'Lost...'
      const color = result.success ? '#2ecc71' : '#e74c3c'

      // 25% chance to win a second ability reward if both challenges passed.
      if (result.success && Math.random() < 0.25) {
        if (this.abilitySelected && this.selectedAbilityAction) {
          const bonusName = this.grantBonusAbility(this.selectedAbilityAction.type)
          if (bonusName) {
            status = 'Won! Bonus ability!'
            this.markAbilitySelected(this.selectedAbilityName, bonusName)
          }
        } else {
          this.bonusAbilityPending = true
          status = 'Won! Bonus ability unlocked!'
        }
      }

      this.challengeResultText.setText(`${status} Multiplier: x${this.challengeMultiplier.toFixed(2)}`)
      this.challengeResultText.setColor(color)

      this.challengeSystem.destroy()
      this.challengeSystem = null
    })
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
