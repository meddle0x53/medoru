// Headless verification harness for Phase 1 of the roguelike upgrade rework.
import './phaser-stub.js'

import { default as Player } from '../entities/Player.js'
import { apply, countUpgrade } from '../systems/UpgradeEngine.js'
import { default as TurnManager } from '../systems/TurnManager.js'
import { ALL_ACTIONS, getMaxActiveActions } from '../data/actions.js'

let passed = 0
let failed = 0
function check(name, cond, detail = '') {
  if (cond) { passed++; console.log(`  PASS ${name}`) }
  else { failed++; console.log(`  FAIL ${name} ${detail}`) }
}
function freshPlayer() {
  return new Player({ name: 'Harness', level: 10 })
}

console.log('stat & flat cards')
{
  const p = freshPlayer()
  const baseStr = p.baseStats.strength
  const baseStam = p.maxStamina
  const baseSlots = p.maxActiveSlots
  check('capacity baseline 3', baseSlots === getMaxActiveActions(p.getEffectiveCapacity()), `got ${baseSlots}`)
  for (let i = 0; i < 3; i++) check(`might apply #${i + 1}`, apply(p, 'might').ok)
  check('strength +3', p.baseStats.strength === baseStr + 3, `got ${p.baseStats.strength}`)
  check('might maxStacks enforced', countUpgrade(p, 'might') === 3)
  check('stamina_1 applies', apply(p, 'stamina_1').ok)
  check('stamina_2 chain applies', apply(p, 'stamina_2').ok)
  check('maxStamina exactly +2', p.maxStamina === baseStam + 2, `got ${p.maxStamina} want ${baseStam + 2}`)
  check('stamina_3 chain applies', apply(p, 'stamina_3').ok)
  check('stamina chain prerequisite enforced', (() => { const p2 = freshPlayer(); return !apply(p2, 'stamina_3').ok })())
  check('capacity_1 applies', apply(p, 'capacity_1').ok)
  check('active slots +1', p.maxActiveSlots === baseSlots + 1, `got ${p.maxActiveSlots}`)
  check('capacity_2 chain applies', apply(p, 'capacity_2').ok)
}

console.log('weapon profile conversion')
{
  const p = freshPlayer()
  check('sharp_weapon apply', apply(p, 'sharp_weapon').ok)
  const scaling = p.getEffectiveScaling()
  check('sharp override strength fixed D', scaling.strength === 'D', JSON.stringify(scaling))
  check('sharp override skill milestones (lv0 => C)', scaling.skill === 'C', JSON.stringify(scaling))
  const heavy = apply(p, 'heavy_weapon')
  check('heavy excluded after sharp', !heavy.ok, heavy.reason)
  check('fire excluded after sharp', !apply(p, 'fire_weapon').ok)
  check('override charm id stored', p.loadout.weaponProfileOverride === 'sharp_charm_sword')
}

console.log('ability modifiers')
{
  const p = freshPlayer()
  const slash = ALL_ACTIONS.find(a => a.id === 'forward_slash')
  for (let i = 0; i < 3; i++) check(`sharpened_slash apply #${i + 1}`, apply(p, 'sharpened_slash').ok)
  const eff = p.getEffectiveAbility(slash)
  check('damageMultiplier ~1.3', Math.abs(eff.damageMultiplier - 1.3) < 1e-9, `got ${eff.damageMultiplier}`)
  check('stack cap at 3', !apply(p, 'sharpened_slash').ok)

  check('deep_cut apply', apply(p, 'deep_cut').ok)
  const stab = ALL_ACTIONS.find(a => a.id === 'quick_stab')
  const effStab = p.getEffectiveAbility(stab)
  check('deep_cut bleed 2 onHit', effStab.onHitEffects.some(e => e.effectId === 'bleed' && e.duration === 2), JSON.stringify(effStab.onHitEffects))
  check('staminaCost min 1', effStab.staminaCost >= 1)
}

console.log('quick_stab unlock gate')
{
  const p = freshPlayer()
  const stab = ALL_ACTIONS.find(a => a.id === 'quick_stab')
  check('gated before unlock', p.skillUnavailableReason(stab) !== null)
  check('unlock card apply', apply(p, 'quick_stab_unlock').ok)
  check('unlocked after card', p.skillUnavailableReason(stab) === null, p.skillUnavailableReason(stab))
  check('ability learned', p.hasAbility('quick_stab'))
  check('no free slot -> not force-equipped', !p.loadout.activeActionIds.includes('quick_stab'))
  const pFree = freshPlayer()
  pFree.loadout.activeActionIds = ['forward_slash', 'use_item']
  pFree.refreshActions()
  apply(pFree, 'quick_stab_unlock')
  check('auto-equipped into free slot', pFree.loadout.activeActionIds.includes('quick_stab'))
  const p2 = freshPlayer()
  p2.weapon.socketCharmIds[0] = 'sharp_charm_sword'
  check('socket charm still opens gate', p2.skillUnavailableReason(stab) === null)
  const gb = ALL_ACTIONS.find(a => a.id === 'guard_break')
  if (gb) check('guard_break still gated', p.skillUnavailableReason(gb) !== null)
  const p3 = freshPlayer()
  check('guard_break_unlock opens gate', apply(p3, 'guard_break_unlock').ok && p3.skillUnavailableReason(gb) === null)
}

console.log('rolls')
{
  const p = freshPlayer()
  p.loadout.ouroScales = 100
  p.loadout.gold = 1000
  const s0 = p.loadout.ouroScales
  check('buy rare w/ scales', p.buyRoll('rare', 'scales').ok)
  check('scales deducted 18', p.loadout.ouroScales === s0 - 18, `${p.loadout.ouroScales}`)
  check('inventory rare 1', p.loadout.rollInventory.rare === 1)
  check('buy common w/ gold', p.buyRoll('common', 'gold').ok)
  check('gold deducted 50', p.loadout.gold === 950)
  p.loadout.ouroScales = 3
  check('insufficient funds', !p.buyRoll('epic', 'scales').ok)
  p.loadout.ouroScales = 82

  check('no activeRoll state', p.loadout.activeRoll === undefined)
  check('useRoll decrements inventory', p.useRoll('rare').ok && p.loadout.rollInventory.rare === 0)
  check('useRoll refuses empty inventory', !p.useRoll('rare').ok)
  check('useRoll validates tier', !p.useRoll('legendary').ok)

  p.resetToFreshHero()
  check('reset keeps rollInventory', p.loadout.rollInventory.rare === 0 && p.loadout.rollInventory.common === 1, JSON.stringify(p.loadout.rollInventory))
  check('reset leaves no activeRoll', p.loadout.activeRoll === undefined)
  check('reset wipes runUpgrades', Array.isArray(p.loadout.runUpgrades) && p.loadout.runUpgrades.length === 0)
  check('reset wipes kanjiTiers', JSON.stringify(p.loadout.kanjiTiers) === '{}')
  check('reset wipes staminaFlatBonus/activeSlotBonus/override',
    p.loadout.staminaFlatBonus === 0 && p.loadout.activeSlotBonus === 0 && p.loadout.weaponProfileOverride === null && p.loadout.shieldProfileOverride === null)
  check('statPoints/statAllocations wiped', p.loadout.statPoints === undefined && p.loadout.statAllocations === undefined)
  check('baseStats restored', p.baseStats.strength === p.startingBaseStats.strength)
}

console.log('kanji tiers')
{
  const p = freshPlayer()
  const slash = ALL_ACTIONS.find(a => a.id === 'forward_slash')
  check('default tier green', p.getKanjiTier('forward_slash', slash.kanjiPool[0]) === 'green')
  const r1 = apply(p, 'kanji_attunement_slash')
  check('tier card applies', r1.ok)
  const tiers = p.loadout.kanjiTiers['forward_slash'] || {}
  const raised = Object.entries(tiers)
  check('exactly one char raised', raised.length === 1, JSON.stringify(tiers))
  check('raised to blue', raised.length === 1 && raised[0][1] === 'blue')
  check('getKanjiTier reflects', raised.length === 1 && p.getKanjiTier('forward_slash', raised[0][0]) === 'blue')
  let guard = 0
  while (apply(p, 'kanji_attunement_slash').ok && guard < 30) guard++
  const allTiers = Object.values(p.loadout.kanjiTiers['forward_slash'] || {})
  check('all pool chars silver at cap', allTiers.length === slash.kanjiPool.length && allTiers.every(t => t === 'silver'),
    JSON.stringify(p.loadout.kanjiTiers['forward_slash']))
  check('apply fails at silver cap', !apply(p, 'kanji_attunement_slash').ok)
  p.resetToFreshHero()
  check('reset clears kanjiTiers', JSON.stringify(p.loadout.kanjiTiers) === '{}')
}

console.log('charges deleted')
{
  const p = freshPlayer()
  check('no singleUseCharges key', p.loadout.singleUseCharges === undefined)
  p.learnAbility('quick_stab')
  check('learnAbility grants ability', p.hasAbility('quick_stab'))
  check('still no charges map', p.loadout.singleUseCharges === undefined)
  check('learnAbility is idempotent', p.learnAbility('quick_stab').added === false)
}

console.log('turn manager attack branch')
{
  const p = freshPlayer()
  apply(p, 'sharpened_slash')
  apply(p, 'sharpened_slash')
  apply(p, 'sharpened_slash')
  const slash = ALL_ACTIONS.find(a => a.id === 'forward_slash')

  const target = {
    name: 'Dummy', hp: 500, maxHp: 500,
    getDefense: () => 0,
    getActiveEffectIds: () => [],
    removeEffects: () => {},
    getIncomingDamageMultiplier: () => 1,
    getMissChanceFor: () => 0,
    takeDamage(d) { this.hp -= d; return d },
    isAlive() { return this.hp > 0 },
    incrementElementStreak: () => 1,
    resetElementStreak: () => {},
  }
  const tm = new TurnManager(p, [target], {})
  p.activeKanjiTierMult = 1.15
  p.stamina = p.maxStamina
  const eff = p.getEffectiveAbility(slash)
  const stamBefore = p.stamina
  const result = tm.useSkill(slash, p, target, 'success')
  check('attack resolves', result && result.type === 'attack', JSON.stringify(result))
  check('effective stamina spent', p.stamina === stamBefore - eff.staminaCost, `${p.stamina} vs ${stamBefore - eff.staminaCost}`)
  check('tier mult consumed (cleared)', p.activeKanjiTierMult === 1)

  const expected = Math.floor(p.calculateWeaponDamage(slash) * 1 * 1.3 * 1.15)
  const dealt = 500 - target.hp
  check('damage composition exact', dealt === expected || result.isCrit, `dealt ${dealt} expected ${expected} crit=${result.isCrit}`)

  const p2 = freshPlayer()
  apply(p2, 'quick_stab_unlock')
  apply(p2, 'deep_cut')
  const stab = ALL_ACTIONS.find(a => a.id === 'quick_stab')
  p2.stamina = p2.maxStamina
  const t2 = { ...target, hp: 500, maxHp: 500, activeEffects: [],
    applyEffect(id, opts) { this.activeEffects.push({ id, ...opts }); },
    getEffectEntry: () => null,
  }
  const tm2 = new TurnManager(p2, [t2], {})
  const r2 = tm2.useSkill(stab, p2, t2, 'success')
  check('quick_stab resolves post-unlock', r2 && r2.type === 'attack', JSON.stringify(r2))
  check('bleed applied via onHitEffects', t2.activeEffects.some(e => e.id === 'bleed'), JSON.stringify(t2.activeEffects))

  const p3 = freshPlayer()
  p3.loadout.runUpgrades.push({ upgradeId: 'x', type: 'ability_modifier', effect: { abilityId: 'forward_slash', executeBonus: 1, doubleHit: true } })
  p3.stamina = p3.maxStamina
  const t3 = { ...target, hp: 100, maxHp: 1000, activeEffects: [], applyEffect() {}, getEffectEntry: () => null }
  const tm3 = new TurnManager(p3, [t3], {})
  const r3 = tm3.useSkill(slash, p3, t3, 'success')
  check('execute+doubleHit resolves', r3 && typeof r3.doubleHitDamage === 'number', JSON.stringify(r3))
}

console.log(`\n${passed} passed, ${failed} failed`)
process.exit(failed > 0 ? 1 : 0)
