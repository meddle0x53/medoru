// Headless verification harness for Phase 4 (sites & economy cutover).
import './phaser-stub.js'

import { default as Player, ROLL_PRICES } from '../entities/Player.js'
import { default as HomeShopScene, SHOP_ITEMS } from '../scenes/HomeShopScene.js'
import { default as RestScene } from '../scenes/RestScene.js'
import { default as ShopScene } from '../scenes/ShopScene.js'
import { apply } from '../systems/UpgradeEngine.js'

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

console.log('HomeShopScene')
{
  const ids = SHOP_ITEMS.map(i => i.id)
  check('stat_point item removed', !ids.includes('stat_point'), JSON.stringify(ids))
  check('weapon_upgrade_run item removed', !ids.includes('weapon_upgrade_run'))
  const rollItems = SHOP_ITEMS.filter(i => i.tier)
  check('4 roll items', rollItems.length === 4, `${rollItems.length}`)
  check('roll scale prices 5/10/18/25',
    rollItems.every(i => i.costScales === ROLL_PRICES.scales[i.tier]),
    JSON.stringify(rollItems.map(i => [i.tier, i.costScales])))
  check('kept: chest/memory/cascade/permanent',
    ['chest', 'memory', 'cascade', 'weapon_upgrade_permanent'].every(id => ids.includes(id)))
  const perm = SHOP_ITEMS.find(i => i.id === 'weapon_upgrade_permanent')
  check('permanent upgrade still 5 scales + 1 source', perm.costScales === 5 && perm.costSource === 1)

  const p = freshPlayer()
  p.loadout.ouroScales = 20
  let restarts = 0
  const scene = makeSceneInstance(HomeShopScene, { player: p, tile: null, mapIndex: 0, scene: { restart: () => { restarts++ } } })
  const rareItem = SHOP_ITEMS.find(i => i.tier === 'rare')
  scene.buyItem(rareItem)
  check('rare roll bought (stored, not activated)', p.loadout.rollInventory.rare === 1, `${p.loadout.rollInventory.rare}`)
  check('scales deducted (18)', p.loadout.ouroScales === 2, `${p.loadout.ouroScales}`)
  check('scene restarted to refresh counts', restarts === 1)

  const broke = freshPlayer()
  broke.loadout.ouroScales = 3
  const scene2 = makeSceneInstance(HomeShopScene, { player: broke, scene: { restart: () => {} } })
  scene2.buyItem(SHOP_ITEMS.find(i => i.tier === 'epic'))
  check('insufficient scales rejected', broke.loadout.rollInventory.epic === 0 && broke.loadout.ouroScales === 3)
}

console.log('RestScene')
{
  const p = freshPlayer()
  p.loadout.gold = 300
  p.hp = 50
  const mkBtn = () => ({ bg: { removeInteractive() { this.disabled = true }, setFillStyle(c) { this.color = c }, disabled: false, color: null }, text: { setText(t) { this.label = t }, label: '' } })
  const restBtn = mkBtn(), weaponBtn = mkBtn(), shieldBtn = mkBtn()
  const rollBtns = ['common', 'uncommon', 'rare', 'epic'].map(tier => ({ ...mkBtn(), tier }))
  const scene = makeSceneInstance(RestScene, {
    player: p, tile: null, actionsUsed: 0, actionsAllowed: 1,
    restBtn, weaponBtn, shieldBtn, rollBtns,
    goldText: { setText() {} },
    showToast(m) { this.lastToast = m },
  })

  scene.onBuyRoll('uncommon')
  check('gold roll bought (stored, not activated)', p.loadout.rollInventory.uncommon === 1)
  check('gold deducted 100', p.loadout.gold === 200, `${p.loadout.gold}`)
  check('purchase consumes the visit action', scene.actionsUsed === 1)
  check('rest button disabled after purchase', restBtn.bg.disabled === true)
  check('other roll buttons disabled too', rollBtns.every(b => b.bg.disabled === true))

  scene.onBuyRoll('rare')
  check('second action refused', p.loadout.rollInventory.rare === 0 && scene.lastToast === 'No actions left here.')

  const p2 = freshPlayer()
  p2.hp = 50
  const restBtn2 = mkBtn(), weaponBtn2 = mkBtn(), shieldBtn2 = mkBtn()
  const rollBtns2 = ['common', 'uncommon', 'rare', 'epic'].map(tier => ({ ...mkBtn(), tier }))
  const scene2 = makeSceneInstance(RestScene, {
    player: p2, tile: null, actionsUsed: 0, actionsAllowed: 1,
    restBtn: restBtn2, weaponBtn: weaponBtn2, shieldBtn: shieldBtn2, rollBtns: rollBtns2,
    goldText: { setText() {} },
    hpText: { setText() {} },
    weaponInfoText: { setText() {} },
    shieldInfoText: { setText() {} },
    showToast(m) { this.lastToast = m },
    time: { delayedCall() {} },
  })
  scene2.onRest()
  check('rest takes the action', scene2.actionsUsed === 1)
  scene2.onBuyRoll('common')
  check('roll refused after rest', p2.loadout.rollInventory.common === 0)

  const p3 = freshPlayer()
  p3.loadout.gold = 30
  const scene3 = makeSceneInstance(RestScene, { player: p3, actionsUsed: 0, actionsAllowed: 1, rollBtns: [], goldText: { setText() {} }, showToast(m) { this.lastToast = m } })
  scene3.onBuyRoll('rare')
  check('insufficient gold rejected', p3.loadout.rollInventory.rare === 0 && p3.loadout.gold === 30)
  check('gold prices 50/100/180/250',
    ROLL_PRICES.gold.common === 50 && ROLL_PRICES.gold.uncommon === 100 && ROLL_PRICES.gold.rare === 180 && ROLL_PRICES.gold.epic === 250)

  // Camp Comfort: each stack grants +1 action per visit.
  const p4 = freshPlayer()
  apply(p4, 'camp_comfort')
  apply(p4, 'camp_comfort')
  p4.loadout.gold = 300
  p4.hp = 50
  const btns4 = { restBtn: mkBtn(), weaponBtn: mkBtn(), shieldBtn: mkBtn() }
  const rollBtns4 = ['common', 'uncommon', 'rare', 'epic'].map(tier => ({ ...mkBtn(), tier }))
  let exits = 0
  const scene4 = makeSceneInstance(RestScene, {
    player: p4, tile: null, actionsUsed: 0,
    actionsAllowed: 1 + (p4.loadout.runUpgrades || []).filter(u => (u.upgradeId || u.id) === 'camp_comfort').length,
    ...btns4, rollBtns: rollBtns4,
    goldText: { setText() {} },
    hpText: { setText() {} },
    weaponInfoText: { setText() {} },
    shieldInfoText: { setText() {} },
    showToast(m) { this.lastToast = m },
    time: { delayedCall(delay, fn) { fn(); exits++ } },
    completeTile() { exits++ },
  })
  check('camp comfort grants 3 actions', scene4.actionsAllowed === 3, `${scene4.actionsAllowed}`)
  scene4.onRest()
  check('rest did not exit with actions remaining', exits === 0, `${exits}`)
  check('buttons still enabled after first action', btns4.restBtn.bg.disabled !== true)
  scene4.onBuyRoll('common')
  scene4.onUpgradeWeapon()
  check('three actions consumed', scene4.actionsUsed === 3)
  check('buttons disabled after last action', btns4.restBtn.bg.disabled === true)
  scene4.onBuyRoll('uncommon')
  check('fourth action refused', p4.loadout.rollInventory.uncommon === 0)
}

console.log('ShopScene')
{
  let abilityRows = 0, otherRows = 0
  for (let i = 0; i < 100; i++) {
    const p = freshPlayer()
    const scene = makeSceneInstance(ShopScene, { player: p })
    const stock = ShopScene.prototype.generateStock.call(scene)
    if (stock.some(e => e.type === 'ability')) abilityRows++
    if (stock.some(e => e.type === 'item') && stock.some(e => e.type === 'heroCharm')) otherRows++
    if (stock.length === 0) check('stock never empty', false)
  }
  check('no ability stock in 100 rolls', abilityRows === 0)
  check('charms + items still stocked', otherRows === 100, `${otherRows}`)
}

console.log('Player legacy loadout handling')
{
  const legacy = {
    class: 'warrior',
    statPoints: 7,
    statAllocations: { vitality: 3, strength: 2 },
    permanentStatPointBonus: 4,
    singleUseCharges: { quick_stab: 2 },
    knownActionIds: ['forward_slash'],
    selectedActionIds: ['forward_slash', 'use_item'],
    activeActionIds: ['forward_slash', 'use_item'],
    gold: 5,
    ouroScales: 9,
    mapVersion: 5,
  }
  globalThis.localStorage.setItem('medoru_loadout_public_v1', JSON.stringify(legacy))
  const p = new Player({ name: 'Legacy', level: 10 })
  check('statPoints dropped', p.loadout.statPoints === undefined)
  check('statAllocations dropped', p.loadout.statAllocations === undefined)
  check('permanentStatPointBonus dropped', p.loadout.permanentStatPointBonus === undefined)
  check('singleUseCharges dropped', p.loadout.singleUseCharges === undefined)
  check('legacy allocations NOT applied (base stats pristine)',
    p.baseStats.vitality === p.startingBaseStats.vitality && p.baseStats.strength === p.startingBaseStats.strength,
    JSON.stringify({ vit: p.baseStats.vitality, str: p.baseStats.strength }))
  check('new run keys backfilled',
    Array.isArray(p.loadout.runUpgrades) && p.loadout.activeRoll === undefined &&
    p.loadout.rollInventory && typeof p.loadout.rollInventory.common === 'number')
  check('stale mapVersion invalidates mapState', p.loadout.mapState === null && p.loadout.mapVersion >= 7)
  globalThis.localStorage.removeItem('medoru_loadout_public_v1')
}

console.log(`\n${passed} passed, ${failed} failed`)
process.exit(failed > 0 ? 1 : 0)
