/**
 * Enemy definition loader.
 *
 * Each enemy lives in its own JSON file under this folder. Add a new enemy by
 * creating a JSON file and importing it below.
 */

import kasaObake from './kasa_obake.json'
import kasaObakeElite from './kasa_obake_elite.json'
import kasaObakeTyrant from './kasa_obake_tyrant.json'
import hitotsumeKozo from './hitotsume_kozo.json'
import honeOnna from './hone_onna.json'
import kyubiKitsune from './kyubi_kitsune.json'
import bakeNeko from './bake_neko.json'
import danzaburoDanuki from './danzaburo_danuki.json'
import tanukiClone from './tanuki_clone.json'
import raijuSekigan from './raiju_sekigan.json'

export const ENEMY_DEFINITIONS = [
  bakeNeko,
  kasaObake,
  kasaObakeElite,
  kasaObakeTyrant,
  hitotsumeKozo,
  honeOnna,
  kyubiKitsune,
  danzaburoDanuki,
  tanukiClone,
  raijuSekigan,
]

export function getEnemyDefinition(id) {
  return ENEMY_DEFINITIONS.find(e => e.id === id)
}

function pickWeightedEnemy(pool, foughtEnemyIds, { excludeFought = false } = {}) {
  const fought = (id) => (foughtEnemyIds || []).includes(id)
  let weights = pool.map(def => {
    if (fought(def.id)) return excludeFought ? 0 : 0.5
    return 1
  })
  // Exclusion is a preference, not a hard guarantee: if every candidate was
  // already fought, fall back to the usual half-weight variety nudge.
  if (excludeFought && weights.every(w => w === 0)) {
    weights = pool.map(def => (fought(def.id) ? 0.5 : 1))
  }
  const total = weights.reduce((a, b) => a + b, 0)
  let roll = Math.random() * total
  for (let i = 0; i < pool.length; i++) {
    roll -= weights[i]
    if (roll <= 0) return pool[i]
  }
  return pool[pool.length - 1]
}

export function pickEnemyForTile(tile, mapIndex, foughtEnemyIds = []) {
  const role = tile?.type === 'mini_boss' ? 'mini_boss'
             : tile?.type === 'boss' ? 'boss'
             : 'battle'

  // If the map JSON supplied an explicit enemy pool for this tile, use it.
  if (tile?.enemyPool?.length > 0) {
    const pool = tile.enemyPool
      .map(id => getEnemyDefinition(id))
      .filter(Boolean)
    if (pool.length > 0) {
      // Mini-bosses already fought this run are excluded so the player never
      // faces the same mini-boss twice in one run (unless there is no choice).
      return pickWeightedEnemy(pool, foughtEnemyIds, { excludeFought: role === 'mini_boss' })
    }
  }

  // Fallback to the enemy JSON's own role/map/column restrictions.
  const mapId = (mapIndex ?? 0) + 1
  const col = tile?.col ?? 1

  const pool = ENEMY_DEFINITIONS.filter(def =>
    def.roles.includes(role) &&
    def.mapIds.includes(mapId) &&
    def.maxColumn >= col
  )

  if (pool.length === 0) {
    const fallbackPool = ENEMY_DEFINITIONS.filter(def => def.roles.includes(role))
    if (fallbackPool.length === 0) return ENEMY_DEFINITIONS[0]
    return pickWeightedEnemy(fallbackPool, foughtEnemyIds, { excludeFought: role === 'mini_boss' })
  }

  return pickWeightedEnemy(pool, foughtEnemyIds, { excludeFought: role === 'mini_boss' })
}

/**
 * Returns all image texture keys referenced by an enemy definition
 * (sprites, phase sprites, portrait, icon), excluding comment/utility keys.
 */
export function getEnemyTextureKeys(definition) {
  const keys = new Set()
  if (!definition) return keys

  for (const [pose, key] of Object.entries(definition.sprites || {})) {
    if (pose.startsWith('_') || typeof key !== 'string') continue
    keys.add(key)
  }

  for (const phase of definition.phases || []) {
    for (const [pose, key] of Object.entries(phase.sprites || {})) {
      if (pose.startsWith('_') || typeof key !== 'string') continue
      keys.add(key)
    }
  }

  if (typeof definition.portrait === 'string') keys.add(definition.portrait)
  if (typeof definition.icon === 'string') keys.add(definition.icon)

  return Array.from(keys)
}

export function rollEnemyDrops(enemy, playerClass = 'warrior', ngPlusMultiplier = 1) {
  const table = (enemy?.definition?.drops && enemy.definition.drops[playerClass]) || []
  const scaleChance = (c) => Math.min(1, c * ngPlusMultiplier)
  return table.filter(drop => Math.random() < scaleChance(drop.chance))
}
