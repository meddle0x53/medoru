import Character from './Character.js'
import { ITEMS } from '../data/items.js'
import { splitActions, getMaxActiveActions } from '../data/actions.js'
import { getCharmById, canEquipCharm, CHARM_TYPES } from '../data/charms.js'
import { generateMap, MAP_TEMPLATES } from '../systems/MapGenerator.js'

const LOADOUT_KEY = 'medoru_loadout_v1'
const MAP_VERSION = 2

const BASE_STAT_POINTS = 10
const STAT_POINTS_PER_LEVEL = 1

// Scaling letter multipliers
const SCALING_MULTIPLIERS = {
  S: 1.10,
  A: 0.90,
  B: 0.70,
  C: 0.50,
  D: 0.30,
  E: 0.15,
}

// Soft-cap stat factor: returns 0.0–1.0 based on stat value
function getStatFactor(stat) {
  if (stat <= 0) return 0
  if (stat <= 25) {
    // 0–25: grows from 0.0 to 0.5
    return 0.5 * (stat / 25)
  } else if (stat <= 50) {
    // 26–50: grows from 0.5 to 0.85
    return 0.5 + 0.35 * ((stat - 25) / 25)
  } else {
    // 51–99: grows from 0.85 to 1.0
    return 0.85 + 0.15 * (Math.min(stat, 99) - 50) / 49
  }
}

export default class Player extends Character {
  constructor(userData = {}) {
    // Base character stats (Dark Souls style)
    const shirtDefense = 5  // Traveler Shirt
    const baseStats = {
      vitality: 20,
      stamina: 10,
      skill: 10,
      strength: 20,
      mana: 5,
      luck: 5,
    }

    // Long Sword: base damage 20, STR C, SKL D
    const weapon = {
      name: 'Long Sword',
      nameJa: '長剣',
      baseDamage: 20,
      level: 0,
      maxLevel: 10,
      scaling: {
        strength: 'C', // 0.50
        skill: 'D',    // 0.30
      },
      // Kanji powerups this weapon can learn
      kanjiPowerups: [
        { kanji: '力', name: 'chikara', learned: true, effect: 'flat_bonus', hint: { en: 'Make a POWERFUL swing.', ja: '強力な一振りを。' } },
      ],
      // Move hints (language depends on user level)
      moveHints: {
        forward_slash: { en: 'Make a POWERFUL swing.', ja: '強力な一振りを。' },
      },
    }

    // Wooden Shield: base defense 5, STR D scaling
    const shield = {
      name: 'Wooden Shield',
      nameJa: '木盾',
      baseDefense: 5,
      level: 0,
      maxLevel: 10,
      scaling: {
        strength: 'D', // 0.30
      },
      kanjiPowerup: { kanji: '盾', name: 'tate', learned: true, effect: 'flat_defense', bonus: 3, hint: { en: 'Raise your GUARD.', ja: '盾を構えろ。' } },
      moveHint: { en: 'Raise your GUARD.', ja: '盾を構えろ。' },
    }

    // Calculate max HP from vitality
    const maxHp = 80 + baseStats.vitality * 5
    const maxStamina = 8 + Math.floor(baseStats.stamina / 3)

    super({
      name: userData.name || 'Warrior',
      nameJa: '戦士',
      maxHp,
      maxStamina,
      defense: shirtDefense,
      strength: baseStats.strength,
      skill: baseStats.skill,
      mana: baseStats.mana,
      luck: baseStats.luck,
      capacity: 3,
      armor: 1,
      equippedSkills: [],
      weapon,
      armorItem: { name: 'Shirt', bonus: 1 },
      shirt: { name: 'Traveler Shirt', defense: 5 },
      shield: null,
    })

    this.baseStats = baseStats
    this.startingBaseStats = { ...baseStats }
    this.level = userData.level || 1
    this.potionUsesLeft = 3
    this.userData = userData
    const startingStatPoints = BASE_STAT_POINTS + (this.level - 1) * STAT_POINTS_PER_LEVEL

    // Equipment
    this.shield = shield

    // Loadout: persistent battle preparation state
    const starterActionIds = ['forward_slash', 'setup_defence', 'shield_parry', 'use_item']
    this.loadout = this.loadLoadout() || {
      class: 'warrior',
      activeItemIds: ['health_potion', 'stone'],
      heroCharmIds: ['chikara_charm', 'tate_charm', 'hayai_charm', 'un_charm'],
      weaponCharmIds: [],
      shieldCharmIds: [],
      selectedActionIds: [...starterActionIds],
      activeActionIds: ['forward_slash', 'setup_defence', 'shield_parry'],
      statPoints: startingStatPoints,
      statAllocations: { vitality: 0, stamina: 0, skill: 0, strength: 0, mana: 0, luck: 0 },
      permanentStatPointBonus: 0,
      gold: 0,
      inventory: { health_potion: 2, stone: 1 },
      ownedCharmIds: [],
      mapState: null,
      mapVersion: MAP_VERSION,
    }

    // Apply stat allocations to base stats
    for (const [stat, points] of Object.entries(this.loadout.statAllocations)) {
      if (this.baseStats[stat] !== undefined) {
        this.baseStats[stat] += points
        this[stat] = this.baseStats[stat]
      }
    }

    // Recalculate derived stats after allocations
    this.maxHp = 80 + this.baseStats.vitality * 5
    this.hp = this.maxHp
    this.maxStamina = 8 + Math.floor(this.baseStats.stamina / 3)
    this.stamina = this.maxStamina

    // Active / inactive action management
    this.activeActionIds = this.loadout.activeActionIds
    const { active, inactive } = splitActions(this)
    this.activeActions = active
    this.inactiveActions = inactive
    // Keep equippedSkills in sync for Character base class compatibility
    this.equippedSkills = this.activeActions
    this.maxActiveSlots = getMaxActiveActions(this.capacity || 3)

    // Current kanji powerup state during a move
    this.activeKanjiBonus = 0
    this.activeShieldBonus = 0

    // Track setup defence used this turn
    this.setupDefenceUsed = false

    // Readiness: 0 = distracted, 1 = focused (set after End Turn word challenge)
    this.readiness = 0

    // Reaction multiplier: applied during enemy attacks when a reaction challenge triggers
    // 1 = no effect, 2 = correct reaction (doubles readiness effect), 0.5 = wrong reaction (halves it)
    this.reactionMultiplier = 1

    // Track if last reaction challenge was answered correctly (for parry bonus)
    this.lastReactionCorrect = false

    // Word list for readiness challenge
    this.wordList = userData.word_list || []

    // Inventory (demo: health potion + stone)
    this.inventory = [...ITEMS]

    // Current item effect modifier from kanji challenge (-2, 0, +2)
    this.itemEffectModifier = 0

    // Parry setup: player must click Shield Parry during their turn to activate it
    this.parrySetup = false
    this.parryKanjiQuality = null // 'perfect', 'sloppy', or 'fail'

    // Cache computed charm stats so we don't recompute every frame
    this._charmEffects = null

    // Kanji list for item challenges
    this.kanjiList = userData.kanji_list || []
  }

  // ---------- Weapon Damage Calculation ----------

  calculateWeaponDamage(action = null) {
    const w = this.weapon
    if (!w) return 0

    const base = w.baseDamage
    let bonus = 0

    // Apply scaling for each stat
    for (const [stat, grade] of Object.entries(w.scaling)) {
      const multiplier = SCALING_MULTIPLIERS[grade] || 0
      const statValue = this.getStatValue(stat)
      const factor = getStatFactor(statValue)
      bonus += base * multiplier * factor
    }

    // Add active kanji bonus (flat)
    bonus += this.activeKanjiBonus

    let total = base + bonus

    // Apply action-specific power modifier (e.g. Heavy Slash = 2x Forward Slash base)
    if (action && action.basePower) {
      const actionMultiplier = action.basePower / 8 // 8 is Forward Slash basePower
      total = total * actionMultiplier
    }

    // Apply charm damage bonus (percent)
    const charmEffects = this.getCharmEffects()
    if (charmEffects.damageBonus) {
      total *= (1 + charmEffects.damageBonus)
    }

    return Math.floor(total)
  }

  // ---------- Kanji Powerups ----------

  setKanjiBonus(amount) {
    this.activeKanjiBonus = amount
  }

  clearKanjiBonus() {
    this.activeKanjiBonus = 0
    this.lastKanjiWrongStrokes = 0
  }

  setKanjiResult(wrongStrokes) {
    this.lastKanjiWrongStrokes = wrongStrokes
  }

  // ---------- Utility ----------

  usePotion() {
    if (this.potionUsesLeft > 0) {
      this.potionUsesLeft--
      return true
    }
    return false
  }

  getWeaponBonus() {
    return this.weapon ? this.weapon.baseDamage : 0
  }

  getShieldBonus() {
    return this.shield ? this.shield.bonus : 0
  }

  // ---------- Shield Defence Calculation ----------

  calculateShieldDefense() {
    const s = this.shield
    if (!s) return 0

    const base = s.baseDefense
    let bonus = 0

    // Apply scaling for each stat
    for (const [stat, grade] of Object.entries(s.scaling)) {
      const multiplier = SCALING_MULTIPLIERS[grade] || 0
      const statValue = this.getStatValue(stat)
      const factor = getStatFactor(statValue)
      bonus += base * multiplier * factor
    }

    // Add active kanji bonus (flat)
    bonus += this.activeShieldBonus

    return Math.floor(base + bonus)
  }

  setShieldBonus(amount) {
    this.activeShieldBonus = amount
  }

  clearShieldBonus() {
    this.activeShieldBonus = 0
  }

  // Total defense = base + temp + shield base/scaling + shield kanji bonus + readiness bonus + charm bonus
  getTotalDefense() {
    const readinessBonus = this.readiness > 0 ? 5 : 0
    const charmEffects = this.getCharmEffects()
    const charmDefense = charmEffects.defense || 0
    return this.baseDefense + this.tempDefense + this.calculateShieldDefense() + readinessBonus + charmDefense
  }

  resetReadiness() {
    this.readiness = 0
  }

  setReadiness(value) {
    this.readiness = value
  }

  // ---------- Action Management ----------

  refreshActions() {
    const { active, inactive } = splitActions(this)
    this.activeActions = active
    this.inactiveActions = inactive
    this.equippedSkills = active
    this.maxActiveSlots = getMaxActiveActions(this.capacity || 3)
  }

  setActiveActionIds(ids) {
    this.activeActionIds = ids
    this.refreshActions()
  }

  swapActions(activeId, inactiveId) {
    const newActive = this.activeActionIds.filter(id => id !== activeId)
    newActive.push(inactiveId)
    this.setActiveActionIds(newActive)
  }

  // ---------- Parry System ----------

  hasActiveParry() {
    return this.parrySetup
  }

  getParryChance() {
    if (!this.hasActiveParry()) return 0
    const parryAction = this.activeActions.find(a => a.type === 'parry')
    const base = parryAction?.baseParryChance || 0.15
    const luckBonus = (this.luck || 0) / 100
    const readinessBonus = (this.readiness || 0) * 0.10
    const quizBonus = this.lastReactionCorrect ? 0.10 : 0
    let chance = base + luckBonus + readinessBonus + quizBonus
    // Kanji quality bonus
    if (this.parryKanjiQuality === 'perfect') chance += 0.15
    else if (this.parryKanjiQuality === 'fail') chance -= 0.10
    return Math.min(0.60, Math.max(0.05, chance))
  }

  // ---------- Item System ----------

  calculateStoneDamage() {
    const base = 5
    let bonus = 0
    const stoneScaling = { strength: 'D' }
    for (const [stat, grade] of Object.entries(stoneScaling)) {
      const multiplier = SCALING_MULTIPLIERS[grade] || 0
      const statValue = this.getStatValue(stat)
      const factor = getStatFactor(statValue)
      bonus += base * multiplier * factor
    }
    return Math.floor(base + bonus)
  }

  setItemEffectModifier(value) {
    this.itemEffectModifier = value
  }

  clearItemEffectModifier() {
    this.itemEffectModifier = 0
  }

  getItemHealAmount(baseValue) {
    return Math.max(1, baseValue + this.itemEffectModifier)
  }

  getItemDamage(baseValue) {
    const stoneDmg = this.calculateStoneDamage()
    return Math.max(1, stoneDmg + this.itemEffectModifier)
  }

  // ---------- Loadout Persistence ----------

  loadLoadout() {
    try {
      const raw = localStorage.getItem(LOADOUT_KEY)
      if (raw) {
        const loadout = JSON.parse(raw)
        // Migration: ensure permanent bonus field exists
        if (typeof loadout.permanentStatPointBonus !== 'number') {
          loadout.permanentStatPointBonus = 0
        }
        // Migration: recalc available stat points based on level + permanent bonus,
        // preserving points already spent.
        const expectedTotal = BASE_STAT_POINTS + (this.level - 1) * STAT_POINTS_PER_LEVEL + loadout.permanentStatPointBonus
        const spent = Object.values(loadout.statAllocations || {}).reduce((a, b) => a + b, 0)
        const expectedRemaining = Math.max(0, expectedTotal - spent)
        if (typeof loadout.statPoints !== 'number' || loadout.statPoints < expectedRemaining) {
          loadout.statPoints = expectedRemaining
        }
        // Migration: ensure new rogue-like fields exist
        if (!loadout.class) loadout.class = 'warrior'
        if (typeof loadout.gold !== 'number') loadout.gold = 0
        if (!loadout.inventory || typeof loadout.inventory !== 'object') {
          loadout.inventory = { health_potion: 2, stone: 1 }
        }
        if (!Array.isArray(loadout.ownedCharmIds)) {
          loadout.ownedCharmIds = []
        }
        if (!loadout.mapState || typeof loadout.mapState !== 'object') {
          loadout.mapState = null
        }
        // Reset the map when the generation logic changes so players see the new layout.
        if (loadout.mapVersion !== MAP_VERSION) {
          loadout.mapState = null
          loadout.mapVersion = MAP_VERSION
        }
        return loadout
      }
    } catch (e) {
      console.warn('[Player] Failed to load loadout:', e)
    }
    return null
  }

  saveLoadout() {
    try {
      localStorage.setItem(LOADOUT_KEY, JSON.stringify(this.loadout))
    } catch (e) {
      console.warn('[Player] Failed to save loadout:', e)
    }
  }

  // ---------- Charm System ----------

  getHeroCharmSlots() {
    return 4
  }

  getWeaponCharmSlots() {
    return Math.min(3, Math.floor((this.weapon?.level || 0) / 3))
  }

  getShieldCharmSlots() {
    return Math.min(3, Math.floor((this.shield?.level || 0) / 3))
  }

  getEquippedCharms() {
    return [
      ...this.loadout.heroCharmIds.map(id => ({ id, slot: 'hero' })),
      ...this.loadout.weaponCharmIds.map(id => ({ id, slot: 'weapon' })),
      ...this.loadout.shieldCharmIds.map(id => ({ id, slot: 'shield' })),
    ]
      .map(({ id, slot }) => {
        const charm = getCharmById(id)
        return charm ? { ...charm, slot } : null
      })
      .filter(Boolean)
  }

  canEquipCharm(charmId, slotType) {
    const charm = getCharmById(charmId)
    const heroUsed = this.loadout.heroCharmIds.length
    const weaponUsed = this.loadout.weaponCharmIds.length
    const shieldUsed = this.loadout.shieldCharmIds.length
    return canEquipCharm(charm, heroUsed, weaponUsed, shieldUsed, this.weapon?.level || 0, this.shield?.level || 0)
  }

  equipCharm(charmId, slotType) {
    const charm = getCharmById(charmId)
    if (!charm) return { ok: false, reason: 'Charm not found.' }
    if (charm.type !== slotType) {
      return { ok: false, reason: 'This charm cannot go in that slot type.' }
    }
    if (slotType === CHARM_TYPES.HERO) {
      if (this.loadout.heroCharmIds.length >= this.getHeroCharmSlots()) {
        return { ok: false, reason: 'No free hero charm slots.' }
      }
      if (this.loadout.heroCharmIds.includes(charmId)) {
        return { ok: false, reason: 'Already equipped.' }
      }
      this.loadout.heroCharmIds.push(charmId)
    } else if (slotType === CHARM_TYPES.WEAPON) {
      if (this.loadout.weaponCharmIds.length >= this.getWeaponCharmSlots()) {
        return { ok: false, reason: 'No free weapon charm slots.' }
      }
      if (this.loadout.weaponCharmIds.includes(charmId)) {
        return { ok: false, reason: 'Already equipped.' }
      }
      this.loadout.weaponCharmIds.push(charmId)
    } else if (slotType === CHARM_TYPES.SHIELD) {
      if (this.loadout.shieldCharmIds.length >= this.getShieldCharmSlots()) {
        return { ok: false, reason: 'No free shield charm slots.' }
      }
      if (this.loadout.shieldCharmIds.includes(charmId)) {
        return { ok: false, reason: 'Already equipped.' }
      }
      this.loadout.shieldCharmIds.push(charmId)
    }
    this._charmEffects = null
    this.saveLoadout()
    return { ok: true }
  }

  unequipCharm(charmId, slotType) {
    if (slotType === CHARM_TYPES.HERO) {
      this.loadout.heroCharmIds = this.loadout.heroCharmIds.filter(id => id !== charmId)
    } else if (slotType === CHARM_TYPES.WEAPON) {
      this.loadout.weaponCharmIds = this.loadout.weaponCharmIds.filter(id => id !== charmId)
    } else if (slotType === CHARM_TYPES.SHIELD) {
      this.loadout.shieldCharmIds = this.loadout.shieldCharmIds.filter(id => id !== charmId)
    }
    this._charmEffects = null
    this.saveLoadout()
  }

  unequipAllCharms() {
    this.loadout.heroCharmIds = []
    this.loadout.weaponCharmIds = []
    this.loadout.shieldCharmIds = []
    this._charmEffects = null
    this.saveLoadout()
  }

  // Returns a plain object of accumulated charm effects, e.g.
  // { strength: 2, skill: 2, critChance: 0.05, damageBonus: 0.18 }
  getCharmEffects() {
    if (this._charmEffects) return this._charmEffects
    const effects = {}
    for (const charm of this.getEquippedCharms()) {
      const { stat, value } = charm.effect || {}
      if (!stat || value === undefined) continue
      if (typeof value === 'number') {
        effects[stat] = (effects[stat] || 0) + value
      }
    }
    this._charmEffects = effects
    return effects
  }

  // ---------- Inventory & Gold ----------

  addGold(amount) {
    this.loadout.gold = Math.max(0, (this.loadout.gold || 0) + Math.floor(amount))
    this.saveLoadout()
  }

  addItem(itemId, count = 1) {
    if (!this.loadout.inventory) this.loadout.inventory = {}
    this.loadout.inventory[itemId] = (this.loadout.inventory[itemId] || 0) + count
    this.saveLoadout()
  }

  hasItem(itemId) {
    return (this.loadout.inventory?.[itemId] || 0) > 0
  }

  consumeItem(itemId, count = 1) {
    if (!this.hasItem(itemId)) return false
    this.loadout.inventory[itemId] -= count
    if (this.loadout.inventory[itemId] <= 0) {
      delete this.loadout.inventory[itemId]
    }
    this.saveLoadout()
    return true
  }

  // ---------- Ability Learning ----------

  hasAbility(actionId) {
    return this.loadout.selectedActionIds.includes(actionId)
  }

  countCombatAbilities() {
    return this.loadout.selectedActionIds.filter(id => id !== 'use_item').length
  }

  learnAbility(actionId) {
    if (!this.loadout.selectedActionIds.includes(actionId)) {
      this.loadout.selectedActionIds.push(actionId)
    }
    // If it's an attack, make sure at least one attack stays active
    this.refreshActions()
    this.saveLoadout()
  }

  replaceAbility(oldActionId, newActionId) {
    const idx = this.loadout.selectedActionIds.indexOf(oldActionId)
    if (idx >= 0) {
      this.loadout.selectedActionIds[idx] = newActionId
    } else {
      this.loadout.selectedActionIds.push(newActionId)
    }
    // Replace in active list too if present
    const activeIdx = this.loadout.activeActionIds.indexOf(oldActionId)
    if (activeIdx >= 0) {
      this.loadout.activeActionIds[activeIdx] = newActionId
    }
    this.refreshActions()
    this.saveLoadout()
  }

  // ---------- Map / Rogue-like State ----------

  ensureMapState() {
    if (!this.loadout.mapState) {
      this.loadout.mapState = { currentMapIndex: 0, currentTileId: null, maps: [] }
    }
    const ms = this.loadout.mapState
    if (!ms.maps[ms.currentMapIndex]) {
      ms.maps[ms.currentMapIndex] = generateMap(ms.currentMapIndex)
    }
    // Backfill any new template fields (e.g. tile images) added after the map
    // was first generated, so older saves pick them up without a full reset.
    const map = ms.maps[ms.currentMapIndex]
    const template = MAP_TEMPLATES[map.index] || MAP_TEMPLATES[0]
    if (template.battleTileImage && !map.battleTileImage) {
      map.battleTileImage = template.battleTileImage
    }
    if (template.miniBossTileImage && !map.miniBossTileImage) {
      map.miniBossTileImage = template.miniBossTileImage
    }
    if (template.bossTileImage && !map.bossTileImage) {
      map.bossTileImage = template.bossTileImage
    }
    if (template.chestTileImage && !map.chestTileImage) {
      map.chestTileImage = template.chestTileImage
    }
    if (template.shopTileImage && !map.shopTileImage) {
      map.shopTileImage = template.shopTileImage
    }
    if (template.memoryTileImage && !map.memoryTileImage) {
      map.memoryTileImage = template.memoryTileImage
    }
    if (template.cascadeTileImage && !map.cascadeTileImage) {
      map.cascadeTileImage = template.cascadeTileImage
    }
    if (template.restTileImage && !map.restTileImage) {
      map.restTileImage = template.restTileImage
    }

    if (!ms.currentTileId) {
      ms.currentTileId = map.columns[0][0].id
    }
    this.saveLoadout()
    return this.loadout.mapState
  }

  setCurrentMap(map) {
    if (!this.loadout.mapState) {
      this.loadout.mapState = { currentMapIndex: 0, currentTileId: null, maps: [] }
    }
    this.loadout.mapState.currentMapIndex = map.index
    this.loadout.mapState.maps[map.index] = map
    this.loadout.mapState.currentTileId = map.columns[0][0].id
    this.saveLoadout()
  }

  getCurrentMap() {
    if (!this.loadout.mapState) return null
    return this.loadout.mapState.maps[this.loadout.mapState.currentMapIndex] || null
  }

  getCurrentTileId() {
    return this.loadout.mapState?.currentTileId || null
  }

  completeTile(tileId) {
    const map = this.getCurrentMap()
    if (!map) return
    const tile = map.columns.flat().find(t => t.id === tileId)
    if (tile) tile.completed = true
    this.loadout.mapState.currentTileId = tileId
    this.saveLoadout()
  }

  advanceMap() {
    const ms = this.loadout.mapState
    if (!ms) return
    ms.currentMapIndex = (ms.currentMapIndex + 1) % 2
    ms.maps[ms.currentMapIndex] = generateMap(ms.currentMapIndex)
    ms.currentTileId = ms.maps[ms.currentMapIndex].columns[0][0].id
    this.saveLoadout()
  }

  restartMap() {
    const ms = this.loadout.mapState
    if (!ms) return
    ms.maps[ms.currentMapIndex] = generateMap(ms.currentMapIndex)
    ms.currentTileId = ms.maps[ms.currentMapIndex].columns[0][0].id
    this.saveLoadout()
  }

  resetToFreshHero() {
    const starterActionIds = ['forward_slash', 'setup_defence', 'shield_parry', 'use_item']
    const permanentStatPointBonus = this.loadout?.permanentStatPointBonus || 0
    const totalStatPoints = BASE_STAT_POINTS + (this.level - 1) * STAT_POINTS_PER_LEVEL + permanentStatPointBonus

    this.loadout = {
      class: 'warrior',
      activeItemIds: ['health_potion', 'stone'],
      heroCharmIds: ['chikara_charm', 'tate_charm', 'hayai_charm', 'un_charm'],
      weaponCharmIds: [],
      shieldCharmIds: [],
      selectedActionIds: [...starterActionIds],
      activeActionIds: ['forward_slash', 'setup_defence', 'shield_parry'],
      statPoints: totalStatPoints,
      statAllocations: { vitality: 0, stamina: 0, skill: 0, strength: 0, mana: 0, luck: 0 },
      permanentStatPointBonus,
      gold: 0,
      inventory: { health_potion: 2, stone: 1 },
      ownedCharmIds: [],
      mapState: null,
      mapVersion: MAP_VERSION,
    }

    this.activeActionIds = this.loadout.activeActionIds

    this.baseStats = { ...this.startingBaseStats }
    for (const stat of Object.keys(this.baseStats)) {
      this[stat] = this.baseStats[stat]
    }
    this.maxHp = 80 + this.baseStats.vitality * 5
    this.hp = this.maxHp
    this.maxStamina = 8 + Math.floor(this.baseStats.stamina / 3)
    this.stamina = this.maxStamina

    this.buffs = []
    this.activeKanjiBonus = 0
    this.activeShieldBonus = 0
    this.setupDefenceUsed = false
    this.readiness = 0
    this.reactionMultiplier = 1
    this.lastReactionCorrect = false
    this.itemEffectModifier = 0
    this.parrySetup = false
    this.parryKanjiQuality = null
    this._charmEffects = null

    this.clearKanjiBonus()
    this.clearShieldBonus()
    this.refreshActions()
    this.saveLoadout()
  }
}
