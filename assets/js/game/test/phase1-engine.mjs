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
  check('strength +15 (3x +5 front-loaded)', p.baseStats.strength === baseStr + 15, `got ${p.baseStats.strength}`)
  check('might maxStacks enforced', countUpgrade(p, 'might') === 3)
  check('4th might gives +4 (taper)', (() => {
    const px = freshPlayer()
    for (let i = 0; i < 3; i++) apply(px, 'might')
    const s3 = px.baseStats.strength
    apply(px, 'might')
    return px.baseStats.strength === s3 + 4
  })())
  check('8th might gives +3 (final taper)', (() => {
    const px = freshPlayer()
    for (let i = 0; i < 7; i++) apply(px, 'might')
    const s7 = px.baseStats.strength
    apply(px, 'might')
    return px.baseStats.strength === s7 + 3
  })())
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

  // flat_active_slot: the extra slot must survive into splitActions' trim,
  // not just the maxActiveSlots field (bug: bar stayed at base 3).
  const pSlots = freshPlayer()
  apply(pSlots, 'capacity_1')
  pSlots.loadout.selectedActionIds = ['forward_slash', 'setup_defence', 'shield_parry', 'focus', 'use_item']
  pSlots.loadout.activeActionIds = ['forward_slash', 'setup_defence', 'shield_parry', 'focus']
  pSlots.refreshActions()
  check('activeSlotBonus yields a 4th combat active', pSlots.activeActions.length === 4, `${pSlots.activeActions.length}`)
  const pSlotsBase = freshPlayer()
  pSlotsBase.loadout.selectedActionIds = ['forward_slash', 'setup_defence', 'shield_parry', 'focus', 'use_item']
  pSlotsBase.loadout.activeActionIds = ['forward_slash', 'setup_defence', 'shield_parry', 'focus']
  pSlotsBase.refreshActions()
  check('without bonus still trims to 3', pSlotsBase.activeActions.length === 3, `${pSlotsBase.activeActions.length}`)

  // Constructor path: a saved run with activeSlotBonus must reload with the
  // extra slot available (bug: maxActiveSlots was set without the bonus, so
  // fresh loads after a refresh showed the base 3 again).
  const memStore = new Map()
  const prevStorage = globalThis.localStorage
  globalThis.localStorage = {
    getItem: k => (memStore.has(k) ? memStore.get(k) : null),
    setItem: (k, v) => memStore.set(k, String(v)),
    removeItem: k => memStore.delete(k),
  }
  const pSaved = freshPlayer()
  apply(pSaved, 'capacity_1')
  pSaved.saveLoadout()
  const pReloaded = new Player({ name: 'Reload', level: 10 })
  check('reloaded player keeps bonus slot count', pReloaded.maxActiveSlots === 4, `${pReloaded.maxActiveSlots}`)
  check('reloaded player keeps activeSlotBonus', pReloaded.loadout.activeSlotBonus === 1)
  globalThis.localStorage = prevStorage
}

console.log('forgetAbility')
{
  const p = freshPlayer()
  apply(p, 'quick_stab_unlock')
  apply(p, 'deep_cut')
  apply(p, 'fleet_stab')
  const before = p.loadout.runUpgrades.length
  check('setup knows quick stab with upgrades', p.hasAbility('quick_stab') && p.loadout.runUpgrades.length === before)

  const res = p.forgetAbility('quick_stab')
  check('forget succeeds', res.ok, res.reason || '')
  check('upgrades purged (unlock + 2 modifiers)', res.removedUpgrades === 3, `${res.removedUpgrades}`)
  check('no longer known', !p.hasAbility('quick_stab'))
  check('removed from selected/active', !p.loadout.selectedActionIds.includes('quick_stab') && !p.loadout.activeActionIds.includes('quick_stab'))
  check('run-upgrades no longer reference it', (p.loadout.runUpgrades || []).every(u => u.effect?.abilityId !== 'quick_stab'))

  const again = p.forgetAbility('quick_stab')
  check('forgetting unknown ability fails', !again.ok)

  const item = p.forgetAbility('use_item')
  check('use_item cannot be forgotten', !item.ok)

  // Attack floor: the two starter attacks are forward_slash + ... only one
  // attack among starters, so forgetting the last attack must fail.
  const p2 = freshPlayer()
  // Give p2 a second attack first, then remove it, then try the last one.
  p2.learnAbility('heavy_slash')
  const res2 = p2.forgetAbility('forward_slash')
  check('forgetting attack with another attack available works', res2.ok, res2.reason || '')
  const res3 = p2.forgetAbility('heavy_slash')
  check('forgetting the last attack fails', !res3.ok, res3.reason || '')
  check('still knows heavy_slash', p2.hasAbility('heavy_slash'))

  // kanjiTiers entry purged
  const p3 = freshPlayer()
  apply(p3, 'quick_stab_unlock')
  apply(p3, 'kanji_attunement_stab')
  check('tier recorded before forget', Object.keys(p3.loadout.kanjiTiers?.quick_stab || {}).length >= 0 && !!p3.loadout.kanjiTiers.quick_stab)
  p3.forgetAbility('quick_stab')
  check('kanjiTiers entry cleared', !p3.loadout.kanjiTiers?.quick_stab)
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

  // Perfect-draw accuracy: flawless kanji reduces/negates miss chance by size.
  const tm4 = new TurnManager(p3, [t3], {})
  const p4 = freshPlayer()
  p4.stamina = p4.maxStamina
  p4.lastKanjiWrongStrokes = 0
  const tiers = [[3, 0.25], [6, 0.5], [11, 0.75], [14, 1]]
  for (const [strokes, expected] of tiers) {
    p4.lastKanjiStrokes = strokes
    check(`perfect ${strokes} strokes -> reduction ${expected}`, tm4.perfectDrawMissReduction(p4, 'perfect') === expected)
  }
  p4.lastKanjiStrokes = 6
  check('no reduction on success result', tm4.perfectDrawMissReduction(p4, 'success') === 0)
  p4.lastKanjiWrongStrokes = 1
  check('no reduction with wrong strokes', tm4.perfectDrawMissReduction(p4, 'perfect') === 0)
  p4.lastKanjiWrongStrokes = 0
  p4.lastKanjiStrokes = 0
  check('no reduction without stroke data', tm4.perfectDrawMissReduction(p4, 'perfect') === 0)

  // 13+ perfect vs a 95%-evasion enemy: miss chance clamps to 0, never misses.
  const dodgeTarget = {
    name: 'Dodger', hp: 5000, maxHp: 5000, buffs: [], activeEffects: [],
    getMissChanceFor: () => 0.95,
    takeDamage(d) { this.hp -= d; return d },
    getIncomingDamageMultiplier: () => 1,
    getDefense: () => 0,
    getPhysicalDefense: () => 0,
    getElementalDefense: () => 0,
    getActiveEffectIds: () => [],
    isAlive() { return this.hp > 0 },
    incrementElementStreak: () => 1,
    resetElementStreak: () => {},
    applyEffect() {}, getEffectEntry: () => null,
  }
  p4.lastKanjiStrokes = 14
  p4.lastKanjiWrongStrokes = 0
  let misses = 0
  for (let i = 0; i < 40; i++) {
    p4.stamina = p4.maxStamina
    dodgeTarget.hp = 5000
    if (tm4.useSkill(slash, p4, dodgeTarget, 'perfect').missed) misses++
  }
  check('13+ perfect never misses (40/40 hit)', misses === 0, `${misses} misses`)
  p4.lastKanjiStrokes = 4
  misses = 0
  for (let i = 0; i < 40; i++) {
    p4.stamina = p4.maxStamina
    dodgeTarget.hp = 5000
    if (tm4.useSkill(slash, p4, dodgeTarget, 'perfect').missed) misses++
  }
  check('4-stroke perfect (-25%) still misses often vs 95% evasion', misses >= 15, `${misses}/40`)
  p4.lastKanjiStrokes = 0
  const origRand = Math.random
  Math.random = () => 0.5 // 0.5 < 0.95 miss chance -> always miss, deterministic
  misses = 0
  for (let i = 0; i < 40; i++) {
    p4.stamina = p4.maxStamina
    dodgeTarget.hp = 5000
    if (tm4.useSkill(slash, p4, dodgeTarget, 'success').missed) misses++
  }
  Math.random = origRand
  check('no-draw attacks vs 95% evasion always miss (fixed rng)', misses === 40, `${misses}/40`)
}

console.log(`\n${passed} passed, ${failed} failed`)
process.exit(failed > 0 ? 1 : 0)
