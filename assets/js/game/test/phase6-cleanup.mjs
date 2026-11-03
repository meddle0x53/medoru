// Headless verification harness for Phase 6 (final cleanup).
import './phaser-stub.js'
import fs from 'node:fs'
import path from 'node:path'

import { default as Player } from '../entities/Player.js'
import { openChest } from '../systems/ChestRewards.js'

// Repo root: the runner invokes node from assets/, so cwd is assets/.
const ROOT = process.env.MEDORU_REPO_ROOT || path.resolve(process.cwd(), '..')
let passed = 0, failed = 0
function check(name, cond, detail = '') {
  if (cond) { passed++; console.log(`  PASS ${name}`) }
  else { failed++; console.log(`  FAIL ${name} ${detail}`) }
}
function freshPlayer() { return new Player({ name: 'Harness', level: 10 }) }

console.log('stat-point / charge remnant sweep')
{
  const gameDir = path.join(ROOT, 'assets/js/game')
  const files = []
  const walk = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, e.name)
      if (e.isDirectory()) walk(full)
      else if (e.name.endsWith('.js')) files.push(full)
    }
  }
  walk(gameDir)
  const pattern = /\bstatPoints\b|\bstatAllocations\b|\bbaseAttributePoints\b|\battributePoints\b|\bsingleUse\b/
  const offenders = []
  for (const f of files) {
    const src = fs.readFileSync(f, 'utf8')
    const rel = path.relative(gameDir, f)
    if (rel === 'entities/Player.js') {
      // Only the intentional loadout-migration deletes may remain.
      const lines = src.split('\n').filter(l => pattern.test(l) && !l.includes('delete loadout.') && !l.trim().startsWith('//'))
      if (lines.length > 0) offenders.push(`${rel}: ${lines.length} non-delete non-comment lines`)
      continue
    }
    const lines = src.split('\n').filter(l => pattern.test(l))
    if (lines.length > 0) offenders.push(`${rel}: ${lines.join(' | ').slice(0, 120)}`)
  }
  check('no remnants outside Player.js migration deletes', offenders.length === 0, JSON.stringify(offenders))
  const playerSrc = fs.readFileSync(path.join(gameDir, 'entities/Player.js'), 'utf8')
  check('migration deletes still present (kept, harmless)', playerSrc.includes('delete loadout.singleUseCharges') && playerSrc.includes('delete loadout.statAllocations'))
}

console.log('MAP_VERSION 7 invalidates v6 saves')
{
  const v6save = {
    class: 'warrior',
    mapVersion: 6,
    mapState: { currentMapIndex: 0, currentTileId: 'x', maps: [{ index: 0, columns: [[{ id: 'x', col: 0, row: 0, type: 'battle', completed: false, reachable: true, connections: [] }]] }] },
    knownActionIds: ['forward_slash'],
    selectedActionIds: ['forward_slash', 'use_item'],
    activeActionIds: ['forward_slash', 'use_item'],
    gold: 0,
    ouroScales: 3,
  }
  globalThis.localStorage.setItem('medoru_loadout_public_v1', JSON.stringify(v6save))
  const p = new Player({ name: 'V6', level: 10 })
  check('mapVersion-6 mapState nulled', p.loadout.mapState === null, JSON.stringify(p.loadout.mapState))
  check('mapVersion bumped to 7', p.loadout.mapVersion === 7, `${p.loadout.mapVersion}`)
  globalThis.localStorage.removeItem('medoru_loadout_public_v1')
}

console.log('staminaRegen turn-start proc')
{
  const p = freshPlayer()
  check('no regen without charm', (p.getCharmEffects().staminaRegen || 0) === 0)
  p.loadout.heroCharmIds = ['kitsune_tail_charm']
  p._charmEffects = null
  check('kitsune tail grants staminaRegen 2', p.getCharmEffects().staminaRegen === 2, `${p.getCharmEffects().staminaRegen}`)
  const baseMax = freshPlayer().maxStamina
  p.recalcMaxStamina()
  check('kitsune tail -> +2 max Energy', p.maxStamina === baseMax + 2, `${p.maxStamina} vs ${baseMax}`)
  // mizu charm (value 1)
  const p2 = freshPlayer()
  p2.loadout.heroCharmIds = ['mizu_charm']
  p2._charmEffects = null
  p2.recalcMaxStamina()
  check('mizu charm -> +1 max Energy', p2.maxStamina === baseMax + 1, `${p2.maxStamina}`)
  // socket charm regen_stamina proc (wind spirit) remains SocketProcSystem-wired
  const p3 = freshPlayer()
  p3.weapon.socketCharmIds[1] = 'wind_spirit_charm_sword'
  p3._charmEffects = null
  check('wind spirit proc charm still equippable', p3.getSocketCharmInSlot(p3.weapon, 1)?.id === 'wind_spirit_charm_sword')
}

console.log('chest: no stat points')
{
  const types = new Set()
  for (let i = 0; i < 100; i++) {
    const p = freshPlayer()
    for (const r of openChest(p)) types.add(r.type)
  }
  check('chest rewards never include statPoint', !types.has('statPoint'), JSON.stringify([...types]))
  check('chest still gives gold/items', types.has('gold'))
}

console.log('cache versions agree')
{
  const tpl1 = fs.readFileSync(path.join(ROOT, 'lib/medoru_web/live/game_live.html.heex'), 'utf8')
  const tpl2 = fs.readFileSync(path.join(ROOT, 'lib/medoru_web/live/admin/game_live/game.html.heex'), 'utf8')
  const sw = fs.readFileSync(path.join(ROOT, 'priv/static/service-worker.js'), 'utf8')
  const v1 = tpl1.match(/game\.js\?v=(\d+)/)?.[1]
  const v2 = tpl2.match(/game\.js\?v=(\d+)/)?.[1]
  const v3 = sw.match(/game\.js\?v=(\d+)/)?.[1]
  check('public template has a cache version', !!v1, String(v1))
  check('admin template has a cache version', !!v2, String(v2))
  check('all three agree on the same version', !!v1 && v1 === v2 && v2 === v3, `${v1}/${v2}/${v3}`)
  check('SW cache name is versioned', /medoru-v\d+/.test(sw), sw.match(/CACHE_NAME = "([^"]+)"/)?.[1])
  const bundle = fs.statSync(path.join(ROOT, 'priv/static/assets/js/game.js'))
  check('bundle exists (fresh build)', bundle.size > 900000, `${bundle.size}`)
}

console.log(`\n${passed} passed, ${failed} failed`)
process.exit(failed > 0 ? 1 : 0)
