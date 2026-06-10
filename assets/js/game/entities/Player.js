import Character from './Character.js'
import { ITEMS } from '../data/items.js'
import { splitActions, getMaxActiveActions } from '../data/actions.js'

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
    this.level = userData.level || 1
    this.potionUsesLeft = 3
    this.userData = userData

    // Equipment
    this.shield = shield

    // Active / inactive action management
    this.activeActionIds = userData.active_action_ids || ['forward_slash', 'setup_defence', 'shield_parry']
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

  // Total defense = base + temp + shield base/scaling + shield kanji bonus + readiness bonus
  getTotalDefense() {
    const readinessBonus = this.readiness > 0 ? 5 : 0
    return this.baseDefense + this.tempDefense + this.calculateShieldDefense() + readinessBonus
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
}
