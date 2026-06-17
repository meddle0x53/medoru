/**
 * Enemy definition loader.
 *
 * Each enemy lives in its own JSON file under this folder. Add a new enemy by
 * creating a JSON file and importing it below.
 */

import kasaObake from './kasa_obake.json'
import kasaObakeElite from './kasa_obake_elite.json'
import kasaObakeTyrant from './kasa_obake_tyrant.json'

export const ENEMY_DEFINITIONS = [
  kasaObake,
  kasaObakeElite,
  kasaObakeTyrant,
]

export function getEnemyDefinition(id) {
  return ENEMY_DEFINITIONS.find(e => e.id === id)
}

export function pickEnemyForTile(tile, mapIndex) {
  const mapId = (mapIndex ?? 0) + 1
  const col = tile?.col ?? 1
  const role = tile?.type === 'mini_boss' ? 'mini_boss'
             : tile?.type === 'boss' ? 'boss'
             : 'battle'

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

export function rollEnemyDrops(enemy, playerClass = 'warrior') {
  const table = (enemy?.definition?.drops && enemy.definition.drops[playerClass]) || []
  return table.filter(drop => Math.random() < drop.chance)
}
