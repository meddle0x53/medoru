import { GAME_CONFIG, COLORS, FONTS } from '../config.js'
import AbilityTooltip from '../ui/AbilityTooltip.js'
import Player from '../entities/Player.js'
import { ITEMS } from '../data/items.js'
import { ALL_ACTIONS, getActionTypeColor, getAbilityRarityColor, getMaxActiveActions, getMaxBattlePoolActions, getMaxOverallAbilities, getAvailableActions, formatAbilityRequirements } from '../data/actions.js'
import { getCharmById, getCharmsByType, CHARM_TYPES } from '../data/charms.js'
import { getSocketCharmById } from '../data/socketCharms.js'
import { getWindowGameData } from '../api.js'
import { setupHighDPIWorld } from '../highDpi.js'

const TAB_NAMES = ['items', 'heroCharms', 'weapons', 'abilities', 'stats']
const TAB_LABELS = ['Items', 'Hero', 'Weapons', 'Abilities', 'Stats']

export default class LoadoutScene extends Phaser.Scene {
  constructor() {
    super({ key: 'LoadoutScene' })
  }

  init(data) {
    this.tile = data.tile || null
    this.mapIndex = data.mapIndex ?? 0
    this.mode = data.mode || 'battle'
    this.returnScene = data.returnScene || 'BattleScene'
  }

  create() {
    setupHighDPIWorld(this)
    const passedPlayer = this.scene.settings.data?.player
    if (passedPlayer) {
      this.player = passedPlayer
    } else {
      const userData = getWindowGameData()
      this.player = new Player(userData)
    }

    this.dragItem = null
    this.dragClone = null
    this.currentTab = 'items'

    this.abilityTooltip = new AbilityTooltip(this)

    this.createBackground()
    this.createLeftPanel()
    this.createRightPanel()
    this.createTabs()
    this.showTab('items')

    this.createReadyButton()

    // Global trackpad / wheel scrolling for scrollable lists
    this._wheelHandler = (e) => {
      if (this.abilityDialogOpen) return
      if (this.currentTab === 'items' && this.itemListContainer) {
        e.preventDefault()
        this.scrollItemList(e.deltaY * 0.8)
      } else if (this.currentTab === 'abilities' && this.abilityListContainer) {
        e.preventDefault()
        if (e.deltaY > 0) this.setAbilityPage(this.abilityPage + 1)
        else this.setAbilityPage(this.abilityPage - 1)
      }
    }
    this.game.canvas.addEventListener('wheel', this._wheelHandler, { passive: false })
    this.events.on('shutdown', () => {
      this.game.canvas.removeEventListener('wheel', this._wheelHandler)
    })
  }

  // ---------- Background ----------

  createBackground() {
    this.add.rectangle(
      GAME_CONFIG.width / 2,
      GAME_CONFIG.height / 2,
      GAME_CONFIG.width,
      GAME_CONFIG.height,
      0x0f1525
    )
  }

  update() {
    // Apply momentum scrolling to the item list
    if (!this.itemListDragging && Math.abs(this.itemListVelocity) > 0.5) {
      this.setItemListScroll(this.itemListScroll + this.itemListVelocity)
      this.itemListVelocity *= 0.9
      if (Math.abs(this.itemListVelocity) < 0.5) {
        this.itemListVelocity = 0
      }
    }
  }

  // ---------- Left Panel: Hero Portrait ----------

  createLeftPanel() {
    // Frame background
    this.leftPanel = this.add.container(0, 0)
    const frame = this.add.graphics()
    frame.fillStyle(0x1a1a2e, 0.9)
    frame.fillRoundedRect(20, 20, 400, 500, 16)
    frame.lineStyle(2, 0x3498db, 0.3)
    frame.strokeRoundedRect(20, 20, 400, 500, 16)
    this.leftPanel.add(frame)

    // Title
    const titleText = this.mode === 'map' ? 'Prepare for Journey' : 'Prepare for Battle'
    this.leftPanel.add(
      this.add.text(220, 44, titleText, {
        ...FONTS.title,
        fontSize: '20px',
      }).setOrigin(0.5)
    )

    // Hero portrait
    this.heroPortrait = this.add.image(220, 330, 'hero_portrait')
      .setDisplaySize(260, 390)
      .setOrigin(0.5)
    this.leftPanel.add(this.heroPortrait)

    // Charm slots
    this.createCharmSlots()

    // Active action slot indicators
    this.createActiveActionSlots()

    // Equipped charm glows (reuse BattleScene logic)
    this.refreshCharmGlows()

    // Socket charms buttons above weapon and shield charm columns.
    this.createSocketButton(70, 266)
    this.createSocketButton(370, 266)
  }

  createSocketButton(x, y) {
    const size = 36
    const bg = this.add.rectangle(x, y, size, size, 0x2c3e50)
      .setStrokeStyle(2, 0xf39c12)
      .setInteractive({ useHandCursor: true })
      .setOrigin(0.5)
    const text = this.add.text(x, y, '穴', {
      fontFamily: FONTS.kanji.fontFamily,
      fontSize: '18px',
      color: '#f39c12',
    }).setOrigin(0.5)
    this.leftPanel.add([bg, text])

    bg.on('pointerdown', () => this.scene.start('SocketScene', { player: this.player }))
    bg.on('pointerover', () => bg.setFillStyle(0x34495e))
    bg.on('pointerout', () => bg.setFillStyle(0x2c3e50))
  }

  createCharmSlots() {
    this.charmSlots = []
    const cx = 220
    const cy = 360
    const slotRadius = 18 // larger for mobile touch

    // Hero charm slots: fixed arc above head (4 slots hardcoded for visibility)
    const heroSlotPositions = [
      { x: cx - 62, y: cy - 182 },
      { x: cx - 21, y: cy - 205 },
      { x: cx + 21, y: cy - 205 },
      { x: cx + 62, y: cy - 182 },
    ]
    const heroSlotCount = this.player.getHeroCharmSlots()
    for (let i = 0; i < heroSlotPositions.length; i++) {
      const pos = heroSlotPositions[i]
      const unlocked = i < heroSlotCount
      this.charmSlots.push(this.createSlot(pos.x, pos.y, 'hero', i, unlocked, slotRadius))
    }

    // Primary weapon socket slots: left side of body
    for (let i = 0; i < 4; i++) {
      const x = cx - 150
      const y = cy - 50 + i * 44
      const unlocked = i < this.player.getWeaponCharmSlots()
      this.charmSlots.push(this.createSlot(x, y, 'primary_weapon', i, unlocked, slotRadius, this.player.weapon))
    }

    // Secondary weapon socket slots: right side of body
    for (let i = 0; i < 4; i++) {
      const x = cx + 150
      const y = cy - 50 + i * 44
      const unlocked = i < this.player.getShieldCharmSlots()
      this.charmSlots.push(this.createSlot(x, y, 'secondary_weapon', i, unlocked, slotRadius, this.player.shield))
    }
  }

  createSlot(x, y, type, index, unlocked = true, radius = 18, equipment = null) {
    const g = this.add.graphics()
    if (unlocked) {
      g.lineStyle(2, 0x3498db, 0.5)
      g.strokeCircle(x, y, radius)
      g.fillStyle(0x3498db, 0.1)
      g.fillCircle(x, y, radius)
    } else {
      g.lineStyle(2, 0x555555, 0.3)
      g.strokeCircle(x, y, radius)
      g.fillStyle(0x000000, 0.2)
      g.fillCircle(x, y, radius)
      // Lock icon
      const lock = this.add.text(x, y, '🔒', { fontSize: '14px' }).setOrigin(0.5)
      this.leftPanel.add(lock)
    }

    const slot = {
      type,
      index,
      x,
      y,
      radius,
      unlocked,
      graphics: g,
      hitArea: null,
      charmId: null,
      glowContainer: null,
      equipment: equipment || null,
      socket: !!equipment,
    }

    // Populate from loadout
    let equipped = null
    if (equipment) {
      equipped = equipment.socketCharmIds?.[index] || null
    } else {
      const loadoutKey = type === 'hero' ? 'heroCharmIds' : type === 'weapon' ? 'weaponCharmIds' : 'shieldCharmIds'
      equipped = this.player.loadout[loadoutKey][index] || null
    }
    if (equipped) {
      slot.charmId = equipped
    }

    // Make unlocked slots clickable/tappable to unequip
    if (unlocked) {
      const hitArea = this.add.circle(x, y, radius + 6, 0x000000, 0)
        .setInteractive({ useHandCursor: true })
        .on('pointerdown', () => {
          if (slot.charmId) {
            this.unequipCharmFromSlot(slot)
          }
        })
      this.leftPanel.add(hitArea)
      slot.hitArea = hitArea
    }

    this.leftPanel.add(g)
    return slot
  }

  syncSlotCharmIds() {
    this.charmSlots.forEach(slot => {
      if (slot.equipment) {
        slot.charmId = slot.equipment.socketCharmIds?.[slot.index] || null
      } else {
        const loadoutKey = slot.type === 'hero' ? 'heroCharmIds' : slot.type === 'weapon' ? 'weaponCharmIds' : 'shieldCharmIds'
        slot.charmId = this.player.loadout[loadoutKey][slot.index] || null
      }
    })
  }

  createActiveActionSlots() {
    this.actionSlots = []
    const maxSlots = getMaxActiveActions(this.player.capacity || 3)
    const activeIds = this.player.loadout.activeActionIds
    const combatActiveIds = activeIds.filter(id => id !== 'use_item')
    const useItemActive = activeIds.includes('use_item')
    const startX = 220 - ((maxSlots - 1) * 40) / 2
    const y = 380
    const size = 36

    this.leftPanel.add(
      this.add.text(220, y - 42, `Active for Battle (${maxSlots})`, {
        ...FONTS.default,
        fontSize: '12px',
        color: '#f1c40f',
      }).setOrigin(0.5)
    )

    const createSlot = (x, actionId, options = {}) => {
      const { isItemSlot = false } = options
      const g = this.add.graphics()
      const borderColor = isItemSlot ? 0x1abc9c : 0xf1c40f
      g.lineStyle(2, borderColor, 0.5)
      g.strokeRoundedRect(x - size / 2, y - size / 2, size, size, 6)
      g.fillStyle(borderColor, 0.1)
      g.fillRoundedRect(x - size / 2, y - size / 2, size, size, 6)
      this.leftPanel.add(g)

      let label = ''
      let action = null
      if (actionId) {
        action = ALL_ACTIONS.find(a => a.id === actionId)
        label = action ? (action.kanji || action.name.slice(0, 2)) : '?'
      } else if (isItemSlot) {
        label = '🎒'
      }

      const text = this.add.text(x, y, label, {
        fontFamily: FONTS.kanji.fontFamily,
        fontSize: '18px',
        color: '#ffffff',
      }).setOrigin(0.5)
      this.leftPanel.add(text)

      // Invisible hit area for click-to-remove/toggle and drop-target
      const hitArea = this.add.rectangle(x, y, size + 8, size + 8, 0x000000, 0)
        .setInteractive({ useHandCursor: true })
        .on('pointerdown', () => {
          if (isItemSlot) {
            if (useItemActive) this.deactivateAbility('use_item')
            else this.activateAbility('use_item')
          } else if (actionId) {
            this.deactivateAbility(actionId)
          }
        })
      this.leftPanel.add(hitArea)

      return {
        x, y, size,
        index: isItemSlot ? 'item' : options.index,
        actionId,
        action,
        text,
        graphics: g,
        hitArea,
      }
    }

    for (let i = 0; i < maxSlots; i++) {
      const x = startX + i * 40
      this.actionSlots.push(createSlot(x, combatActiveIds[i], { index: i }))
    }

    // Dedicated Use Item slot to the right of combat slots
    const itemX = startX + maxSlots * 40 + 16
    this.actionSlots.push(createSlot(itemX, useItemActive ? 'use_item' : null, { isItemSlot: true }))
  }

  deactivateAbility(actionId, { force = false } = {}) {
    const idx = this.player.loadout.activeActionIds.indexOf(actionId)
    if (idx < 0) return

    const actionObj = ALL_ACTIONS.find(a => a.id === actionId)
    let fallbackAttackId = null

    if (!force && actionObj?.type === 'attack') {
      const remainingAttacks = this.player.loadout.activeActionIds
        .filter(id => id !== actionId)
        .map(id => ALL_ACTIONS.find(a => a.id === id))
        .filter(a => a?.type === 'attack')
      if (remainingAttacks.length === 0) {
        // Try to keep an attack active by falling back to another known attack
        const fallback = this.player.loadout.selectedActionIds
          .filter(id => id !== actionId)
          .map(id => ALL_ACTIONS.find(a => a.id === id))
          .find(a => a?.type === 'attack')
        if (!fallback) {
          this.showToast('At least one attack must be active')
          return
        }
        fallbackAttackId = fallback.id
      }
    }

    this.player.loadout.activeActionIds.splice(idx, 1)
    if (fallbackAttackId && !this.player.loadout.activeActionIds.includes(fallbackAttackId)) {
      this.player.loadout.activeActionIds.push(fallbackAttackId)
    }
    this.player.saveLoadout()
    this.player.refreshActions()
    this.refreshActionSlots()
    this.showTab('abilities')
  }

  activateAbility(actionId) {
    // Use Item occupies its own dedicated slot and never blocks combat abilities.
    if (actionId === 'use_item') {
      if (!this.player.loadout.activeActionIds.includes('use_item')) {
        this.player.loadout.activeActionIds.push('use_item')
        this.player.saveLoadout()
      }
      this.player.refreshActions()
      this.refreshActionSlots()
      this.showTab('abilities')
      this.showToast('Use Item activated')
      return
    }

    const maxSlots = getMaxActiveActions(this.player.capacity || 3)
    const combatActiveCount = this.player.loadout.activeActionIds.filter(id => id !== 'use_item').length
    if (combatActiveCount >= maxSlots) {
      this.showToast(`Max ${maxSlots} active abilities`)
      return
    }
    if (this.player.loadout.activeActionIds.includes(actionId)) {
      this.showToast('Already active')
      return
    }
    // Ensure ability is in the battle pool first
    if (!this.player.loadout.selectedActionIds.includes(actionId)) {
      const res = this.player.addToBattlePool(actionId)
      if (!res.ok) {
        this.showToast(res.reason)
        return
      }
    }
    this.player.loadout.activeActionIds.push(actionId)
    this.player.saveLoadout()
    this.player.refreshActions()
    this.refreshActionSlots()
    this.showTab('abilities')
    const action = ALL_ACTIONS.find(a => a.id === actionId)
    if (action) this.showToast(`${action.name} activated`)
  }


  addToSelectedPool(actionId) {
    // Deprecated: use Player.addToBattlePool directly
    this.player.addToBattlePool(actionId)
  }

  refreshCharmGlows() {
    // Remove old glows
    if (this.charmGlows) {
      this.charmGlows.forEach(g => g.destroy())
    }
    this.charmGlows = []

    // Always read fresh from loadout so we never render stale data
    this.syncSlotCharmIds()

    this.charmSlots.forEach(slot => {
      if (!slot.charmId || !slot.unlocked) return
      const charm = slot.equipment ? getSocketCharmById(slot.charmId) : getCharmById(slot.charmId)
      if (!charm) return

      const colorHex = '#' + charm.color.toString(16).padStart(6, '0')
      const container = this.add.container(slot.x, slot.y)

      // Glow layers
      for (let i = 3; i > 0; i--) {
        const glow = this.add.text(0, 0, charm.kanji, {
          fontFamily: FONTS.kanji.fontFamily,
          fontSize: '18px',
          color: colorHex,
          stroke: colorHex,
          strokeThickness: i * 2,
        }).setOrigin(0.5)
        glow.setAlpha(0.35)
        container.add(glow)
      }

      // Core
      const core = this.add.text(0, 0, charm.kanji, {
        fontFamily: FONTS.kanji.fontFamily,
        fontSize: '18px',
        color: '#ffffff',
        stroke: colorHex,
        strokeThickness: 2,
      }).setOrigin(0.5)
      container.add(core)

      this.leftPanel.add(container)
      this.charmGlows.push(container)
    })
  }

  unequipCharmFromSlot(slot) {
    if (!slot.charmId) return
    const charm = slot.equipment ? getSocketCharmById(slot.charmId) : getCharmById(slot.charmId)
    if (slot.equipment) {
      this.player.unequipSocketCharm(slot.equipment, slot.index)
    } else {
      const loadoutKey = slot.type === 'hero' ? 'heroCharmIds' : slot.type === 'weapon' ? 'weaponCharmIds' : 'shieldCharmIds'
      this.player.loadout[loadoutKey][slot.index] = null
      this.player._charmEffects = null
      this.player.saveLoadout()
    }
    this.syncSlotCharmIds()
    this.refreshCharmGlows()
    this.showTab(this.currentTab)
    if (charm) this.showToast(`${charm.name} removed`)
  }

  // ---------- Right Panel: Tabs & Content ----------

  createRightPanel() {
    this.rightPanel = this.add.container(0, 0)
    const bg = this.add.graphics()
    bg.fillStyle(0x1a1a2e, 0.9)
    bg.fillRoundedRect(440, 20, 500, 500, 16)
    bg.lineStyle(2, 0x3498db, 0.3)
    bg.strokeRoundedRect(440, 20, 500, 500, 16)
    this.rightPanel.add(bg)
  }

  createTabs() {
    this.tabButtons = []
    this.tabWidth = 500 / TAB_NAMES.length - 5
    const startX = 460 + this.tabWidth / 2
    const y = 48

    TAB_NAMES.forEach((key, i) => {
      const x = startX + i * this.tabWidth
      const text = this.add.text(x, y, TAB_LABELS[i], {
        fontFamily: FONTS.default.fontFamily,
        fontSize: '14px',
        color: key === this.currentTab ? '#3498db' : '#7f8c8d',
      }).setOrigin(0.5)

      // Larger invisible hit area for mobile
      const hitArea = this.add.rectangle(x, y, this.tabWidth - 4, 48, 0x000000, 0)
        .setInteractive({ useHandCursor: true })
        .on('pointerdown', () => this.showTab(key))
      this.rightPanel.add(hitArea)

      this.tabButtons.push({ key, text, hitArea })
      this.rightPanel.add(text)
    })

    // Underline indicator
    this.tabIndicator = this.add.graphics()
    this.rightPanel.add(this.tabIndicator)
    this.updateTabIndicator()
  }

  updateTabIndicator() {
    this.tabIndicator.clear()
    const activeBtn = this.tabButtons.find(b => b.key === this.currentTab)
    if (!activeBtn) return
    const x = activeBtn.text.x
    const y = activeBtn.text.y + 16
    this.tabIndicator.fillStyle(0x3498db, 1)
    const width = this.tabWidth - 40
    this.tabIndicator.fillRect(x - width / 2, y, width, 3)
  }

  showTab(tabName) {
    this.closeAbilityDialog()

    // Destroy any stray charm drag clone before rebuilding the tab content
    if (this.dragClone) {
      this.dragClone.destroy()
      this.dragClone = null
      this.dragItem = null
    }

    // Clear stale pagination references so setAbilityPage doesn't touch
    // text objects that were destroyed with the previous tabContent.
    this.abilityPageText = null
    this.abilityPaginationButtons = null

    this.currentTab = tabName

    // Update tab button colors
    this.tabButtons.forEach(({ key, text }) => {
      text.setColor(key === tabName ? '#3498db' : '#7f8c8d')
    })
    this.updateTabIndicator()

    // Clear previous content
    if (this.tabContent) {
      this.tabContent.destroy()
    }
    this.tabContent = this.add.container(0, 0)
    this.rightPanel.add(this.tabContent)

    switch (tabName) {
      case 'items': this.createItemsTab(); break
      case 'heroCharms': this.createCharmsTab(CHARM_TYPES.HERO); break
      case 'weapons': this.createWeaponsTab(); break
      case 'abilities': this.createAbilitiesTab(); break
      case 'stats': this.createStatsTab(); break
    }
  }

  // ---------- Items Tab ----------

  createItemsTab() {
    const activeItemIds = this.player.loadout.activeItemIds
    const startY = 80
    const itemHeight = 58
    const listX = 460
    const listY = startY
    const listW = 460
    const visibleRows = 6
    const listH = visibleRows * itemHeight // 348px, fits whole rows

    // Create scrollable container
    this.itemListContainer = this.add.container(listX, listY)
    this.tabContent.add(this.itemListContainer)

    // Add rows to the scrollable container
    this.itemListRows = []
    const ownedItems = ITEMS.filter(item => (this.player.loadout.inventory?.[item.id] || 0) > 0)
    ownedItems.forEach((item, i) => {
      const y = i * itemHeight
      const isActive = activeItemIds.includes(item.id)
      const row = this.createItemRow(0, y, item, isActive)
      this.itemListContainer.add(row.container)
      this.itemListRows.push(row)
    })

    if (ownedItems.length === 0) {
      this.itemListContainer.add(this.add.text(listW / 2, listH / 2, 'No items yet.\nWin items from battles and events.', {
        ...FONTS.default,
        fontSize: '14px',
        color: '#7f8c8d',
        align: 'center',
      }).setOrigin(0.5))
    }

    // Scroll state
    this.itemListMaxScroll = Math.max(0, ownedItems.length * itemHeight - listH)
    this.itemListScroll = 0
    this.itemListVisibleHeight = listH
    this.itemListItemHeight = itemHeight

    // NOTE: Geometry masks are not supported in Phaser 4 WebGL and corrupt the
    // renderer, so the item list is no longer clipped. The list area is tall
    // enough for 6 rows; overflow is visually bounded by the dark panel below.

    // Invisible interactive area for wheel + drag scrolling (slightly wider for mobile)
    const scrollHitArea = this.add.rectangle(listX + listW / 2, listY + listH / 2, listW + 16, listH, 0x000000, 0.01)
      .setInteractive({ useHandCursor: false })
    this.tabContent.add(scrollHitArea)

    // Touch / drag scrolling with momentum
    this.itemListVelocity = 0
    this.itemListDragging = false
    let listDragStartY = 0
    let listDragStartScroll = 0
    let listLastY = 0
    let listLastTime = 0

    const startListDrag = (pointer) => {
      this.itemListDragging = true
      this.itemListVelocity = 0
      listDragStartY = pointer.y
      listLastY = pointer.y
      listDragStartScroll = this.itemListScroll
      listLastTime = performance.now()
    }

    const moveListDrag = (pointer) => {
      if (!this.itemListDragging) return
      const dy = pointer.y - listDragStartY
      this.setItemListScroll(listDragStartScroll - dy)

      const now = performance.now()
      const dt = now - listLastTime
      if (dt > 0) {
        this.itemListVelocity = -(pointer.y - listLastY) / dt * 16
      }
      listLastY = pointer.y
      listLastTime = now
    }

    const endListDrag = () => {
      this.itemListDragging = false
    }

    scrollHitArea.on('pointerdown', startListDrag)
    scrollHitArea.on('pointermove', moveListDrag)
    scrollHitArea.on('pointerup', endListDrag)
    scrollHitArea.on('pointerupoutside', endListDrag)

    // Scrollbar track (wider for mobile)
    const trackX = listX + listW + 12
    const trackH = listH
    const trackW = 12
    const track = this.add.rectangle(trackX, listY + listH / 2, trackW, trackH, 0x2c3e50, 0.5)
    this.tabContent.add(track)

    // Scrollbar thumb — fixed small size so it clearly travels top-to-bottom
    const thumbH = this.itemListMaxScroll > 0 ? 50 : trackH
    this.itemListThumbH = thumbH
    this.itemListThumb = this.add.rectangle(trackX, listY + thumbH / 2, trackW, thumbH, 0x3498db, 0.9)
    this.tabContent.add(this.itemListThumb)

    // Invisible wider thumb hit area for easier touch grabs
    const thumbHitH = Math.max(thumbH + 16, 56)
    const thumbHit = this.add.rectangle(trackX, listY + thumbH / 2, 28, thumbHitH, 0x000000, 0)
      .setInteractive({ useHandCursor: true })
    this.tabContent.add(thumbHit)

    // Draggable scrollbar thumb
    let thumbDragStartY = 0
    let thumbDragStartScroll = 0
    const startThumbDrag = (pointer) => {
      this.itemListDragging = true
      this.itemListVelocity = 0
      thumbDragStartY = pointer.y
      thumbDragStartScroll = this.itemListScroll
    }
    const moveThumbDrag = (pointer) => {
      if (!this.itemListDragging) return
      const dy = pointer.y - thumbDragStartY
      const trackRatio = this.itemListMaxScroll / (trackH - thumbH)
      this.setItemListScroll(thumbDragStartScroll + dy * trackRatio)
    }
    const endThumbDrag = () => {
      this.itemListDragging = false
    }

    thumbHit.on('pointerdown', startThumbDrag)
    thumbHit.on('pointermove', moveThumbDrag)
    thumbHit.on('pointerup', endThumbDrag)
    thumbHit.on('pointerupoutside', endThumbDrag)

    // Row hit areas live above the scroll overlay so Add/Remove clicks register.
    this.itemListY = listY
    this.itemListRows.forEach((row, i) => {
      row.hitArea.setPosition(listX + 230, listY + i * itemHeight + row.rowH / 2)
      this.tabContent.add(row.hitArea)
    })

    this.updateItemListScrollThumb(listY, listH, thumbH)
    this.setItemListScroll(0)

    // Active count indicator
    const countText = this.add.text(690, 470, `${activeItemIds.length}/5 Active`, {
      ...FONTS.default,
      fontSize: '14px',
      color: activeItemIds.length > 5 ? '#e74c3c' : '#7f8c8d',
    }).setOrigin(0.5)
    this.tabContent.add(countText)
  }

  scrollItemList(delta) {
    this.setItemListScroll(this.itemListScroll + delta)
  }

  setItemListScroll(value) {
    if (!this.itemListContainer) return
    this.itemListScroll = Math.max(0, Math.min(this.itemListMaxScroll, value))
    this.itemListContainer.setY(80 - this.itemListScroll)

    // Visibility culling: hide rows outside the visible area and keep the
    // overlay hit areas in sync with the scrolled list.
    const visibleH = this.itemListVisibleHeight
    const rowH = this.itemListItemHeight
    const listY = this.itemListY
    const listX = 460
    this.itemListRows.forEach((row, i) => {
      const relY = i * rowH - this.itemListScroll
      const visible = relY + rowH > 0 && relY < visibleH
      row.container.setVisible(visible)
      if (row.hitArea) {
        row.hitArea.setVisible(visible)
        row.hitArea.input.enabled = visible
        row.hitArea.setPosition(listX + 230, listY - this.itemListScroll + i * rowH + row.rowH / 2)
      }
    })

    this.updateItemListScrollThumb()
  }

  updateItemListScrollThumb(listY = 80, listH = 348) {
    if (!this.itemListThumb || this.itemListMaxScroll <= 0) return
    const thumbH = this.itemListThumbH || 40
    const trackH = listH
    const pct = this.itemListScroll / this.itemListMaxScroll
    const thumbY = listY + thumbH / 2 + pct * (trackH - thumbH)
    this.itemListThumb.setY(thumbY)
  }

  createItemRow(x, y, item, isActive) {
    const container = this.add.container(x, y)
    const rowH = 54

    // Background
    const bg = this.add.graphics()
    bg.fillStyle(isActive ? 0x2980b9 : 0x16213e, 0.8)
    bg.fillRoundedRect(0, 0, 460, rowH, 8)
    bg.lineStyle(1.5, isActive ? 0x3498db : 0x2c3e50, 0.5)
    bg.strokeRoundedRect(0, 0, 460, rowH, 8)
    container.add(bg)

    // Icon
    const icon = this.add.text(28, rowH / 2, item.icon, { fontSize: '22px' }).setOrigin(0.5)
    container.add(icon)

    // Name with quantity
    const count = this.player.loadout.inventory?.[item.id] || 0
    const countLabel = item.infinite ? '∞' : `x${count}`
    const name = this.add.text(56, 14, `${item.name} ${countLabel}`, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ecf0f1',
    })
    container.add(name)

    // Description
    const desc = this.add.text(56, 34, item.description, {
      ...FONTS.default,
      fontSize: '11px',
      color: '#7f8c8d',
    })
    container.add(desc)

    // Stamina cost
    const cost = this.add.text(360, rowH / 2, `${item.staminaCost} STA`, {
      ...FONTS.default,
      fontSize: '12px',
      color: '#f1c40f',
    }).setOrigin(0.5)
    container.add(cost)

    // Toggle button
    const toggleColor = isActive ? 0xe74c3c : 0x27ae60
    const toggleLabel = isActive ? 'Remove' : 'Add'
    const toggleBtn = this.createMiniButton(420, rowH / 2, toggleLabel, toggleColor, () => {
      this.toggleActiveItem(item.id)
    })
    container.add(toggleBtn.container)

    // Make whole row clickable for toggling. The hit area is returned so it
    // can be placed above the scroll overlay, which otherwise swallows clicks.
    const hitArea = this.add.rectangle(230, rowH / 2, 460, rowH, 0x000000, 0).setInteractive({ useHandCursor: true })
    hitArea.on('pointerdown', () => this.toggleActiveItem(item.id))

    return { container, bg, hitArea, rowH }
  }

  toggleActiveItem(itemId) {
    const ids = this.player.loadout.activeItemIds
    const idx = ids.indexOf(itemId)
    if (idx >= 0) {
      ids.splice(idx, 1)
    } else {
      if (ids.length >= 5) {
        this.showToast('Max 5 active items')
        return
      }
      ids.push(itemId)
    }
    this.player.saveLoadout()
    this.showTab('items')
  }

  // ---------- Charms Tabs ----------

  createCharmsTab(charmType, options = {}) {
    const { startY = 80, container = this.tabContent } = options
    const isSocketTab = charmType === 'primary_weapon' || charmType === 'secondary_weapon'
    let charms
    if (isSocketTab) {
      const equipmentType = charmType
      charms = (this.player.loadout.ownedSocketCharmIds || [])
        .map(id => getSocketCharmById(id))
        .filter(c => c && c.equipmentType === equipmentType)
    } else {
      const ownedIds = new Set(this.player.loadout.ownedCharmIds || [])
      charms = getCharmsByType(charmType).filter(c => ownedIds.has(c.id))
    }
    const cols = 2
    const cellW = 230
    const cellH = 90
    const startX = 470

    charms.forEach((charm, i) => {
      const col = i % cols
      const row = Math.floor(i / cols)
      const x = startX + col * cellW
      const y = startY + row * cellH
      const card = this.createCharmCard(x, y, charm, charmType)
      container.add(card.container)
    })

    // Slot info text
    const slotInfo = charmType === CHARM_TYPES.HERO
      ? `Slots: ${this.player.loadout.heroCharmIds.filter(Boolean).length}/${this.player.getHeroCharmSlots()}`
      : charmType === 'primary_weapon'
        ? `Sockets: ${(this.player.weapon?.socketCharmIds || []).filter(Boolean).length}/${this.player.getWeaponCharmSlots()}`
        : `Sockets: ${(this.player.shield?.socketCharmIds || []).filter(Boolean).length}/${this.player.getShieldCharmSlots()}`

    const infoText = this.add.text(690, 470, slotInfo, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#7f8c8d',
    }).setOrigin(0.5)
    container.add(infoText)
  }

  createWeaponsTab() {
    this.weaponsSubTab = this.weaponsSubTab || 'primary_weapon'

    const subTabY = 80
    const subTabW = 100
    const startX = 710 - subTabW / 2 - 70

    const createSubTabBtn = (key, label, x) => {
      const text = this.add.text(x, subTabY, label, {
        ...FONTS.default,
        fontSize: '14px',
        color: key === this.weaponsSubTab ? '#f39c12' : '#7f8c8d',
      }).setOrigin(0.5)
      const hitArea = this.add.rectangle(x, subTabY, subTabW, 32, 0x000000, 0)
        .setInteractive({ useHandCursor: true })
        .on('pointerdown', () => this.showWeaponsSubTab(key))
      this.tabContent.add([text, hitArea])
      return { key, text }
    }

    this.weaponsSubTabButtons = [
      createSubTabBtn('primary_weapon', 'Primary', startX),
      createSubTabBtn('secondary_weapon', 'Secondary', startX + subTabW + 20),
    ]

    this.weaponsContent = this.add.container(0, 0)
    this.tabContent.add(this.weaponsContent)

    this.showWeaponsSubTab(this.weaponsSubTab)
  }

  showWeaponsSubTab(subType) {
    this.weaponsSubTab = subType

    if (this.weaponsSubTabButtons) {
      this.weaponsSubTabButtons.forEach(({ key, text }) => {
        text.setColor(key === subType ? '#f39c12' : '#7f8c8d')
      })
    }

    if (this.weaponsContent) {
      this.weaponsContent.removeAll(true)
    }

    this.createCharmsTab(subType, { startY: 120, container: this.weaponsContent })
  }

  createCharmCard(x, y, charm, targetType) {
    const container = this.add.container(x, y)
    const colorHex = '#' + charm.color.toString(16).padStart(6, '0')
    const isSocketCharm = !!charm.equipmentType
    const isEquipped = isSocketCharm
      ? this.player.hasSocketCharmEquipped(charm.id)
      : this.player.getEquippedCharms().some(c => c.id === charm.id)
    const cardW = 220
    const cardH = 80

    // Background
    const bg = this.add.graphics()
    bg.fillStyle(isEquipped ? 0x2c3e50 : 0x16213e, 0.9)
    bg.fillRoundedRect(0, 0, cardW, cardH, 8)
    bg.lineStyle(1.5, charm.color, isEquipped ? 0.8 : 0.3)
    bg.strokeRoundedRect(0, 0, cardW, cardH, 8)
    container.add(bg)

    // Kanji
    const kanji = this.add.text(28, 40, charm.kanji, {
      fontFamily: FONTS.kanji.fontFamily,
      fontSize: '32px',
      color: colorHex,
      stroke: colorHex,
      strokeThickness: 3,
    }).setOrigin(0.5)
    container.add(kanji)

    // Name
    const name = this.add.text(80, 22, charm.name, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ecf0f1',
    })
    container.add(name)

    // Effect / description
    let effectText = ''
    if (charm.effect) {
      if (Array.isArray(charm.effect.stats)) {
        effectText = charm.effect.stats.join('/') + ' +' + charm.effect.value
      } else {
        effectText = charm.effect.stat + ' +' + charm.effect.value
      }
    } else if (charm.description) {
      effectText = charm.description
    }
    const effect = this.add.text(80, 44, effectText, {
      ...FONTS.default,
      fontSize: '11px',
      color: '#7f8c8d',
      wordWrap: { width: 130 },
    })
    container.add(effect)

    // Equipped indicator
    if (isEquipped) {
      const check = this.add.text(200, 62, '✓', {
        fontSize: '16px',
        color: '#2ecc71',
      }).setOrigin(0.5)
      container.add(check)
    }

    // Draggable / tappable hit area
    const hitArea = this.add.rectangle(cardW / 2, cardH / 2, cardW, cardH, 0x000000, 0).setInteractive({ useHandCursor: true, draggable: true })
    container.add(hitArea)

    hitArea.on('dragstart', (pointer) => {
      this.startDrag(charm, targetType, container, pointer.x, pointer.y)
    })
    hitArea.on('drag', (pointer) => {
      if (this.dragClone) {
        this.dragClone.setPosition(pointer.x, pointer.y)
      }
    })
    hitArea.on('dragend', (pointer) => {
      this.endDrag(charm, targetType, pointer)
    })

    // Tap-to-equip fallback (mobile-friendly)
    hitArea.on('pointerup', (pointer) => {
      // Only treat as tap if there was very little movement
      const moveDist = Math.hypot(pointer.x - pointer.downX, pointer.y - pointer.downY)
      if (moveDist < 8) {
        this.tapEquipCharm(charm, targetType)
      }
    })

    return { container, bg, hitArea }
  }

  startDrag(charm, targetType, sourceContainer, x, y) {
    const colorHex = '#' + charm.color.toString(16).padStart(6, '0')
    this.dragClone = this.add.text(0, 0, charm.kanji, {
      fontFamily: FONTS.kanji.fontFamily,
      fontSize: '28px',
      color: '#ffffff',
      stroke: colorHex,
      strokeThickness: 4,
    }).setOrigin(0.5)
    this.dragClone.setPosition(x, y)
    this.dragClone.setDepth(1000)
    this.dragItem = { charm, targetType, sourceContainer }
  }

  endDrag(charm, targetType, pointer) {
    if (this.dragClone) {
      this.syncSlotCharmIds()
      const droppedSlot = this.findDropSlot(pointer.x, pointer.y, targetType)

      if (droppedSlot) {
        this.equipCharmToSlot(charm, targetType, droppedSlot)
      }

      this.dragClone.destroy()
      this.dragClone = null
      this.dragItem = null
      this.syncSlotCharmIds()
      this.refreshCharmGlows()
      this.showTab(this.currentTab)
    }
  }

  tapEquipCharm(charm, targetType) {
    // Ensure slot state is fresh before looking for empty slots
    this.syncSlotCharmIds()

    // Socket charms (weapon/shield)
    if (charm.equipmentType) {
      const maxSlots = targetType === 'primary_weapon'
        ? this.player.getWeaponCharmSlots()
        : this.player.getShieldCharmSlots()
      const emptySlot = this.charmSlots.find(slot =>
        slot.type === targetType && slot.unlocked && slot.index < maxSlots && !slot.charmId
      )
      if (emptySlot) {
        this.equipCharmToSlot(charm, targetType, emptySlot)
      } else {
        const firstSlot = this.charmSlots.find(slot =>
          slot.type === targetType && slot.unlocked && slot.index < maxSlots
        )
        if (firstSlot) {
          this.equipCharmToSlot(charm, targetType, firstSlot)
        } else {
          this.showToast('No free charm slots')
          return
        }
      }
      this.syncSlotCharmIds()
      this.refreshCharmGlows()
      this.showTab(this.currentTab)
      return
    }

    // Legacy hero/weapon/shield charms
    const emptySlot = this.charmSlots.find(slot =>
      slot.type === targetType && slot.unlocked && !slot.charmId
    )
    if (emptySlot) {
      this.equipCharmToSlot(charm, targetType, emptySlot)
      this.syncSlotCharmIds()
      this.refreshCharmGlows()
      this.showTab(this.currentTab)
      return
    }

    // If no empty slot, find first slot of this type and replace
    const firstSlot = this.charmSlots.find(slot =>
      slot.type === targetType && slot.unlocked
    )
    if (firstSlot) {
      this.equipCharmToSlot(charm, targetType, firstSlot)
      this.syncSlotCharmIds()
      this.refreshCharmGlows()
      this.showTab(this.currentTab)
      return
    }

    this.showToast('No free charm slots')
  }

  findDropSlot(x, y, targetType) {
    return this.charmSlots.find(slot => {
      if (!slot.unlocked) return false
      if (slot.type !== targetType) return false
      const dx = slot.x - x
      const dy = slot.y - y
      return Math.sqrt(dx * dx + dy * dy) < (slot.radius + 10)
    })
  }

  equipCharmToSlot(charm, targetType, slot) {
    this.unequipCharmIfEquipped(charm.id)

    // Socket charms on weapon/shield equipment
    if (slot.equipment) {
      if (charm.equipmentType !== slot.type) {
        this.showToast('That charm does not fit there.')
        return
      }
      if (charm.slot && charm.slot !== slot.index + 1) {
        this.showToast('That charm fits a different socket.')
        return
      }
      const result = this.player.equipSocketCharm(slot.equipment, slot.index, charm.id)
      if (!result.ok) {
        this.showToast(result.reason)
        return
      }
      this.showToast(`${charm.name} equipped`)
      return
    }

    // Legacy hero/weapon/shield charm slots
    const loadoutKey = targetType === 'hero' ? 'heroCharmIds' : targetType === 'weapon' ? 'weaponCharmIds' : 'shieldCharmIds'
    const arr = this.player.loadout[loadoutKey]
    const oldIdx = arr.indexOf(charm.id)
    if (oldIdx >= 0) arr.splice(oldIdx, 1)
    arr[slot.index] = charm.id
    this.player._charmEffects = null
    this.player.saveLoadout()
    this.showToast(`${charm.name} equipped`)
  }

  unequipCharmIfEquipped(charmId) {
    // Socket charms on weapon/shield
    for (const equipment of [this.player.weapon, this.player.shield]) {
      const ids = equipment?.socketCharmIds
      if (!ids) continue
      const idx = ids.indexOf(charmId)
      if (idx >= 0) {
        ids[idx] = null
        this.player.saveLoadout()
        this.syncSlotCharmIds()
        return
      }
    }

    // Legacy hero/weapon/shield charms
    for (const type of ['hero', 'weapon', 'shield']) {
      const key = type === 'hero' ? 'heroCharmIds' : type === 'weapon' ? 'weaponCharmIds' : 'shieldCharmIds'
      const arr = this.player.loadout[key]
      const idx = arr.indexOf(charmId)
      if (idx >= 0) {
        arr[idx] = null
        this.player._charmEffects = null
        this.player.saveLoadout()
        this.syncSlotCharmIds()
        return
      }
    }
  }

  // ---------- Abilities Tab ----------

  createAbilitiesTab() {
    // Ensure Use Item is always in the battle pool
    if (!this.player.loadout.selectedActionIds.includes('use_item')) {
      this.player.loadout.selectedActionIds.push('use_item')
      this.player.saveLoadout()
    }

    const capacity = this.player.capacity || 3
    const maxActive = getMaxActiveActions(capacity)
    const maxBattle = getMaxBattlePoolActions(capacity)
    const maxOverall = getMaxOverallAbilities(capacity)
    const activeIds = this.player.loadout.activeActionIds
    const selectedIds = this.player.loadout.selectedActionIds
    const knownIds = this.player.loadout.knownActionIds || []
    const useItemActive = activeIds.includes('use_item')

    // Header
    this.tabContent.add(
      this.add.text(690, 72, 'Known Abilities', {
        ...FONTS.default,
        fontSize: '14px',
        color: '#3498db',
      }).setOrigin(0.5)
    )

    const listX = 460
    const listY = 95
    const listW = 460
    const rowH = 56
    const rowsPerPage = 6
    const listH = rowsPerPage * rowH

    let actions = knownIds
      .map(id => ALL_ACTIONS.find(a => a.id === id))
      .filter(Boolean)

    // Use Item is always available but not part of the known pool.
    const useItemAction = ALL_ACTIONS.find(a => a.id === 'use_item')
    if (useItemAction && !actions.some(a => a.id === 'use_item')) {
      actions = [useItemAction, ...actions]
    }

    // Paged container
    this.abilityListContainer = this.add.container(listX, listY)
    this.tabContent.add(this.abilityListContainer)

    this.abilityListX = listX
    this.abilityListY = listY
    this.abilityRowH = rowH
    this.abilityRowsPerPage = rowsPerPage
    this.abilityPage = 0
    this.abilityTotalPages = Math.max(1, Math.ceil(actions.length / rowsPerPage))

    const availableIds = new Set(getAvailableActions(this.player).map(a => a.id))

    this.abilityListRows = []
    actions.forEach((action, i) => {
      const isAvailable = availableIds.has(action.id)
      const row = this.createAbilityRow(0, 0, action, rowH, isAvailable)
      this.abilityListContainer.add(row.container)
      this.abilityListRows.push(row)
      this.tabContent.add(row.hitArea)
    })

    // Pagination means rows never overflow the visible area, so no mask is
    // needed. Phaser 4's geometry mask also warns/crashes in WebGL.

    // Pagination controls (must be created before setAbilityPage so the page
    // text/button references are fresh, not pointing at destroyed objects).
    const controlsY = listY + listH + 18
    this.createAbilityPaginationControls(controlsY)

    this.setAbilityPage(0)

    // Info footer
    const combatSelected = selectedIds.filter(id => id !== 'use_item').length
    const combatActiveCount = activeIds.filter(id => id !== 'use_item').length
    const color = knownIds.length > maxOverall ? '#e74c3c' : '#7f8c8d'
    this.tabContent.add(
      this.add.text(690, 470, `${knownIds.length}/${maxOverall} Known · ${combatSelected}/${maxBattle} Battle · ${combatActiveCount}/${maxActive} Active · Item ${useItemActive ? 'ON' : 'OFF'}`, {
        ...FONTS.default,
        fontSize: '12px',
        color,
      }).setOrigin(0.5)
    )
  }

  createAbilityRow(x, y, action, rowH, isAvailable = true) {
    const container = this.add.container(x, y)
    const colors = getAbilityRarityColor(action.rarity)
    const rowW = 460
    const isInBattle = this.player.loadout.selectedActionIds.includes(action.id)
    const isActive = this.player.loadout.activeActionIds.includes(action.id)

    const bg = this.add.graphics()
    const fillColor = !isAvailable
      ? 0x1a1a1e
      : isActive
        ? colors.main
        : isInBattle
          ? 0x1a2a3a
          : 0x16213e
    bg.fillStyle(fillColor, 0.9)
    bg.fillRoundedRect(0, 0, rowW, rowH - 4, 6)
    bg.lineStyle(2, isAvailable ? colors.main : 0x555555, isActive ? 0.9 : 0.4)
    bg.strokeRoundedRect(0, 0, rowW, rowH - 4, 6)
    container.add(bg)

    // Kanji
    if (action.kanji) {
      container.add(
        this.add.text(30, rowH / 2 - 2, action.kanji, {
          fontFamily: FONTS.kanji.fontFamily,
          fontSize: '24px',
          color: isAvailable ? '#ffffff' : '#7f8c8d',
        }).setOrigin(0.5)
      )
    }

    // Name
    container.add(
      this.add.text(70, 16, action.name, {
        ...FONTS.default,
        fontSize: '13px',
        color: isAvailable ? '#ecf0f1' : '#7f8c8d',
      })
    )

    // Type + STA cost
    container.add(
      this.add.text(70, 36, `${action.type.toUpperCase()} · ${action.staminaCost} STA`, {
        ...FONTS.default,
        fontSize: '11px',
        color: '#7f8c8d',
      })
    )

    // Status badge
    let badgeText = isActive ? 'ACTIVE' : isInBattle ? 'BATTLE' : 'RESERVE'
    let badgeColor = isActive ? '#f1c40f' : isInBattle ? '#3498db' : '#7f8c8d'
    if (!isAvailable) {
      badgeText = 'LOCKED'
      badgeColor = '#e74c3c'
    }
    container.add(
      this.add.text(rowW - 52, rowH / 2 - 2, badgeText, {
        ...FONTS.default,
        fontSize: '11px',
        color: badgeColor,
      }).setOrigin(0.5)
    )

    // Clickable hit area (drag-and-drop removed due to slot-mapping bugs)
    const hitArea = this.add.rectangle(0, 0, rowW, rowH, 0x000000, 0)
      .setInteractive({ useHandCursor: true })

    this.abilityTooltip.attach(hitArea, action)

    hitArea.on('pointerup', (pointer) => {
      const moveDist = Math.hypot(pointer.x - pointer.downX, pointer.y - pointer.downY)
      if (hitArea.getData('abilityTooltipSuppressClick')) {
        hitArea.setData('abilityTooltipSuppressClick', false)
        return
      }
      if (moveDist < 8) {
        this.showAbilityDetailDialog(action, isAvailable)
      }
    })

    return { container, hitArea, rowH }
  }

  setAbilityPage(page) {
    if (!this.abilityListRows) return
    const total = this.abilityTotalPages || 1
    page = Math.max(0, Math.min(total - 1, page))
    this.abilityPage = page

    const rowH = this.abilityRowH
    const rowsPerPage = this.abilityRowsPerPage
    const startIdx = page * rowsPerPage
    const rowW = 460

    this.abilityListRows.forEach((row, i) => {
      const onPage = i >= startIdx && i < startIdx + rowsPerPage
      row.container.setVisible(onPage)
      row.hitArea.setVisible(onPage)
      if (row.hitArea.input) row.hitArea.input.enabled = onPage

      if (onPage) {
        const localIndex = i - startIdx
        row.container.setY(localIndex * rowH)
        row.hitArea.setPosition(this.abilityListX + rowW / 2, this.abilityListY + localIndex * rowH + rowH / 2)
      }
    })

    if (this.abilityPageText) {
      this.abilityPageText.setText(`Page ${page + 1} / ${total}`)
    }
    if (this.abilityPaginationButtons) {
      const prevBg = this.abilityPaginationButtons.prev?.list?.[0]
      const nextBg = this.abilityPaginationButtons.next?.list?.[0]
      if (prevBg) {
        prevBg.setFillStyle(page === 0 ? 0x555555 : 0x3498db)
        prevBg.input.enabled = page !== 0
      }
      if (nextBg) {
        nextBg.setFillStyle(page === total - 1 ? 0x555555 : 0x3498db)
        nextBg.input.enabled = page !== total - 1
      }
    }
  }

  createAbilityPaginationControls(y) {
    const total = this.abilityTotalPages
    if (total <= 1) return

    const prevBtn = this.createPageButton(560, y, '<', () => this.setAbilityPage(this.abilityPage - 1))
    const nextBtn = this.createPageButton(820, y, '>', () => this.setAbilityPage(this.abilityPage + 1))

    this.abilityPageText = this.add.text(690, y, `Page ${this.abilityPage + 1} / ${total}`, {
      ...FONTS.default,
      fontSize: '13px',
      color: '#ecf0f1',
    }).setOrigin(0.5)

    this.tabContent.add([prevBtn, nextBtn, this.abilityPageText])
    this.abilityPaginationButtons = { prev: prevBtn, next: nextBtn }
  }

  createPageButton(x, y, label, onClick) {
    const w = 48
    const h = 28
    const bg = this.add.rectangle(0, 0, w, h, 0x3498db, 0.9)
    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ffffff',
    }).setOrigin(0.5)
    const container = this.add.container(x, y, [bg, text])
    container.setSize(w, h)
    bg.setInteractive({ useHandCursor: true })
    bg.on('pointerup', () => onClick())
    return container
  }

  showAbilityDetailDialog(action, isAvailable = true) {
    if (this.abilityDialog) this.abilityDialog.destroy()
    this.disableAbilityRowsForDialog(true)

    const overlay = this.add.container(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2).setDepth(2000)

    // Dark backdrop — captures clicks outside the panel and closes on release.
    const backdrop = this.add.rectangle(0, 0, GAME_CONFIG.width, GAME_CONFIG.height, 0x000000, 0.85).setOrigin(0.5)
    backdrop.setInteractive()
    backdrop.on('pointerdown', () => {})
    backdrop.on('pointerup', () => this.closeAbilityDialog())
    overlay.add(backdrop)

    // Panel — captures clicks between buttons so they don't fall through to the ability list.
    const panel = this.add.rectangle(0, 0, 440, 460, 0x1a1a2e).setStrokeStyle(2, 0xf39c12).setOrigin(0.5)
    panel.setInteractive()
    panel.on('pointerdown', () => {})
    panel.on('pointerup', () => {})
    overlay.add(panel)

    // Kanji
    overlay.add(
      this.add.text(0, -190, action.kanji || '', {
        fontFamily: FONTS.kanji.fontFamily,
        fontSize: '48px',
        color: '#ffffff',
      }).setOrigin(0.5)
    )

    // Name
    overlay.add(
      this.add.text(0, -135, action.name, {
        ...FONTS.default,
        fontSize: '18px',
        color: '#ecf0f1',
        fontStyle: 'bold',
      }).setOrigin(0.5)
    )

    // Type & cost
    overlay.add(
      this.add.text(0, -105, `${action.type.toUpperCase()} · ${action.staminaCost} STA`, {
        ...FONTS.default,
        fontSize: '13px',
        color: '#7f8c8d',
      }).setOrigin(0.5)
    )

    // Requirements
    const reqs = formatAbilityRequirements(action)
    overlay.add(
      this.add.text(0, -70, `Requirements: ${reqs}`, {
        ...FONTS.default,
        fontSize: '12px',
        color: '#bdc3c7',
        align: 'center',
        wordWrap: { width: 400 },
      }).setOrigin(0.5)
    )

    // Description
    overlay.add(
      this.add.text(0, 10, action.description || '', {
        ...FONTS.default,
        fontSize: '13px',
        color: '#ecf0f1',
        align: 'center',
        wordWrap: { width: 380 },
      }).setOrigin(0.5)
    )

    const inBattle = this.player.loadout.selectedActionIds.includes(action.id)
    const isActive = this.player.loadout.activeActionIds.includes(action.id)
    const maxActive = getMaxActiveActions(this.player.capacity || 3)
    const maxBattle = getMaxBattlePoolActions(this.player.capacity || 3)

    let btnY = 115
    const addDialogBtn = (label, color, onClick) => {
      const btn = this.createMiniButton(0, btnY, label, color, onClick)
      overlay.add(btn.container)
      btnY += 42
    }

    // Family-locked or otherwise unavailable abilities cannot be equipped.
    if (!isAvailable) {
      overlay.add(
        this.add.text(0, 80, 'Requirements not met', {
          ...FONTS.default,
          fontSize: '13px',
          color: '#e74c3c',
        }).setOrigin(0.5)
      )
      addDialogBtn('Close', 0x7f8c8d, () => this.closeAbilityDialog())
      this.abilityDialog = overlay
      this.disableAbilityRowsForDialog(true)
      return
    }

    // Use Item is always available in the battle pool and occupies its own slot.
    if (action.id === 'use_item') {
      if (isActive) {
        addDialogBtn('Deactivate', 0xf39c12, () => {
          this.deactivateAbility(action.id)
          this.closeAbilityDialog()
          this.showTab('abilities')
          this.refreshActionSlots()
        })
      } else {
        addDialogBtn('Activate', 0x3498db, () => {
          this.activateAbility(action.id)
          this.closeAbilityDialog()
          this.showTab('abilities')
          this.refreshActionSlots()
        })
      }
      addDialogBtn('Close', 0x7f8c8d, () => this.closeAbilityDialog())
      this.abilityDialog = overlay
      this.disableAbilityRowsForDialog(true)
      return
    }

    if (!inBattle) {
      const combatSelected = this.player.loadout.selectedActionIds.filter(id => id !== 'use_item').length
      const battleFull = combatSelected >= maxBattle
      addDialogBtn(battleFull ? 'Battle Pool Full' : 'Equip for Battle', battleFull ? 0x555555 : 0x27ae60, () => {
        if (battleFull) return
        const res = this.player.addToBattlePool(action.id)
        if (!res.ok) {
          this.showToast(res.reason)
          return
        }
        this.closeAbilityDialog()
        this.showTab('abilities')
        this.refreshActionSlots()
      })
    } else {
      addDialogBtn('Unequip from Battle', 0xe74c3c, () => {
        const actionObj = ALL_ACTIONS.find(a => a.id === action.id)
        if (actionObj?.type === 'attack') {
          const remainingKnownAttacks = this.player.loadout.knownActionIds
            .filter(id => id !== action.id)
            .map(id => ALL_ACTIONS.find(a => a.id === id))
            .filter(a => a?.type === 'attack')
          if (remainingKnownAttacks.length === 0) {
            this.showToast('At least one attack must be known')
            return
          }
        }
        this.player.removeFromBattlePool(action.id)
        this.closeAbilityDialog()
        this.showTab('abilities')
        this.refreshActionSlots()
      })

      if (isActive) {
        addDialogBtn('Deactivate', 0xf39c12, () => {
          this.deactivateAbility(action.id)
          this.closeAbilityDialog()
          this.showTab('abilities')
          this.refreshActionSlots()
        })
      } else {
        const combatActiveCount = this.player.loadout.activeActionIds.filter(id => id !== 'use_item').length
        const activeFull = combatActiveCount >= maxActive
        addDialogBtn(activeFull ? 'Active Slots Full' : 'Activate', activeFull ? 0x555555 : 0x3498db, () => {
          if (activeFull) return
          this.activateAbility(action.id)
          this.closeAbilityDialog()
          this.showTab('abilities')
          this.refreshActionSlots()
        })
      }
    }

    addDialogBtn('Close', 0x7f8c8d, () => this.closeAbilityDialog())

    this.abilityDialog = overlay
    this.disableAbilityRowsForDialog(true)
  }

  disableAbilityRowsForDialog(disabled) {
    this.abilityDialogOpen = disabled
    if (this.abilityListRows) {
      this.abilityListRows.forEach(row => {
        if (row.hitArea && row.hitArea.input) row.hitArea.input.enabled = !disabled
      })
    }
  }

  closeAbilityDialog() {
    if (this.abilityDialog) {
      this.abilityDialog.destroy()
      this.abilityDialog = null
    }
    this.disableAbilityRowsForDialog(false)
    if (this.abilityListContainer && this.abilityListContainer.scene) {
      this.setAbilityPage(this.abilityPage)
    }
  }

  refreshActionSlots() {
    // Rebuild the left panel action slot indicators
    this.actionSlots.forEach(slot => {
      slot.text.destroy()
      slot.graphics.destroy()
      if (slot.hitArea) slot.hitArea.destroy()
    })
    this.actionSlots = []
    this.createActiveActionSlots()
  }

  // ---------- Stats Tab ----------

  createStatsTab() {
    const capacity = this.player.capacity || 3
    const stats = [
      { key: 'vitality', label: 'Vitality', derived: `HP: ${this.player.maxHp}` },
      { key: 'stamina', label: 'Stamina', derived: `Max STA: ${this.player.maxStamina}` },
      { key: 'capacity', label: 'Capacity', derived: `A:${getMaxActiveActions(capacity)} / B:${getMaxBattlePoolActions(capacity)} / O:${getMaxOverallAbilities(capacity)}` },
      { key: 'skill', label: 'Skill', derived: `Crit: ${Math.round(this.player.getCritChance() * 100)}%` },
      { key: 'strength', label: 'Strength', derived: `Phys Def: ${this.player.getPhysicalDefense()}` },
      { key: 'mana', label: 'Mana', derived: `Elem Def: ${this.player.getElementalDefense()}` },
      { key: 'luck', label: 'Luck', derived: `Infusion+: ${Math.round(this.player.getInfusionChance() * 100)}%` },
    ]

    const startY = 80
    const rowH = 58

    stats.forEach((stat, i) => {
      const y = startY + i * rowH
      const baseVal = this.player.baseStats[stat.key]
      const alloc = this.player.loadout.statAllocations[stat.key] || 0
      const total = baseVal + alloc

      const row = this.add.container(460, y)

      // Background
      const bg = this.add.graphics()
      bg.fillStyle(0x16213e, 0.8)
      bg.fillRoundedRect(0, 0, 460, 52, 8)
      row.add(bg)

      // Label
      row.add(
        this.add.text(16, 14, stat.label, {
          ...FONTS.default,
          fontSize: '14px',
          color: '#ecf0f1',
        })
      )

      // Base + allocation display
      row.add(
        this.add.text(16, 32, `Base ${baseVal} + Alloc ${alloc} = ${total}`, {
          ...FONTS.default,
          fontSize: '11px',
          color: '#7f8c8d',
        })
      )

      // Derived stat
      row.add(
        this.add.text(200, 26, stat.derived, {
          ...FONTS.default,
          fontSize: '12px',
          color: '#3498db',
        }).setOrigin(0, 0.5)
      )

      // + button
      const plusBtn = this.createMiniButton(420, 26, '+', 0x27ae60, () => {
        if (this.player.loadout.statPoints <= 0) {
          this.showToast('No stat points available')
          return
        }
        this.player.loadout.statPoints--
        this.player.loadout.statAllocations[stat.key]++
        // Apply immediately to player stat
        this.player.baseStats[stat.key]++
        this.player[stat.key] = this.player.baseStats[stat.key]
        // Recalculate derived stats
        if (stat.key === 'vitality') {
          this.player.maxHp = 80 + this.player.baseStats.vitality * 5
          if (this.mode === 'map') {
            this.player.hp = this.player.maxHp
          }
        }
        if (stat.key === 'stamina') {
          this.player.maxStamina = 8 + Math.floor(this.player.baseStats.stamina / 3)
          this.player.stamina = this.player.maxStamina
        }
        this.player.saveLoadout()
        this.showTab('stats')
      })
      row.add(plusBtn.container)

      this.tabContent.add(row)
    })

    // Stat points remaining
    this.tabContent.add(
      this.add.text(690, 500, `Stat Points: ${this.player.loadout.statPoints}`, {
        ...FONTS.default,
        fontSize: '16px',
        color: this.player.loadout.statPoints > 0 ? '#f1c40f' : '#7f8c8d',
      }).setOrigin(0.5)
    )
  }

  // ---------- UI Helpers ----------

  createMiniButton(x, y, label, color, onClick) {
    const container = this.add.container(x, y)
    const h = 32

    // Measure label first so the button can expand to fit longer text.
    const text = this.add.text(0, 0, label, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ffffff',
    }).setOrigin(0.5)

    const minW = label === '+' ? 40 : 68
    let w = Math.max(minW, text.width + 24)
    if (w > 360) w = 360 // keep inside narrow dialogs

    const bg = this.add.graphics()
    bg.fillStyle(color, 0.9)
    bg.fillRoundedRect(-w / 2, -h / 2, w, h, 4)
    container.add([bg, text])

    const hitArea = this.add.rectangle(0, 0, w, h, 0x000000, 0).setInteractive({ useHandCursor: true })
    hitArea.on('pointerup', onClick)
    container.add(hitArea)

    return { container, bg, text, hitArea }
  }

  createReadyButton() {
    const btn = this.add.container(220, 460)

    const bg = this.add.graphics()
    bg.fillStyle(0x27ae60, 0.95)
    bg.fillRoundedRect(-80, -20, 160, 40, 8)
    bg.lineStyle(2, 0x2ecc71, 0.8)
    bg.strokeRoundedRect(-80, -20, 160, 40, 8)
    btn.add(bg)

    const buttonText = this.mode === 'map' ? 'Enter Map' : 'Ready for Battle'
    const text = this.add.text(0, 0, buttonText, {
      ...FONTS.default,
      fontSize: '16px',
      fontStyle: 'bold',
      color: '#ffffff',
    }).setOrigin(0.5)
    btn.add(text)

    const hitArea = this.add.rectangle(0, 0, 160, 40, 0x000000, 0).setInteractive({ useHandCursor: true })
    hitArea.on('pointerdown', () => this.startBattle())
    hitArea.on('pointerover', () => {
      bg.clear()
      bg.fillStyle(0x2ecc71, 0.95)
      bg.fillRoundedRect(-80, -20, 160, 40, 8)
      bg.lineStyle(2, 0x27ae60, 0.8)
      bg.strokeRoundedRect(-80, -20, 160, 40, 8)
    })
    hitArea.on('pointerout', () => {
      bg.clear()
      bg.fillStyle(0x27ae60, 0.95)
      bg.fillRoundedRect(-80, -20, 160, 40, 8)
      bg.lineStyle(2, 0x2ecc71, 0.8)
      bg.strokeRoundedRect(-80, -20, 160, 40, 8)
    })
    btn.add(hitArea)

    this.leftPanel.add(btn)
  }

  showToast(message) {
    // Simple floating toast
    const toast = this.add.text(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2 + 40, message, {
      ...FONTS.default,
      fontSize: '14px',
      color: '#ffffff',
      backgroundColor: '#e74c3c',
    }).setOrigin(0.5).setDepth(2000)

    this.tweens.add({
      targets: toast,
      y: toast.y - 30,
      alpha: 0,
      duration: 1200,
      ease: 'Quad.easeOut',
      onComplete: () => toast.destroy(),
    })
  }

  fillActiveActionSlots() {
    const maxSlots = getMaxActiveActions(this.player.capacity || 3)
    const activeIds = this.player.loadout.activeActionIds
    const useItemActive = activeIds.includes('use_item')

    const selected = this.player.loadout.selectedActionIds.filter(id => id !== 'use_item')
    const available = new Set(getAvailableActions(this.player).map(a => a.id))

    // Start from current combat active abilities, keeping only valid ones.
    let combatActive = activeIds
      .filter(id => id !== 'use_item')
      .filter((id, idx, arr) => arr.indexOf(id) === idx)
      .filter(id => selected.includes(id) && available.has(id))

    // Fill remaining slots from the selected pool, preferring attacks.
    const addable = selected.filter(id => available.has(id) && !combatActive.includes(id))
    while (combatActive.length < maxSlots && addable.length > 0) {
      const nextAttackIdx = addable.findIndex(id => {
        const a = ALL_ACTIONS.find(act => act.id === id)
        return a && a.type === 'attack'
      })
      const idx = nextAttackIdx >= 0 ? nextAttackIdx : 0
      combatActive.push(addable[idx])
      addable.splice(idx, 1)
    }

    combatActive = combatActive.slice(0, maxSlots)
    this.player.loadout.activeActionIds = useItemActive ? [...combatActive, 'use_item'] : combatActive
  }

  startBattle() {
    this.fillActiveActionSlots()

    const hasActiveAttack = this.player.loadout.activeActionIds
      .map(id => ALL_ACTIONS.find(a => a.id === id))
      .some(a => a?.type === 'attack')
    if (!hasActiveAttack) {
      this.showToast('At least one attack must be active')
      return
    }
    this.player.saveLoadout()
    this.player.refreshActions()

    if (this.mode === 'map') {
      this.scene.start('MapScene', { player: this.player })
    } else {
      this.scene.start('BattleScene', { player: this.player, tile: this.tile, mapIndex: this.mapIndex })
    }
  }
}
