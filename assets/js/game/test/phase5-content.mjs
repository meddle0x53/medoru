// Headless verification harness for Phase 5 (full pool + Loadout UI + rebalance).
import './phaser-stub.js'

import { default as Player } from '../entities/Player.js'
import { default as UpgradeScene } from '../scenes/UpgradeScene.js'
import { default as LoadoutScene } from '../scenes/LoadoutScene.js'
import { apply, UPGRADES, UPGRADES_BY_ID } from '../systems/UpgradeEngine.js'
import { generateChoices, isValidFor, bumpTier } from '../systems/UpgradeGenerator.js'
import { ALL_ACTIONS } from '../data/actions.js'

let passed = 0, failed = 0
function check(name, cond, detail = '') {
  if (cond) { passed++; console.log(`  PASS ${name}`) }
  else { failed++; console.log(`  FAIL ${name} ${detail}`) }
}
function freshPlayer() { return new Player({ name: 'Harness', level: 10 }) }
function makeSceneInstance(SceneClass, fields) {
  const inst = Object.create(SceneClass.prototype)
  Object.assign(inst, fields)
  return inst
}

console.log('pool integrity')
{
  const byFamily = {}, byRarity = {}
  for (const c of UPGRADES) {
    byFamily[c.family] = (byFamily[c.family] || 0) + 1
    byRarity[c.rarity] = (byRarity[c.rarity] || 0) + 1
  }
  console.log('  by family:', JSON.stringify(byFamily))
  console.log('  by rarity:', JSON.stringify(byRarity))
  check('pool size ~45+', UPGRADES.length >= 45, `${UPGRADES.length}`)
  check('rarity spread sane (epics 2-4)', byRarity.epic >= 2 && byRarity.epic <= 4, `${byRarity.epic}`)
  check('all 7 ability pools present',
    ['forward_slash', 'quick_stab', 'setup_defence', 'flame_arc', 'gale_strike', 'guard_break', 'seismic_slam']
      .every(id => UPGRADES.some(c => c.effect?.abilityId === id)))
  check('kanji attunement per ability',
    ['forward_slash', 'quick_stab', 'setup_defence', 'flame_arc', 'gale_strike', 'guard_break', 'seismic_slam']
      .every(id => UPGRADES.some(c => c.type === 'kanji_tier_up' && c.effect?.abilityId === id)))

  const p = freshPlayer()
  let applied = 0
  const counted = new Set()
  let expectedTotal = 0
  for (const c of UPGRADES) {
    if ((c.excludes || []).some(ex => counted.has(ex))) continue
    counted.add(c.id)
    expectedTotal += c.maxStacks || 1
  }
  let guard = 0
  while (guard++ < 5000) {
    let any = false
    for (const card of UPGRADES) {
      const r = apply(p, card.id)
      if (r.ok) { any = true; applied++ }
    }
    if (!any) break
  }
  check('whole pool drains without deadlock', applied === expectedTotal, `applied ${applied}/${expectedTotal}`)
  check('pool fully exhausted', UPGRADES.every(c => !isValidFor(p, c)))
  check('exhausted screens are empty', generateChoices(p, 'common').length === 0)
}

console.log('generator (full pool, 500/tier)')
{
  const BANDS = {
    uncommon: new Set(['uncommon', 'rare', 'epic']),
    rare: new Set(['rare', 'epic']),
    epic: new Set(['rare', 'epic']),
  }
  let floorOk = true, dups = 0, excluded = 0, invalid = 0
  for (const tier of ['uncommon', 'rare', 'epic']) {
    for (let i = 0; i < 500; i++) {
      const p = freshPlayer()
      const r = generateChoices(p, tier)
      if (r.length === 0 || !BANDS[tier].has(r[0].rarity)) floorOk = false
      const ids = r.map(c => c.id)
      if (new Set(ids).size !== ids.length) dups++
      for (const c of r) {
        for (const ex of c.excludes || []) if (ids.includes(ex)) excluded++
        if (!isValidFor(p, c)) invalid++
      }
    }
  }
  check('floor intact with full pool (1500 screens)', floorOk)
  check('no dups / exclusions / invalid', dups === 0 && excluded === 0 && invalid === 0, `${dups} ${excluded} ${invalid}`)
}

console.log('knowledge effects (scene side)')
{
  const p = freshPlayer()
  const inst = makeSceneInstance(UpgradeScene, {})
  UpgradeScene.prototype.init.call(inst, { player: p, tier: 'common' })
  check('default rerollsLeft = 1', inst.rerollsLeft === 1, `${inst.rerollsLeft}`)

  const p2 = freshPlayer()
  apply(p2, 'curiosity')
  apply(p2, 'curiosity')
  const inst2 = makeSceneInstance(UpgradeScene, {})
  UpgradeScene.prototype.init.call(inst2, { player: p2, tier: 'common' })
  check('curiosity: rerollsLeft = 1 + stacks', inst2.rerollsLeft === 3, `${inst2.rerollsLeft}`)

  const p3 = freshPlayer()
  ;['memory', 'recall', 'perfect_recall', 'enlightenment'].forEach(id => apply(p3, id))
  const inst3 = makeSceneInstance(UpgradeScene, {})
  UpgradeScene.prototype.init.call(inst3, { player: p3, tier: 'rare' })
  check('enlightenment bumps screen tier', inst3.tier === 'epic', inst3.tier)
  check('bumpTier mapping', bumpTier('common') === 'uncommon' && bumpTier('uncommon') === 'rare' && bumpTier('rare') === 'epic' && bumpTier('epic') === 'epic')
  const inst4 = makeSceneInstance(UpgradeScene, {})
  UpgradeScene.prototype.init.call(inst4, { player: p3, tier: 'epic' })
  check('bump capped at epic', inst4.tier === 'epic')
}

console.log('LoadoutScene run-upgrades tab')
{
  const p = freshPlayer()
  const ls = makeSceneInstance(LoadoutScene, { player: p, mode: 'map' })
  let model = ls.buildRunUpgradesModel()
  check('empty run: no upgrades/attunements', model.upgrades.length === 0 && model.attunements.length === 0)
  check('readouts present', model.readouts.length >= 6 && model.readouts.some(r => r.startsWith('Max HP')),
    JSON.stringify(model.readouts))

  apply(p, 'might')
  apply(p, 'might')
  apply(p, 'sharpened_slash')
  apply(p, 'kanji_attunement_slash')
  model = ls.buildRunUpgradesModel()
  const might = model.upgrades.find(u => u.name === 'Might')
  check('stacks aggregated', might && might.stacks === 2 && might.maxStacks === 10, JSON.stringify(might))
  const slash = model.upgrades.find(u => u.name === 'Sharpened Slash')
  check('rarity carried', slash && slash.rarity === 'common')
  check('attunements listed per ability', model.attunements.length === 1 && model.attunements[0].ability === 'Forward Slash' &&
    model.attunements[0].chars.length === 1 && model.attunements[0].chars[0].tier === 'blue',
    JSON.stringify(model.attunements))
}

console.log('stamina rebalance')
{
  check('no ability retains singleUse', ALL_ACTIONS.every(a => !a.singleUse))
  const cost = id => ALL_ACTIONS.find(a => a.id === id).staminaCost
  check('quick_stab 2 -> 4', cost('quick_stab') === 4)
  check('heavy_slash 4 -> 6', cost('heavy_slash') === 6)
  check('two_hand_heavy 5 -> 7', cost('two_hand_heavy') === 7)
  check('guard_break 5 -> 6', cost('guard_break') === 6)
  check('berserk 8 -> 9', cost('berserk') === 9)
  check('infuse_* 2 -> 3', cost('infuse_fire') === 3 && cost('infuse_bleed') === 3)

  const p = freshPlayer()
  const stab = ALL_ACTIONS.find(a => a.id === 'quick_stab')
  check('rebased cost flows through', p.getEffectiveAbility(stab).staminaCost === 4)
  apply(p, 'fleet_stab')
  apply(p, 'fleet_stab')
  check('cost reductions stack to min 1', p.getEffectiveAbility(stab).staminaCost === 2, `${p.getEffectiveAbility(stab).staminaCost}`)
  const pFull = freshPlayer()
  apply(pFull, 'quick_stab_unlock')
  apply(pFull, 'fleet_stab')
  apply(pFull, 'fleet_stab')
  apply(pFull, 'stamina_1')
  apply(pFull, 'stamina_2')
  apply(pFull, 'stamina_3')
  pFull.stamina = pFull.maxStamina
  check('usable ~2-3x per fight at 11+ energy', pFull.maxStamina >= 11 && pFull.getEffectiveAbility(stab).staminaCost * 3 <= pFull.maxStamina,
    `maxStamina=${pFull.maxStamina} cost=${pFull.getEffectiveAbility(stab).staminaCost}`)
}

console.log('shield profile')
{
  const p = freshPlayer()
  const base = p.getEffectiveShieldScaling()
  check('default shield scaling (strength D)', JSON.stringify(base) === JSON.stringify({ strength: 'D' }), JSON.stringify(base))
  check('sturdy_shield applies', apply(p, 'sturdy_shield').ok)
  const override = p.getEffectiveShieldScaling()
  check('shield override uses charm scaling (C at lv0)', override.strength === 'C', JSON.stringify(override))
  check('warding excluded after sturdy', !apply(p, 'warding_shield').ok)
  check('setup_defence amount reflects override', p.computeSetupDefenceAmount(ALL_ACTIONS.find(a => a.id === 'setup_defence'), 1) > 0)
}

console.log('kanji multiplier sanity')
{
  const p = freshPlayer()
  const slash = ALL_ACTIONS.find(a => a.id === 'forward_slash')
  for (const char of slash.kanjiPool) p.loadout.kanjiTiers['forward_slash'] = { ...(p.loadout.kanjiTiers['forward_slash'] || {}), [char]: 'silver' }
  const baseDmg = p.calculateWeaponDamage(slash)
  const stacked = Math.floor(baseDmg * 1.25 * 1.5 * 1.3 * 1.5)
  const bossHp = 260
  check('stacked silver perfect slash does NOT one-shot a boss', stacked < bossHp,
    `best hit ~${stacked} vs boss HP ${bossHp}`)
  check('...but it is a meaningful chunk', stacked > bossHp * 0.15, `${stacked}`)
}

console.log(`\n${passed} passed, ${failed} failed`)
process.exit(failed > 0 ? 1 : 0)
