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

export function pickEnemyForTile(tile, mapIndex) {
  const role = tile?.type === 'mini_boss' ? 'mini_boss'
             : tile?.type === 'boss' ? 'boss'
             : 'battle'

  // If the map JSON supplied an explicit enemy pool for this tile, use it.
  if (tile?.enemyPool?.length > 0) {
    const pool = tile.enemyPool
      .map(id => getEnemyDefinition(id))
      .filter(Boolean)
    if (pool.length > 0) {
      return pool[Math.floor(Math.random() * pool.length)]
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
    const fallback = ENEMY_DEFINITIONS.find(def => def.roles.includes(role))
    return fallback || ENEMY_DEFINITIONS[0]
  }

  return pool[Math.floor(Math.random() * pool.length)]
}

export function rollEnemyDrops(enemy, playerClass = 'warrior', ngPlusMultiplier = 1) {
  const table = (enemy?.definition?.drops && enemy.definition.drops[playerClass]) || []
  const scaleChance = (c) => Math.min(1, c * ngPlusMultiplier)
  return table.filter(drop => Math.random() < scaleChance(drop.chance))
}
