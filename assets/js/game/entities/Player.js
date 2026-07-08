import Character from './Character.js'
import { ITEMS } from '../data/items.js'
import { splitActions, getMaxActiveActions, getMaxBattlePoolActions, getMaxOverallAbilities, ALL_ACTIONS } from '../data/actions.js'
import { getCharmById, canEquipCharm, CHARM_TYPES, CHARMS } from '../data/charms.js'
import { gradeForSchedule, getSocketCharmById, ALL_SOCKET_CHARMS } from '../data/socketCharms.js'
import metaUnlocks from '../data/metaUnlocks.json'
import { generateMap } from '../systems/MapGenerator.js'
import { getMapDefinition } from '../data/maps/index.js'

const LOADOUT_KEY = 'medoru_loadout_v1'
const MAP_VERSION = 4

const BASE_STAT_POINTS = 0
const STAT_POINTS_PER_LEVEL = 0

// Scaling letter multipliers
export const SCALING_MULTIPLIERS = {
  S: 1.10,
  A: 0.90,
  B: 0.70,
  C: 0.50,
  D: 0.30,
  E: 0.15,
}

const GRADE_ORDER = ['S', 'A', 'B', 'C', 'D', 'E']

function createDefaultWeapon(permanentLevel = 0) {
  const level = Math.min(10, permanentLevel)
  return {
    name: 'Long Sword',
    nameJa: '長剣',
    baseDamage: 20 + level * 2,
    level,
    maxLevel: 10,
    scalingSchedule: {
      strength: { 0: 'C', 3: 'B', 9: 'A' },
      skill: { 0: 'D', 5: 'C' },
    },
    socketCharmIds: [null, null, null, null],
    kanjiPowerups: [
      { kanji: '力', name: 'chikara', learned: true, effect: 'flat_bonus', hint: { en: 'Make a POWERFUL swing.', ja: '強力な一振りを。' } },
    ],
    moveHints: {
      forward_slash: { en: 'Make a POWERFUL swing.', ja: '強力な一振りを。' },
    },
  }
}

function createDefaultShield(permanentLevel = 0) {
  const level = Math.min(10, permanentLevel)
  return {
    name: 'Wooden Shield',
    nameJa: '木盾',
    baseDefense: 5 + level * 1,
    level,
    maxLevel: 10,
    scalingSchedule: {
      strength: { 0: 'D', 5: 'C', 9: 'B' },
    },
    socketCharmIds: [null, null, null, null],
    kanjiPowerup: { kanji: '盾', name: 'tate', learned: true, effect: 'flat_defense', bonus: 3, hint: { en: 'Raise your GUARD.', ja: '盾を構えろ。' } },
    moveHint: { en: 'Raise your GUARD.', ja: '盾を構えろ。' },
    // Base pool for Setup Defence kanji challenge. Charms can extend this.
    kanjiPool: ['守', '防', '盾', '硬', '堅'],
  }
}

function getLockedIds(category, field = 'locked') {
  const list = metaUnlocks[category]?.[field] || []
  return new Set(list.map(entry => (typeof entry === 'string' ? entry : entry.id)).filter(Boolean))
}

function getDefaultUnlockedSocketCharmIds() {
  const locked = getLockedIds('socketCharms')
  const eventLocked = getLockedIds('socketCharms', 'eventLocked')
  // Fresh profiles start with no socket charms; all slot-1 weapon/shield charms unlock through victories/events.
  return ALL_SOCKET_CHARMS.filter(
    c => c.equipmentType === 'secondary_weapon' && !locked.has(c.id) && !eventLocked.has(c.id)
  ).map(c => c.id)
}

function getDefaultUnlockedHeroCharmIds() {
  const locked = getLockedIds('heroCharms')
  const eventLocked = getLockedIds('heroCharms', 'eventLocked')
  return CHARMS.filter(
    c => c.type === CHARM_TYPES.HERO && !locked.has(c.id) && !eventLocked.has(c.id) && !c.firstDefeatReward
  ).map(c => c.id)
}

function getDefaultUnlockedAbilityIds() {
  const locked = new Set([
    ...Array.from(getLockedIds('abilities')),
    ...Array.from(getLockedIds('abilities', 'eventLocked')),
  ])
  return ALL_ACTIONS.filter(a => a.id !== 'use_item' && !locked.has(a.id)).map(a => a.id)
}

export function getUpgradeCost(level) {
  if (level >= 9) return 500
  if (level >= 6) return 200
  if (level >= 3) return 100
  return 50
}

function getBaseScaling(equipment) {
  if (!equipment || !equipment.scalingSchedule) return {}
  const level = equipment.level || 0
  const scaling = {}
  for (const [stat, schedule] of Object.entries(equipment.scalingSchedule)) {
    scaling[stat] = gradeForSchedule(schedule, level)
  }
  return scaling
}

function applySocketScaling(baseScaling, equipment) {
  const sockets = equipment?.socketCharmIds || []
  for (let i = 0; i < sockets.length; i++) {
    const charmId = sockets[i]
    if (!charmId) continue
    const charm = getSocketCharmById(charmId)
    if (!charm || !charm.scaling) continue
    for (const [stat, rule] of Object.entries(charm.scaling)) {
      if (rule === null) {
        delete baseScaling[stat]
      } else if (typeof rule === 'string') {
        baseScaling[stat] = rule
      } else if (rule.fixed) {
        baseScaling[stat] = rule.fixed
      } else if (rule.milestones) {
        baseScaling[stat] = gradeForSchedule(rule.milestones, equipment.level || 0)
      }
    }
  }
  return baseScaling
}

export function getEffectiveScaling(equipment) {
  const base = getBaseScaling(equipment)
  return applySocketScaling(base, equipment)
}

// Soft-cap stat factor: returns 0.0–1.0 based on stat value
export function getStatFactor(stat) {
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
      capacity: 5,
      skill: 10,
      strength: 15,
      mana: 5,
      luck: 5,
    }

    const weapon = createDefaultWeapon()
    const shield = createDefaultShield()

    // Calculate max HP from vitality (charm multiplier applied after loadout)
    const baseMaxHp = 80 + baseStats.vitality * 5
    const maxStamina = 8 + Math.floor(baseStats.stamina / 3)

    super({
      name: userData.name || 'The Anomaly',
      nameJa: '異常存在',
      maxHp: baseMaxHp,
      maxStamina,
      defense: shirtDefense,
      strength: baseStats.strength,
      skill: baseStats.skill,
      mana: baseStats.mana,
      luck: baseStats.luck,
      capacity: baseStats.capacity,
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
    const starterActionIds = [
      'forward_slash', 'setup_defence', 'shield_parry', 'use_item',
    ]
    this.loadout = this.loadLoadout() || {
      class: 'warrior',
      // Meta-currency and permanent unlocks
      ouroScales: this.level,
      savedSiteLevel: this.level,
      ouroSource: 0,
      ouroEssence: 0,
      startingGoldBonus: 0,
      startingPotionBonus: 0,
      lifetimeNormalEnemiesDefeated: 0,
      lifetimeMiniBossesDefeated: 0,
      unlockedSocketCharmIds: getDefaultUnlockedSocketCharmIds(),
      unlockedHeroCharmIds: getDefaultUnlockedHeroCharmIds(),
      unlockedAbilityIds: getDefaultUnlockedAbilityIds(),
      permanentWeaponLevel: 0,
      permanentShieldLevel: 0,
      permanentStatPointBonus: 0,
      // Run-scoped state (reset every run)
      activeItemIds: [],
      heroCharmIds: [],
      weaponCharmIds: [],
      shieldCharmIds: [],
      knownActionIds: starterActionIds.filter(id => id !== 'use_item'),
      selectedActionIds: [...starterActionIds],
      activeActionIds: ['forward_slash', 'setup_defence', 'shield_parry', 'use_item'],
      singleUseCharges: {},
      statPoints: startingStatPoints,
      statAllocations: { vitality: 0, stamina: 0, capacity: 0, skill: 0, strength: 0, mana: 0, luck: 0 },
      gold: 0,
      inventory: {},
      ownedCharmIds: [],
      ownedSocketCharmIds: [],
      mapState: null,
      mapVersion: MAP_VERSION,
      focusKanji: null,
      focusKanjiData: null,
    }

    // Load persisted equipment or fall back to defaults.
    this.weapon = this.loadout.weapon || weapon
    this.shield = this.loadout.shield || shield
    this.loadout.weapon = this.weapon
    this.loadout.shield = this.shield

    // Apply stat allocations to base stats
    for (const [stat, points] of Object.entries(this.loadout.statAllocations)) {
      if (this.baseStats[stat] !== undefined) {
        this.baseStats[stat] += points
        this[stat] = this.baseStats[stat]
      }
    }

    // Recalculate derived stats after allocations
    this.recalcMaxHp()
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

    // Apply any max-HP charm multipliers now that loadout is available.
    this.recalcMaxHp()

    // Kanji list for item challenges
    this.kanjiList = userData.kanji_list || []
  }

  // ---------- Weapon Damage Calculation ----------

  calculateWeaponDamage(action = null) {
    const w = this.weapon
    if (!w) return 0

    const base = w.baseDamage
    let bonus = 0

    // Apply effective scaling (base + socket charm overrides)
    for (const [stat, grade] of Object.entries(getEffectiveScaling(w))) {
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
    return this.shield ? (this.shield.bonus || 0) : 0
  }

  // ---------- Shield Defence Calculation ----------

  calculateShieldDefense() {
    const s = this.shield
    if (!s) return 0

    const base = s.baseDefense
    let bonus = 0

    // Apply effective scaling (base + socket charm overrides)
    for (const [stat, grade] of Object.entries(getEffectiveScaling(s))) {
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

  // Total defense = base + shield base/scaling + shield kanji bonus + readiness bonus + charm bonus
  // NOTE: tempDefense is now a damage-absorption pool, not part of the damage-reduction formula.
  getTotalDefense() {
    const readinessBonus = this.readiness > 0 ? 5 : 0
    const charmEffects = this.getCharmEffects()
    const charmDefense = charmEffects.defense || 0
    return this.baseDefense + this.calculateShieldDefense() + readinessBonus + charmDefense
  }

  // Compute how much temporary defence Setup Defence should grant.
  // It scales with the shield's effective scaling schedule (charms can change this).
  computeSetupDefenceAmount(skill, multiplier = 1) {
    const shield = this.shield
    const baseBlock = skill?.baseBlock || 0
    if (!shield) return Math.floor(baseBlock * multiplier)

    const shieldBase = shield.baseDefense || 0
    let scaling = 0
    for (const [stat, grade] of Object.entries(getEffectiveScaling(shield))) {
      const multiplierGrade = SCALING_MULTIPLIERS[grade] || 0
      const statValue = this.getStatValue(stat)
      const factor = getStatFactor(statValue)
      scaling += shieldBase * multiplierGrade * factor
    }

    return Math.floor((baseBlock + scaling) * multiplier)
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
    // Keep the persistent loadout in sync so splitActions() and saves use the new set.
    if (this.loadout) {
      this.loadout.activeActionIds = ids
      this.saveLoadout()
    }
    this.refreshActions()
  }

  swapActions(activeId, inactiveId) {
    const newActive = this.activeActionIds.filter(id => id !== activeId)
    newActive.push(inactiveId)
    this.setActiveActionIds(newActive)
  }

  // ---------- Skill Availability ----------

  canUseSkill(skill) {
    if (this.stamina < skill.staminaCost) return false
    if (skill.singleUse) {
      return (this.loadout.singleUseCharges?.[skill.id] || 0) > 0
    }
    return true
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
        // Fresh profiles start with shield socket charms only; weapon charms are unlocked later.
        // Starter charms are filtered so anything that has been moved into the locked/eventLocked
        // lists is no longer given for free.
        const socketLocked = getLockedIds('socketCharms')
        const socketEventLocked = getLockedIds('socketCharms', 'eventLocked')
        const starterSocketCharmIds = [
          'sturdy_charm_shield',
          'thorn_shell_charm_shield',
          'steady_guard_charm_shield',
        ].filter(id => !socketLocked.has(id) && !socketEventLocked.has(id))
        if (!Array.isArray(loadout.ownedSocketCharmIds)) {
          loadout.ownedSocketCharmIds = starterSocketCharmIds
        } else {
          for (const id of starterSocketCharmIds) {
            if (!loadout.ownedSocketCharmIds.includes(id)) {
              loadout.ownedSocketCharmIds.push(id)
            }
          }
        }

        // One-time cleanup: old saves may have charms marked as unlocked/owned before they were
        // moved to the eventLocked lists. Remove them so the new lock state applies.
        const CHARM_LOCK_VERSION = 1
        if ((loadout.charmLockVersion || 0) < CHARM_LOCK_VERSION) {
          const heroEventLocked = getLockedIds('heroCharms', 'eventLocked')
          loadout.unlockedSocketCharmIds = (loadout.unlockedSocketCharmIds || [])
            .filter(id => !socketEventLocked.has(id))
          loadout.ownedSocketCharmIds = (loadout.ownedSocketCharmIds || [])
            .filter(id => !socketEventLocked.has(id))
          loadout.unlockedHeroCharmIds = (loadout.unlockedHeroCharmIds || [])
            .filter(id => !heroEventLocked.has(id))
          loadout.ownedCharmIds = (loadout.ownedCharmIds || [])
            .filter(id => !heroEventLocked.has(id))
          loadout.charmLockVersion = CHARM_LOCK_VERSION
        }
        if (!Array.isArray(loadout.knownActionIds)) {
          loadout.knownActionIds = (loadout.selectedActionIds || []).filter(id => id !== 'use_item')
        }
        // Migration: single-use ability charges.
        if (!loadout.singleUseCharges || typeof loadout.singleUseCharges !== 'object') {
          loadout.singleUseCharges = {}
        }
        // Migration: ensure Use Item is active by default (it has its own slot).
        if (!Array.isArray(loadout.activeActionIds)) {
          loadout.activeActionIds = ['forward_slash', 'setup_defence', 'shield_parry', 'use_item']
        } else if (!loadout.activeActionIds.includes('use_item')) {
          loadout.activeActionIds.push('use_item')
        }
        if (!loadout.mapState || typeof loadout.mapState !== 'object') {
          loadout.mapState = null
        }
        if (loadout.focusKanji === undefined) {
          loadout.focusKanji = null
        }
        if (loadout.focusKanjiData === undefined) {
          loadout.focusKanjiData = null
        }
        // Migration: persisted weapon/shield support.
        if (!loadout.weapon || typeof loadout.weapon !== 'object') {
          loadout.weapon = createDefaultWeapon()
        }
        if (!loadout.shield || typeof loadout.shield !== 'object') {
          loadout.shield = createDefaultShield()
        }
        // Migration: move old flat `scaling` field to `scalingSchedule`.
        if (loadout.weapon.scaling && !loadout.weapon.scalingSchedule) {
          loadout.weapon.scalingSchedule = {
            strength: { 0: 'C', 3: 'B', 9: 'A' },
            skill: { 0: 'D', 5: 'C' },
          }
          delete loadout.weapon.scaling
        }
        if (loadout.shield.scaling && !loadout.shield.scalingSchedule) {
          loadout.shield.scalingSchedule = {
            strength: { 0: 'D', 5: 'C', 9: 'B' },
          }
          delete loadout.shield.scaling
        }
        if (!Array.isArray(loadout.weapon.socketCharmIds)) {
          loadout.weapon.socketCharmIds = [null, null, null, null]
        }
        if (!Array.isArray(loadout.shield.socketCharmIds)) {
          loadout.shield.socketCharmIds = [null, null, null, null]
        }
        if (!loadout.statAllocations) {
          loadout.statAllocations = {}
        }
        if (loadout.statAllocations.capacity === undefined) {
          loadout.statAllocations.capacity = 0
        }
        // Migration: meta-currency and permanent unlocks.
        // Legacy `gameTokens` and `rareGameTokens` become `ouroScales` and `ouroSource`.
        if (typeof loadout.ouroScales !== 'number') {
          loadout.ouroScales = typeof loadout.gameTokens === 'number' ? loadout.gameTokens : this.level
        }
        if (typeof loadout.gameTokens === 'number') {
          delete loadout.gameTokens
        }
        if (typeof loadout.savedSiteLevel !== 'number') {
          loadout.savedSiteLevel = this.level
        }
        if (typeof loadout.ouroSource !== 'number') {
          loadout.ouroSource = typeof loadout.rareGameTokens === 'number' ? loadout.rareGameTokens : 0
        }
        if (typeof loadout.rareGameTokens === 'number') {
          delete loadout.rareGameTokens
        }
        if (typeof loadout.ouroEssence !== 'number') {
          loadout.ouroEssence = 0
        }
        if (typeof loadout.startingGoldBonus !== 'number') {
          loadout.startingGoldBonus = 0
        }
        if (typeof loadout.startingPotionBonus !== 'number') {
          loadout.startingPotionBonus = 0
        }
        if (typeof loadout.lifetimeNormalEnemiesDefeated !== 'number') {
          loadout.lifetimeNormalEnemiesDefeated = 0
        }
        if (typeof loadout.lifetimeMiniBossesDefeated !== 'number') {
          loadout.lifetimeMiniBossesDefeated = 0
        }
        if (!Array.isArray(loadout.unlockedSocketCharmIds)) {
          loadout.unlockedSocketCharmIds = getDefaultUnlockedSocketCharmIds()
        }
        if (!Array.isArray(loadout.unlockedHeroCharmIds)) {
          loadout.unlockedHeroCharmIds = getDefaultUnlockedHeroCharmIds()
        }
        if (!Array.isArray(loadout.ownedCharmIds)) {
          loadout.ownedCharmIds = []
        }
        if (!Array.isArray(loadout.unlockedAbilityIds)) {
          loadout.unlockedAbilityIds = getDefaultUnlockedAbilityIds()
        }
        if (typeof loadout.permanentWeaponLevel !== 'number') {
          loadout.permanentWeaponLevel = 0
        }
        if (typeof loadout.permanentShieldLevel !== 'number') {
          loadout.permanentShieldLevel = 0
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
      this.loadout.weapon = this.weapon
      this.loadout.shield = this.shield
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
    const level = this.weapon?.level || 0
    if (level >= 9) return 4
    if (level >= 6) return 3
    if (level >= 3) return 2
    if (level >= 1) return 1
    return 0
  }

  getShieldCharmSlots() {
    const level = this.shield?.level || 0
    if (level >= 9) return 4
    if (level >= 6) return 3
    if (level >= 3) return 2
    if (level >= 1) return 1
    return 0
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
    this.recalcMaxHp()
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
    this.recalcMaxHp()
    this.saveLoadout()
  }

  unequipAllCharms() {
    this.loadout.heroCharmIds = []
    this.loadout.weaponCharmIds = []
    this.loadout.shieldCharmIds = []
    this._charmEffects = null
    this.recalcMaxHp()
    this.saveLoadout()
  }

  getEquippedSocketCharms() {
    const charms = []
    for (const equipment of [this.weapon, this.shield]) {
      if (!equipment) continue
      for (const charmId of equipment.socketCharmIds || []) {
        if (!charmId) continue
        const charm = getSocketCharmById(charmId)
        if (charm) charms.push(charm)
      }
    }
    return charms
  }

  recalcMaxHp() {
    const base = 80 + this.baseStats.vitality * 5
    const multiplier = 1 + (this.getCharmEffects().maxHpMultiplier || 0)
    const newMax = Math.floor(base * multiplier)
    const oldMax = this.maxHp || newMax
    this.maxHp = newMax
    // Heal the same amount the max increased so current HP keeps its ratio.
    this.hp = Math.min(this.maxHp, Math.max(1, this.hp + (newMax - oldMax)))
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
    for (const charm of this.getEquippedSocketCharms()) {
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

  /**
   * Consume one use of an equipped item. Infinite items are not consumed.
   * If the inventory count drops to zero, the item is automatically removed
   * from the active item list.
   */
  useEquippedItem(itemId) {
    const item = ITEMS.find(i => i.id === itemId)
    if (item?.infinite) return { consumed: false, remaining: Infinity }
    if (!this.consumeItem(itemId, 1)) return { consumed: false, remaining: 0 }
    const remaining = this.loadout.inventory[itemId] || 0
    if (remaining <= 0) {
      this.loadout.activeItemIds = this.loadout.activeItemIds.filter(id => id !== itemId)
    }
    this.saveLoadout()
    return { consumed: true, remaining }
  }

  addCharm(charmId) {
    const charm = getCharmById(charmId)
    if (!charm) return false

    if (!this.loadout.ownedCharmIds) this.loadout.ownedCharmIds = []
    if (!this.loadout.ownedCharmIds.includes(charmId)) {
      this.loadout.ownedCharmIds.push(charmId)
    }

    let equipped = false
    if (charm.type === 'hero' && this.loadout.heroCharmIds.length < this.getHeroCharmSlots()) {
      this.loadout.heroCharmIds.push(charmId)
      equipped = true
    } else if (charm.type === 'weapon' && this.loadout.weaponCharmIds.length < this.getWeaponCharmSlots()) {
      this.loadout.weaponCharmIds.push(charmId)
      equipped = true
    } else if (charm.type === 'shield' && this.loadout.shieldCharmIds.length < this.getShieldCharmSlots()) {
      this.loadout.shieldCharmIds.push(charmId)
      equipped = true
    }

    if (equipped) {
      this._charmEffects = null
      this.recalcMaxHp()
    }
    this.saveLoadout()
    return { owned: true, equipped }
  }

  addSocketCharm(charmId) {
    const charm = getSocketCharmById(charmId)
    if (!charm) return false

    if (!this.loadout.ownedSocketCharmIds) this.loadout.ownedSocketCharmIds = []
    if (!this.loadout.ownedSocketCharmIds.includes(charmId)) {
      this.loadout.ownedSocketCharmIds.push(charmId)
    }
    this.saveLoadout()
    return true
  }

  // ---------- Equipment Upgrades ----------

  upgradeWeapon() {
    return this.upgradeEquipment(this.weapon, 'baseDamage')
  }

  upgradeShield() {
    return this.upgradeEquipment(this.shield, 'baseDefense')
  }

  upgradeEquipment(item, baseStatKey) {
    if (!item) return { ok: false, reason: 'No equipment.' }
    if (item.level >= item.maxLevel) return { ok: false, reason: 'Already at max level.' }

    const cost = getUpgradeCost(item.level)
    if ((this.loadout.gold || 0) < cost) {
      return { ok: false, reason: `Need ${cost} gold.` }
    }

    this.loadout.gold -= cost
    item.level += 1

    if (baseStatKey === 'baseDamage') {
      item.baseDamage += 2
    } else if (baseStatKey === 'baseDefense') {
      item.baseDefense += 1
    }

    // Base scaling is now derived from scalingSchedule at runtime, so no
    // per-grade mutation is needed here.

    this.saveLoadout()
    return { ok: true, cost, level: item.level, maxLevel: item.maxLevel }
  }

  equipSocketCharm(equipment, slotIndex, charmId) {
    if (!equipment) return { ok: false, reason: 'No equipment.' }
    const maxSlots = equipment === this.weapon ? this.getWeaponCharmSlots() : this.getShieldCharmSlots()
    if (slotIndex < 0 || slotIndex >= maxSlots) {
      return { ok: false, reason: 'Socket not unlocked yet.' }
    }
    if (charmId) {
      const charm = getSocketCharmById(charmId)
      if (!charm) return { ok: false, reason: 'Unknown charm.' }
      const type = equipment === this.weapon ? 'primary_weapon' : equipment === this.shield ? 'secondary_weapon' : null
      if (charm.equipmentType !== type) {
        return { ok: false, reason: 'Charm does not fit this equipment.' }
      }
    }
    if (!equipment.socketCharmIds) equipment.socketCharmIds = [null, null, null, null]
    equipment.socketCharmIds[slotIndex] = charmId || null
    this._charmEffects = null
    this.saveLoadout()
    return { ok: true }
  }

  unequipSocketCharm(equipment, slotIndex) {
    return this.equipSocketCharm(equipment, slotIndex, null)
  }

  getSocketCharmInSlot(equipment, slotIndex) {
    const id = equipment?.socketCharmIds?.[slotIndex]
    return id ? getSocketCharmById(id) : null
  }

  getEquipmentScaling(equipment) {
    return getEffectiveScaling(equipment)
  }

  hasSocketCharmEquipped(charmId) {
    const weaponIds = this.weapon?.socketCharmIds || []
    const shieldIds = this.shield?.socketCharmIds || []
    return [...weaponIds, ...shieldIds].filter(Boolean).includes(charmId)
  }

  getSocketCharmFamily(equipmentType) {
    const normalized = equipmentType === 'shield' || equipmentType === 'secondary_weapon'
      ? 'secondary_weapon'
      : 'primary_weapon'
    const equipment = normalized === 'secondary_weapon' ? this.shield : this.weapon
    const charmId = equipment?.socketCharmIds?.[0]
    return charmId ? getSocketCharmById(charmId)?.abilityFamily || null : null
  }

  getEquippedSocketCharmFamilies() {
    const families = []
    const weaponFamily = this.getSocketCharmFamily('weapon')
    if (weaponFamily) families.push(weaponFamily)
    const shieldFamily = this.getSocketCharmFamily('shield')
    if (shieldFamily) families.push(shieldFamily)
    return families
  }

  // ---------- Ability Learning ----------

  addToSelectedPool(actionId) {
    if (actionId === 'use_item') {
      if (!this.loadout.selectedActionIds.includes('use_item')) {
        this.loadout.selectedActionIds.push('use_item')
      }
      return
    }
    if (!this.loadout.selectedActionIds.includes(actionId)) {
      this.loadout.selectedActionIds.push(actionId)
    }
  }

  hasAbility(actionId) {
    if (actionId === 'use_item') return true
    return (this.loadout.knownActionIds || []).includes(actionId)
  }

  countCombatAbilities() {
    return (this.loadout.knownActionIds || []).length
  }

  addToBattlePool(actionId) {
    if (actionId === 'use_item') return { ok: true }
    if (!this.hasAbility(actionId)) return { ok: false, reason: 'Ability not known.' }
    if (this.loadout.selectedActionIds.includes(actionId)) return { ok: true }

    const maxBattle = getMaxBattlePoolActions(this.capacity || 3)
    const combatSelected = this.loadout.selectedActionIds.filter(id => id !== 'use_item')
    if (combatSelected.length >= maxBattle) {
      return { ok: false, reason: 'Battle pool is full.' }
    }

    this.loadout.selectedActionIds.push(actionId)
    this.refreshActions()
    this.saveLoadout()
    return { ok: true }
  }

  removeFromBattlePool(actionId) {
    if (actionId === 'use_item') return { ok: false, reason: 'Cannot remove Use Item.' }
    const selIdx = this.loadout.selectedActionIds.indexOf(actionId)
    if (selIdx >= 0) this.loadout.selectedActionIds.splice(selIdx, 1)
    const activeIdx = this.loadout.activeActionIds.indexOf(actionId)
    if (activeIdx >= 0) this.loadout.activeActionIds.splice(activeIdx, 1)
    this.refreshActions()
    this.saveLoadout()
    return { ok: true }
  }

  learnAbility(actionId) {
    if (actionId === 'use_item') return { ok: true, added: false }
    if (!this.loadout.knownActionIds) this.loadout.knownActionIds = []
    if (this.loadout.knownActionIds.includes(actionId)) return { ok: true, added: false }

    const maxOverall = getMaxOverallAbilities(this.capacity || 3)
    if (this.loadout.knownActionIds.length >= maxOverall) {
      return { ok: false, reason: 'Overall ability cap reached.' }
    }

    this.loadout.knownActionIds.push(actionId)

    // Auto-add to battle pool if there is room
    const maxBattle = getMaxBattlePoolActions(this.capacity || 3)
    const combatSelected = this.loadout.selectedActionIds.filter(id => id !== 'use_item')
    if (combatSelected.length < maxBattle) {
      this.addToSelectedPool(actionId)
    }

    this.refreshActions()
    this.saveLoadout()
    return { ok: true, added: true }
  }

  replaceAbility(oldActionId, newActionId) {
    const knownIdx = this.loadout.knownActionIds.indexOf(oldActionId)
    if (knownIdx >= 0) {
      this.loadout.knownActionIds[knownIdx] = newActionId
    } else if (!this.loadout.knownActionIds.includes(newActionId)) {
      this.loadout.knownActionIds.push(newActionId)
    }

    const selIdx = this.loadout.selectedActionIds.indexOf(oldActionId)
    if (selIdx >= 0) {
      this.loadout.selectedActionIds[selIdx] = newActionId
    }

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
    // Backfill any new tile image fields added after the map was first
    // generated, so older saves pick them up without a full reset.
    const map = ms.maps[ms.currentMapIndex]
    const definition = getMapDefinition(map.index)
    const tileImages = definition.tileImages || {}
    const typeToField = {
      battle: 'battleTileImage',
      mini_boss: 'miniBossTileImage',
      boss: 'bossTileImage',
      chest: 'chestTileImage',
      shop: 'shopTileImage',
      memory: 'memoryTileImage',
      short_cascade: 'cascadeTileImage',
      rest_camp: 'restTileImage',
    }
    for (const [type, field] of Object.entries(typeToField)) {
      const image = tileImages[type]?.image
      if (image && !map[field]) {
        map[field] = image
      }
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

    // Keep the cursor on the completed tile. The outgoing connections of the
    // current (finished) tile are the valid choices, so the map must stay here
    // until the player picks the next branch. This also makes the call
    // idempotent when multiple scenes call it for the same tile.
    if (this.loadout.mapState.currentTileId === tileId) {
      this.loadout.mapState.currentTileId = tileId
    }
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
    const starterActionIds = [
      'forward_slash', 'setup_defence', 'shield_parry', 'use_item',
    ]

    // Preserve meta-progression.
    const meta = {
      ouroScales: this.loadout?.ouroScales ?? this.loadout?.gameTokens ?? this.level,
      savedSiteLevel: this.loadout?.savedSiteLevel ?? this.level,
      ouroSource: this.loadout?.ouroSource ?? this.loadout?.rareGameTokens ?? 0,
      ouroEssence: this.loadout?.ouroEssence ?? 0,
      startingGoldBonus: this.loadout?.startingGoldBonus ?? 0,
      startingPotionBonus: Math.min(4, this.loadout?.startingPotionBonus ?? 0),
      lifetimeNormalEnemiesDefeated: this.loadout?.lifetimeNormalEnemiesDefeated ?? 0,
      lifetimeMiniBossesDefeated: this.loadout?.lifetimeMiniBossesDefeated ?? 0,
      unlockedSocketCharmIds: this.loadout?.unlockedSocketCharmIds ?? getDefaultUnlockedSocketCharmIds(),
      unlockedHeroCharmIds: this.loadout?.unlockedHeroCharmIds ?? getDefaultUnlockedHeroCharmIds(),
      unlockedAbilityIds: this.loadout?.unlockedAbilityIds ?? getDefaultUnlockedAbilityIds(),
      permanentWeaponLevel: this.loadout?.permanentWeaponLevel ?? 0,
      permanentShieldLevel: this.loadout?.permanentShieldLevel ?? 0,
      permanentStatPointBonus: this.loadout?.permanentStatPointBonus ?? 0,
    }

    const previousLevel = meta.savedSiteLevel || this.level
    const levelDiff = Math.max(0, this.level - previousLevel)
    if (levelDiff > 0) {
      meta.ouroScales += levelDiff
      meta.savedSiteLevel = this.level
    }

    const totalStatPoints = BASE_STAT_POINTS + (this.level - 1) * STAT_POINTS_PER_LEVEL + meta.permanentStatPointBonus

    this.loadout = {
      class: 'warrior',
      ...meta,
      // Run-scoped state is reset below.
      activeItemIds: [],
      heroCharmIds: [],
      weaponCharmIds: [],
      shieldCharmIds: [],
      knownActionIds: starterActionIds.filter(id => id !== 'use_item'),
      selectedActionIds: [...starterActionIds],
      activeActionIds: ['forward_slash', 'setup_defence', 'shield_parry', 'use_item'],
      statPoints: totalStatPoints,
      statAllocations: { vitality: 0, stamina: 0, capacity: 0, skill: 0, strength: 0, mana: 0, luck: 0 },
      gold: meta.startingGoldBonus || 0,
      inventory: {},
      ownedCharmIds: [],
      ownedSocketCharmIds: [],
      mapState: null,
      mapVersion: MAP_VERSION,
      weapon: createDefaultWeapon(meta.permanentWeaponLevel),
      shield: createDefaultShield(meta.permanentShieldLevel),
    }

    this.weapon = this.loadout.weapon
    this.shield = this.loadout.shield

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
    this.readiness = 0
    this.reactionMultiplier = 1
    this.lastReactionCorrect = false
    this.itemEffectModifier = 0
    this.parrySetup = false
    this.parryKanjiQuality = null
    this.potionUsesLeft = 3 + (meta.startingPotionBonus || 0)
    this._charmEffects = null
    this.clearAllAbilityInfusions()

    this.clearKanjiBonus()
    this.clearShieldBonus()
    this.refreshActions()
    this.saveLoadout()
  }

  hardReset() {
    this.loadout = {
      ...this.loadout,
      ouroScales: this.level,
      savedSiteLevel: this.level,
      ouroSource: 0,
      ouroEssence: 0,
      startingGoldBonus: 0,
      startingPotionBonus: 0,
      lifetimeNormalEnemiesDefeated: 0,
      lifetimeMiniBossesDefeated: 0,
      unlockedSocketCharmIds: getDefaultUnlockedSocketCharmIds(),
      unlockedHeroCharmIds: getDefaultUnlockedHeroCharmIds(),
      unlockedAbilityIds: getDefaultUnlockedAbilityIds(),
      permanentWeaponLevel: 0,
      permanentShieldLevel: 0,
      permanentStatPointBonus: 0,
    }
    this.resetToFreshHero()
  }

  endRun(victory = true) {
    if (victory) {
      this.loadout.ouroScales = (this.loadout.ouroScales || 0) + 1
      if (Math.random() < 0.05) {
        this.loadout.ouroSource = (this.loadout.ouroSource || 0) + 1
      }
      this.unlockNextLockedItems()
    }
    this.resetToFreshHero()
  }

  addOuroScales(amount) {
    this.loadout.ouroScales = (this.loadout.ouroScales || 0) + amount
    this.saveLoadout()
  }

  spendOuroScales(amount) {
    if ((this.loadout.ouroScales || 0) < amount) return false
    this.loadout.ouroScales -= amount
    this.saveLoadout()
    return true
  }

  addOuroSource(amount) {
    this.loadout.ouroSource = (this.loadout.ouroSource || 0) + amount
    this.saveLoadout()
  }

  spendOuroSource(amount) {
    if ((this.loadout.ouroSource || 0) < amount) return false
    this.loadout.ouroSource -= amount
    this.saveLoadout()
    return true
  }

  addOuroEssence(amount) {
    this.loadout.ouroEssence = (this.loadout.ouroEssence || 0) + amount
    this.saveLoadout()
  }

  spendOuroEssence(amount) {
    if ((this.loadout.ouroEssence || 0) < amount) return false
    this.loadout.ouroEssence -= amount
    this.saveLoadout()
    return true
  }

  // ---------- Single-Use Ability Charges ----------

  getAbilityCharges(actionId) {
    const action = ALL_ACTIONS.find(a => a.id === actionId)
    if (!action || !action.singleUse) return Infinity
    return this.loadout.singleUseCharges?.[actionId] || 0
  }

  addAbilityCharges(actionId, charges = 1) {
    const action = ALL_ACTIONS.find(a => a.id === actionId)
    if (!action) return

    if (!action.singleUse) {
      // Multi-use ability: just make sure it's known.
      if (!this.loadout.knownActionIds.includes(actionId)) {
        this.loadout.knownActionIds.push(actionId)
      }
      this.saveLoadout()
      this.refreshActions()
      return
    }

    // Single-use ability.
    if (!this.loadout.singleUseCharges) this.loadout.singleUseCharges = {}
    this.loadout.singleUseCharges[actionId] = (this.loadout.singleUseCharges[actionId] || 0) + charges

    if (!this.loadout.knownActionIds.includes(actionId)) {
      this.loadout.knownActionIds.push(actionId)
    }

    // Auto-equip if there is a free active slot.
    const maxActive = getMaxActiveActions(this.capacity || 3)
    const combatActive = this.loadout.activeActionIds.filter(id => id !== 'use_item')
    if (combatActive.length < maxActive && !this.loadout.activeActionIds.includes(actionId)) {
      this.loadout.activeActionIds.push(actionId)
    }

    // Keep the battle pool consistent so the loadout UI shows it correctly.
    this.addToSelectedPool(actionId)

    this.saveLoadout()
    this.refreshActions()
  }

  consumeAbilityCharge(actionId) {
    const action = ALL_ACTIONS.find(a => a.id === actionId)
    if (!action || !action.singleUse) return true

    const charges = (this.loadout.singleUseCharges?.[actionId] || 0) - 1
    if (charges > 0) {
      this.loadout.singleUseCharges[actionId] = charges
    } else {
      delete this.loadout.singleUseCharges[actionId]
      this.loadout.knownActionIds = this.loadout.knownActionIds.filter(id => id !== actionId)
      this.loadout.activeActionIds = this.loadout.activeActionIds.filter(id => id !== actionId)
      this.loadout.selectedActionIds = this.loadout.selectedActionIds.filter(id => id !== actionId)
    }
    this.saveLoadout()
    this.refreshActions()
    return charges >= 0
  }

  recordNormalEnemyDefeated() {
    this.loadout.lifetimeNormalEnemiesDefeated = (this.loadout.lifetimeNormalEnemiesDefeated || 0) + 1
    let gained = 0
    if (this.loadout.lifetimeNormalEnemiesDefeated % 7 === 0) {
      gained = 1
      this.addOuroEssence(gained)
    }
    return gained
  }

  recordMiniBossDefeated() {
    this.loadout.lifetimeMiniBossesDefeated = (this.loadout.lifetimeMiniBossesDefeated || 0) + 1
    let gained = 0
    if (this.loadout.lifetimeMiniBossesDefeated % 5 === 0) {
      gained = 3
      this.addOuroEssence(gained)
    }
    return gained
  }

  recordMapBossDefeated(level) {
    let gained = 0
    if (level === 1) {
      gained = 2
      this.addOuroEssence(gained)
    }
    return gained
  }

  unlockNextLockedItems() {
    this.unlockNextInCategory('socketCharms', 'unlockedSocketCharmIds', ALL_SOCKET_CHARMS)
    this.unlockNextInCategory('heroCharms', 'unlockedHeroCharmIds', CHARMS.filter(c => c.type === CHARM_TYPES.HERO))
    this.unlockNextInCategory('abilities', 'unlockedAbilityIds', ALL_ACTIONS.filter(a => a.id !== 'use_item'))
  }

  unlockNextInCategory(category, loadoutKey, fullPool) {
    const lockedList = metaUnlocks[category]?.locked || []
    const unlocked = new Set(this.loadout[loadoutKey] || [])
    const fullIds = new Set(fullPool.map(item => item.id))

    for (const entry of lockedList) {
      const id = typeof entry === 'string' ? entry : entry.id
      if (!id || unlocked.has(id)) continue
      if (!fullIds.has(id)) continue
      unlocked.add(id)
      this.loadout[loadoutKey] = Array.from(unlocked)
      break
    }
  }
}
