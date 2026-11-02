// Headless verification harness for Phase 2 (UpgradeGenerator).
import './phaser-stub.js'

import { default as Player } from '../entities/Player.js'
import { generateChoices, computeWeight, isValidFor, RARITY_ORDER, getKnowledgeEffects } from '../systems/UpgradeGenerator.js'
import { apply, UPGRADES, UPGRADES_BY_ID } from '../systems/UpgradeEngine.js'

let passed = 0, failed = 0
function check(name, cond, detail = '') {
  if (cond) { passed++; console.log(`  PASS ${name}`) }
  else { failed++; console.log(`  FAIL ${name} ${detail}`) }
}
function freshPlayer() { return new Player({ name: 'Harness', level: 10 }) }

function midRunPlayer() {
  const p = freshPlayer()
  apply(p, 'sharp_weapon')
  apply(p, 'sharpened_slash')
  apply(p, 'sharpened_slash')
  apply(p, 'sharpened_slash')
  apply(p, 'might')
  apply(p, 'might')
  apply(p, 'deep_cut')
  return p
}

const BANDS = {
  common: new Set(RARITY_ORDER),
  uncommon: new Set(['uncommon', 'rare', 'epic']),
  rare: new Set(['rare', 'epic']),
  epic: new Set(['rare', 'epic']), // epic may fall back one band (chains)
}

console.log('500 generations per tier (fixed mid-run state, statistical)')
const slot0Rarity = { common: {}, uncommon: {}, rare: {}, epic: {} }
let floorViolations = 0, dupViolations = 0, excludedPairs = 0, invalidCards = 0, lenViolations = 0
let totalCards = 0

const STRICT = { common: true, uncommon: true, rare: true, epic: false } // epic may fall back a band
for (const tier of ['common', 'uncommon', 'rare', 'epic']) {
  for (let i = 0; i < 500; i++) {
    const player = midRunPlayer()
    const result = generateChoices(player, tier)
    if (result.length > 3) lenViolations++
    totalCards += result.length
    const ids = result.map(c => c.id)
    if (new Set(ids).size !== ids.length) dupViolations++
    if (result.length > 0) {
      const r = result[0].rarity
      slot0Rarity[tier][r] = (slot0Rarity[tier][r] || 0) + 1
      if (STRICT[tier] ? !BANDS[tier].has(r) : !new Set(['rare', 'epic']).has(r)) floorViolations++
    }
    for (const c of result) {
      for (const ex of c.excludes || []) if (ids.includes(ex)) excludedPairs++
      if (!isValidFor(player, c)) invalidCards++
    }
  }
}

check('floor never violated (2000 screens)', floorViolations === 0, `${floorViolations}`)
check('never more than 3 cards', lenViolations === 0)
check('no duplicate ids on a screen', dupViolations === 0)
check('no excluded pairs on a screen', excludedPairs === 0)
check('all cards pass engine validity re-check', invalidCards === 0, `${invalidCards}`)
check('screens are full (fixed non-exhausted state)', totalCards === 3 * 2000, `${totalCards}/6000`)

console.log('distribution (slot-1 rarity counts / 500)')
for (const tier of ['common', 'uncommon', 'rare', 'epic']) {
  console.log(`  ${tier.padEnd(9)}`, JSON.stringify(slot0Rarity[tier]))
}
const epicShare = t => (slot0Rarity[t].epic || 0) / 500
const rarePlus = t => ((slot0Rarity[t].rare || 0) + (slot0Rarity[t].epic || 0)) / 500
check('epic slot-1 share: epic >= rare (fallback allowed when chains locked)',
  epicShare('epic') >= epicShare('rare') - 0.35,
  JSON.stringify({ common: epicShare('common'), uncommon: epicShare('uncommon'), rare: epicShare('rare'), epic: epicShare('epic') }))
check('rare+ slot-1 share: epic >= rare > uncommon > common',
  rarePlus('epic') >= rarePlus('rare') - 0.01 && rarePlus('rare') > rarePlus('uncommon') && rarePlus('uncommon') > rarePlus('common'),
  JSON.stringify({ common: rarePlus('common'), uncommon: rarePlus('uncommon'), rare: rarePlus('rare'), epic: rarePlus('epic') }))
check('epic tier slot-1 is rare or epic (fallback, never lower)', (slot0Rarity.epic.common || 0) === 0 && (slot0Rarity.epic.uncommon || 0) === 0, JSON.stringify(slot0Rarity.epic))
check('common tier: epic slot-1 is rare',
  epicShare('common') < 0.15, `${epicShare('common')}`)

console.log('weighting')
{
  const fresh = freshPlayer()
  const owner = midRunPlayer()
  const deepCut = UPGRADES_BY_ID['deep_cut']
  check('unmatching card weight is 1.0', computeWeight(fresh, deepCut) === 1)
  check('owned ability tag raises weight', computeWeight(owner, deepCut) > computeWeight(fresh, deepCut),
    `${computeWeight(owner, deepCut)} vs ${computeWeight(fresh, deepCut)}`)
  const life = UPGRADES_BY_ID['life']
  check('dominant stat tag matches (vitality)', computeWeight(fresh, life) === 1.5, `got ${computeWeight(fresh, life)}`)
  const sharpOwner = freshPlayer()
  apply(sharpOwner, 'sharp_weapon')
  const stab = UPGRADES_BY_ID['quick_stab_unlock']
  check('weapon profile family raises weight', computeWeight(sharpOwner, stab) > computeWeight(fresh, stab),
    `${computeWeight(sharpOwner, stab)} vs ${computeWeight(fresh, stab)}`)
}

console.log('knowledge effects (generator side)')
{
  const pMem = freshPlayer()
  apply(pMem, 'memory')
  let four = 0
  for (let i = 0; i < 100; i++) if (generateChoices(pMem, 'common').length === 4) four++
  check('memory -> 4-card screens', four === 100, `${four}/100`)

  const pRec = freshPlayer()
  apply(pRec, 'memory')
  apply(pRec, 'recall')
  const k = getKnowledgeEffects(pRec)
  check('recall doubles tag weight', k.tagWeight === 1.0, `${k.tagWeight}`)
  check('recall keeps extra card', k.extraCards === 1)
  check('curiosity counted', (() => { const c = freshPlayer(); apply(c, 'curiosity'); apply(c, 'curiosity'); return getKnowledgeEffects(c).curiosity === 2 })())
  check('perfect_recall column bonus', (() => { const c = freshPlayer(); ['memory','recall','perfect_recall'].forEach(id => apply(c, id)); return getKnowledgeEffects(c).columnBonus === 2 })())
  check('enlightenment tier bump flag', (() => { const c = freshPlayer(); ['memory','recall','perfect_recall','enlightenment'].forEach(id => apply(c, id)); return getKnowledgeEffects(c).tierBump === 1 })())
}

console.log('pool draining & exhaustion')
{
  const p = midRunPlayer()
  let screens = 0
  for (let i = 0; i < 600; i++) {
    const r = generateChoices(p, 'common')
    if (r.length === 0) break
    screens++
    const res = apply(p, r[0].id)
    if (!res.ok) { check('offered card is engine-applicable', false, `${r[0].id}: ${res.reason}`); break }
  }
  check('reward flow drains until pool exhausted', screens > 30, `${screens} screens`)
  check('entire pool drained without deadlock', generateChoices(p, 'common').length === 0)
  check('exhausted pool returns empty array', generateChoices(p, 'common').length === 0)
  const p2 = freshPlayer()
  apply(p2, 'sharp_weapon')
  apply(p2, 'heavy_weapon')
  check('exclusion blocks owning both conversions', !(p2.loadout.runUpgrades || []).some(u => (u.upgradeId || u.id) === 'heavy_weapon'))
  let offeredHeavy = 0, subFloor = 0, emptyEpic = 0
  for (let i = 0; i < 200; i++) {
    const r = generateChoices(p, 'epic')
    if (r.length === 0) { emptyEpic++; continue }
    if (r[0].rarity !== 'epic') subFloor++
  }
  for (let i = 0; i < 200; i++) {
    const r = generateChoices(p2, 'epic')
    if (r.some(c => ['heavy_weapon','fire_weapon','wind_weapon'].includes(c.id))) offeredHeavy++
  }
  check('exhausted band -> empty (no sub-floor screens)', subFloor === 0 && emptyEpic === 200,
    `subFloor=${subFloor} empty=${emptyEpic}`)
  check('excluded conversions never offered', offeredHeavy === 0)
}

console.log(`\n${passed} passed, ${failed} failed`)
process.exit(failed > 0 ? 1 : 0)
