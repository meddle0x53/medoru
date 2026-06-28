import { LEVEL_1_MAPS } from './level_1/index.js'
import { LEVEL_2_MAPS } from './level_2/index.js'

/**
 * Central registry for all map definitions.
 *
 * Maps are imported at build time. The registry assigns a stable numeric index
 * to each map for save compatibility, while also grouping maps by level so a
 * future level selector can pick the right pool.
 */

export const MAP_DEFINITIONS = [...LEVEL_1_MAPS, ...LEVEL_2_MAPS]

MAP_DEFINITIONS.forEach((definition, index) => {
  if (definition.index === undefined) {
    definition.index = index
  }
})

export const MAPS_BY_LEVEL = MAP_DEFINITIONS.reduce((acc, definition) => {
  const level = definition.level || 1
  if (!acc[level]) acc[level] = []
  acc[level].push(definition)
  return acc
}, {})

export function getMapDefinition(indexOrId) {
  if (typeof indexOrId === 'number') {
    return MAP_DEFINITIONS[indexOrId] || MAP_DEFINITIONS[0]
  }
  if (typeof indexOrId === 'string') {
    return MAP_DEFINITIONS.find(def => def.id === indexOrId) || MAP_DEFINITIONS[0]
  }
  return MAP_DEFINITIONS[0]
}

export function getMapName(map, userLevel = 1) {
  if (!map) return ''
  const localized = userLevel >= 10 ? (map.nameJa || map.nameEn) : (map.nameEn || map.nameJa)
  return localized || map.name || ''
}
