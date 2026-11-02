// Headless verification harness for Phase 3 + D12 revision.
import './phaser-stub.js'

import { default as Player } from '../entities/Player.js'
import { default as UpgradeScene } from '../scenes/UpgradeScene.js'
import { default as WinScene } from '../scenes/WinScene.js'
import { default as LoadoutScene } from '../scenes/LoadoutScene.js'
import { default as WinChallengeSystem } from '../systems/WinChallengeSystem.js'
import { apply, countUpgrade, UPGRADES_BY_ID } from '../systems/UpgradeEngine.js'

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

console.log('UpgradeScene')
{
  const p = freshPlayer()
  const scene = makeSceneInstance(UpgradeScene, { player: p, returnScene: 'MapScene', mapIndex: 2, tier: 'common', rerollsLeft: 1, cards: [], chosen: false, returnData: null })
  check('tier from init data', scene.resolveTier() === 'common')
  const sceneR = makeSceneInstance(UpgradeScene, { player: p, tier: 'rare', rerollsLeft: 1, cards: [], chosen: false, returnData: null })
  check('explicit tier honored', sceneR.resolveTier() === 'rare')

  const cards = scene.rollCards()
  check('cards generated', cards.length >= 3, `${cards.length}`)

  const pick = cards[0]
  const res = scene.chooseCard(pick)
  check('choose applies card', res.ok && countUpgrade(p, pick.id) === 1, JSON.stringify(res))
  check('choose is one-shot', !scene.chooseCard(cards[1]).ok)

  const p2 = freshPlayer()
  const scene2 = makeSceneInstance(UpgradeScene, { player: p2, tier: 'rare', rerollsLeft: 1, cards: [], chosen: false, returnData: null })
  const before = scene2.rollCards()
  const after = scene2.rerollOutcome(true)
  check('pass regenerates cards', after.regenerated && scene2.cards.length >= 1 && scene2.cards.length <= 3)
  const band = ['rare', 'epic']
  check('regenerated slot-1 honors same tier floor', band.includes(scene2.cards[0].rarity), scene2.cards[0].rarity)

  const kept = scene2.cards
  const failRes = scene2.rerollOutcome(false)
  check('fail keeps cards', !failRes.regenerated && scene2.cards === kept)

  const p3 = freshPlayer()
  let guard = 0
  while (guard++ < 600) {
    let any = false
    for (const c of Object.values(UPGRADES_BY_ID)) { if (apply(p3, c.id).ok) any = true }
    if (!any) break
  }
  const scene3 = makeSceneInstance(UpgradeScene, { player: p3, returnScene: 'MapScene', mapIndex: 0, tier: 'common', returnData: null })
  check('exhausted pool -> no cards', scene3.rollCards().length === 0)
  let exitTarget = null
  scene3.scene = { start: (key, data) => { exitTarget = { key, data } } }
  scene3.exit()
  check('exit goes to returnScene with player', exitTarget?.key === 'MapScene' && exitTarget?.data?.player === p3, JSON.stringify(exitTarget?.key))
  const scene4 = makeSceneInstance(UpgradeScene, { player: p3, returnScene: 'LoadoutScene', returnData: { player: p3, mode: 'map' } })
  scene4.scene = { start: (key, data) => { exitTarget = { key, data } } }
  scene4.exit()
  check('exit honors returnData when provided', exitTarget?.key === 'LoadoutScene' && exitTarget?.data?.mode === 'map', JSON.stringify(exitTarget))

  let pf = null
  WinChallengeSystem.prototype.runPassFail.call(
    { pickKanji: () => null },
    () => { pf = 'pass' }, () => { pf = 'fail' }
  )
  check('runPassFail passes with no drawable kanji', pf === 'pass')
  WinChallengeSystem.prototype.runPassFail.call(
    { pickKanji: () => ({ character: '一' }), startKanjiChallenge: (k, cb) => cb(false) },
    () => { pf = 'pass' }, () => { pf = 'fail' }
  )
  check('runPassFail reports fail', pf === 'fail')
}

console.log('WinScene (D12 routing)')
{
  check('60% gate removed', typeof WinScene.prototype.shouldShowUpgradeScreen === 'undefined')

  const p = freshPlayer()
  const wsTile = makeSceneInstance(WinScene, { tile: { id: 't1', col: 7 }, player: p, monster: { level: 3 } })
  check('column from battle tile', wsTile.battleRewardColumn() === 7)
  const wsProxy = makeSceneInstance(WinScene, { tile: null, player: p, monster: { level: 4 } })
  check('column falls back to enemy level proxy', wsProxy.battleRewardColumn() === 4)

  const dist = (column, luck) => {
    const counts = { common: 0, uncommon: 0, rare: 0, epic: 0 }
    for (let i = 0; i < 5000; i++) counts[p.rollBattleRewardTier(column, luck)]++
    return counts
  }
  const c0 = dist(0, 0), c5 = dist(5, 0), c10 = dist(10, 0)
  const share = (d, t) => d[t] / 5000
  console.log('  col0 :', JSON.stringify(c0))
  console.log('  col5 :', JSON.stringify(c5))
  console.log('  col10:', JSON.stringify(c10))
  check('common share decreases with column',
    share(c0, 'common') > share(c5, 'common') && share(c5, 'common') > share(c10, 'common'),
    `${share(c0, 'common')} ${share(c5, 'common')} ${share(c10, 'common')}`)
  check('epic share increases with column',
    share(c0, 'epic') < share(c5, 'epic') && share(c5, 'epic') < share(c10, 'epic'),
    `${share(c0, 'epic')} ${share(c5, 'epic')} ${share(c10, 'epic')}`)
  const luck0 = dist(0, 0), luck99 = dist(0, 99)
  check('high luck shifts weight off common', share(luck99, 'common') < share(luck0, 'common'),
    `${share(luck0, 'common')} -> ${share(luck99, 'common')}`)
  check('high luck boosts rare+epic', share(luck99, 'rare') + share(luck99, 'epic') > share(luck0, 'rare') + share(luck0, 'epic'))

  const texts = () => ({ setText() {}, setColor() {}, setVisible() {} })
  const ws = makeSceneInstance(WinScene, {
    player: p,
    baseGold: 100,
    goldReward: 100,
    essenceGained: 4,
    challengeMultiplier: 1,
    goldText: texts(),
    essenceText: texts(),
    essenceIcon: { setVisible() {} },
  })
  check('no attribute-points remnants', ws.attributePoints === undefined && ws.baseAttributePoints === undefined)
  ws.applyChallengeResult({ success: true, multiplier: 2.0 })
  check('gamble doubles gold', ws.goldReward === 200, `${ws.goldReward}`)
  check('gamble doubles essence', ws.essenceGained === 8, `${ws.essenceGained}`)
  ws.applyChallengeResult({ success: false, multiplier: 0.5 })
  check('failed gamble halves gold', ws.goldReward === 50, `${ws.goldReward}`)
}

console.log('LoadoutScene roll chips')
{
  const p = freshPlayer()
  p.loadout.ouroScales = 100
  const ls = makeSceneInstance(LoadoutScene, { player: p, mode: 'battle', returnScene: 'BattleScene', tile: { id: 't' }, mapIndex: 1 })
  let started = null
  ls.scene = { start: (key, data) => { started = { key, data } } }
  ls.refreshRollSelector = () => {}
  ls.showToast = () => {}

  p.buyRoll('rare', 'scales')
  let r = ls.applyRollTap('rare')
  check('chip tap triggers screen', r.action === 'triggered' && started?.key === 'UpgradeScene', JSON.stringify(r))
  check('screen gets the roll tier', started?.data?.tier === 'rare', JSON.stringify(started?.data))
  check('roll consumed on trigger', p.loadout.rollInventory.rare === 0)
  check('returns to battle prep', started?.data?.returnScene === 'BattleScene' && started?.data?.returnData?.tile?.id === 't')

  started = null
  r = ls.applyRollTap('epic')
  check('empty inventory -> no transition', r.action === 'failed' && started === null, JSON.stringify(r))

  const lsMap = makeSceneInstance(LoadoutScene, { player: p, mode: 'map', returnScene: 'MapScene', tile: null, mapIndex: 0 })
  lsMap.scene = { start: (key, data) => { started = { key, data } } }
  p.buyRoll('common', 'scales')
  lsMap.applyRollTap('common')
  check('map mode returns to LoadoutScene', started?.data?.returnScene === 'LoadoutScene' && started?.data?.returnData?.mode === 'map')
}

console.log(`\n${passed} passed, ${failed} failed`)
process.exit(failed > 0 ? 1 : 0)
