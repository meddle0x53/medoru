import { GAME_CONFIG } from '../config.js'
import { TILE_TYPES, isBattleTile } from '../data/tileTypes.js'
import { getMapDefinition } from '../data/maps/index.js'

/**
 * Generate a planar layered graph for the rogue-like map.
 *
 * Map configuration (weights, images, constants, enemy pools) is read from the
 * map registry in assets/js/game/data/maps. This function still produces the
 * same map object shape as before so existing scenes and saves stay compatible.
 *
 * Structure:
 *   - 11 columns (0 = home, 1-9 = intermediate, 10 = boss)
 *   - Column 0 and 10 always have exactly 1 tile
 *   - Columns 1-9 have 2-5 tiles (column 1 capped at 3 because home can only
 *     branch to 1-3 tiles)
 *   - Connections between adjacent columns are non-crossing and each tile
 *     has 1-3 outgoing paths to the next column.
 */

const DEFAULT_COLUMN_COUNT = 11
const DEFAULT_HOME_COLUMN = 0
const DEFAULT_BOSS_COLUMN = 10
const DEFAULT_MAX_CONNECTIONS_PER_TILE = 3

const LAYOUT = {
  paddingX: 70,
  minY: 100,
  maxY: 440,
  minSpacing: 60,
}

export function getMapName(map, userLevel = 1) {
  if (!map) return ''
  const localized = userLevel >= 10 ? (map.nameJa || map.nameEn) : (map.nameEn || map.nameJa)
  // Backwards compatibility for saves created before the localized-name change.
  return localized || map.name || ''
}

export function generateMap(mapIndexOrId = 0) {
  const definition = getMapDefinition(mapIndexOrId)
  const constants = definition.constants || {}
  const columnCount = constants.columnCount || DEFAULT_COLUMN_COUNT
  const homeColumn = constants.homeColumn ?? DEFAULT_HOME_COLUMN
  const bossColumn = constants.bossColumn ?? DEFAULT_BOSS_COLUMN
  const maxConnections = constants.maxConnectionsPerTile || DEFAULT_MAX_CONNECTIONS_PER_TILE
  const columnConfigs = definition.columns || []

  const columns = []
  let tileCounter = 0

  for (let col = 0; col < columnCount; col++) {
    const colConfig = columnConfigs[col] || {}
    const tileCount = getTileCountForColumn(col, definition)
    const column = []
    const typePool = getTypePool(col, definition)

    for (let row = 0; row < tileCount; row++) {
      const type = col === homeColumn
        ? TILE_TYPES.HOME
        : col === bossColumn
          ? TILE_TYPES.BOSS
          : colConfig.fixedType || pickWeightedType(typePool)

      const tile = {
        id: `map-${definition.index}-tile-${tileCounter++}`,
        col,
        row,
        type,
        completed: false,
        reachable: col === homeColumn,
        connections: [],
      }

      attachEnemyPool(tile, definition, colConfig)
      column.push(tile)
    }

    columns.push(column)
  }

  // Connect columns with non-crossing, capped intervals
  for (let col = 0; col < columnCount - 1; col++) {
    connectColumns(columns[col], columns[col + 1], maxConnections)
  }

  enforceOncePerPath(columns, definition)

  const map = buildMapObject(definition, columns)
  computeLayout(map)
  return map
}

function buildMapObject(definition, columns) {
  const names = definition.names || {}
  const bg = definition.background || {}
  const tileImages = definition.tileImages || {}

  const map = {
    id: `map-${definition.index}`,
    index: definition.index,
    nameEn: names.en,
    nameJa: names.ja,
    backgroundImage: bg.image || null,
    background: bg,
    tileImages,
    columns,
  }

  // Backwards-compatible per-type image keys used by older MapScene code and
  // older saves. New code should prefer map.tileImages[type].
  const typeToField = {
    [TILE_TYPES.BATTLE]: 'battleTileImage',
    [TILE_TYPES.MINI_BOSS]: 'miniBossTileImage',
    [TILE_TYPES.BOSS]: 'bossTileImage',
    [TILE_TYPES.CHEST]: 'chestTileImage',
    [TILE_TYPES.SHOP]: 'shopTileImage',
    [TILE_TYPES.MEMORY]: 'memoryTileImage',
    [TILE_TYPES.SHORT_CASCADE]: 'cascadeTileImage',
    [TILE_TYPES.REST_CAMP]: 'restTileImage',
  }
  for (const [type, field] of Object.entries(typeToField)) {
    map[field] = tileImages[type]?.image || null
  }

  return map
}

function attachEnemyPool(tile, definition, colConfig) {
  if (!isBattleTile(tile.type)) return

  const role = tile.type === TILE_TYPES.MINI_BOSS
    ? 'mini_boss'
    : tile.type === TILE_TYPES.BOSS
      ? 'boss'
      : 'battle'

  const mapDefaults = definition.defaultEnemyPools || {}
  const pool = colConfig.enemyPools?.[role] || mapDefaults[role] || null
  if (pool && pool.length > 0) {
    tile.enemyPool = pool
  }
}

function connectColumns(sourceColumn, targetColumn, maxConnections) {
  const intervals = buildNonCrossingIntervals(
    sourceColumn.length,
    targetColumn.length,
    maxConnections,
  )

  for (let i = 0; i < sourceColumn.length; i++) {
    const [start, end] = intervals[i]
    sourceColumn[i].connections = targetColumn
      .slice(start, end + 1)
      .map(tile => tile.id)
  }
}

/**
 * Build a sequence of non-crossing intervals over [0, targetCount-1].
 *
 * Each interval has length between 1 and maxConnections, and the sequence
 * covers every target index without gaps. Adjacent intervals may share an
 * endpoint, but they never overlap, so the resulting edges do not cross.
 */
function buildNonCrossingIntervals(sourceCount, targetCount, maxConnections) {
  if (sourceCount <= 0 || targetCount <= 0) return []

  const intervals = []
  let start = 0

  for (let i = 0; i < sourceCount; i++) {
    const remainingSources = sourceCount - 1 - i
    const isLast = remainingSources === 0

    if (isLast) {
      intervals.push([start, targetCount - 1])
      break
    }

    // Lower bound: leave enough targets so the remaining sources can still
    // cover to the end (each can cover at most maxConnections new targets).
    const minEnd = Math.max(start, targetCount - 1 - remainingSources * maxConnections)
    // Upper bound: size cap and target boundary.
    const maxEnd = Math.min(targetCount - 1, start + maxConnections - 1)

    if (minEnd > maxEnd) {
      // Fallback (should not happen with valid inputs); advance one tile.
      intervals.push([start, start])
      start = Math.min(targetCount - 1, start + 1)
      continue
    }

    const end = randomInt(minEnd, maxEnd)
    intervals.push([start, end])

    const remainingAfterEnd = (targetCount - 1) - end
    const canShare = remainingSources * maxConnections >= remainingAfterEnd + 1
    const canAdvance = (end + 1 <= targetCount - 1) && remainingSources * maxConnections >= remainingAfterEnd

    if (canShare && canAdvance) {
      // Randomly share the endpoint or advance, creating light branching.
      start = Math.random() < 0.5 ? end : end + 1
    } else if (canShare) {
      start = end
    } else {
      start = end + 1
    }

    start = Math.min(start, targetCount - 1)
  }

  return intervals
}

/**
 * Compute tile (x, y) positions using a barycentric layout.
 *
 * Tiles are placed so that each tile sits near the vertical midpoint of its
 * connected neighbours, while keeping a minimum vertical spacing. This makes
 * the 1-3 outgoing paths from each tile straight and easy to read.
 */
export function computeLayout(map) {
  const columnCount = map.columns.length
  const usableWidth = GAME_CONFIG.width - LAYOUT.paddingX * 2

  // Initial positions: evenly spaced columns, rows spread across full height.
  for (let col = 0; col < columnCount; col++) {
    const column = map.columns[col]
    const count = column.length
    const x = LAYOUT.paddingX + (col / (columnCount - 1)) * usableWidth
    const rowSpacing = (LAYOUT.maxY - LAYOUT.minY) / (count + 1)
    for (let row = 0; row < count; row++) {
      const tile = column[row]
      tile.x = x
      tile.y = LAYOUT.minY + (row + 1) * rowSpacing
    }
  }

  // Build predecessor / successor lookup maps for fast averaging.
  const idToTile = new Map()
  const predecessors = new Map()
  const successors = new Map()

  for (const column of map.columns) {
    for (const tile of column) {
      idToTile.set(tile.id, tile)
      predecessors.set(tile.id, [])
      successors.set(tile.id, [])
    }
  }

  for (let col = 0; col < columnCount - 1; col++) {
    for (const tile of map.columns[col]) {
      for (const nextId of tile.connections) {
        successors.get(tile.id).push(nextId)
        predecessors.get(nextId).push(tile.id)
      }
    }
  }

  const averageY = (ids) => {
    if (ids.length === 0) return null
    let sum = 0
    for (const id of ids) sum += idToTile.get(id).y
    return sum / ids.length
  }

  // Relax positions back and forth a few times.
  for (let iter = 0; iter < 3; iter++) {
    // Left to right: align with predecessors.
    for (let col = 1; col < columnCount; col++) {
      const column = map.columns[col]
      const desiredYs = column.map(tile => averageY(predecessors.get(tile.id)) ?? tile.y)
      const placed = placeNodes(desiredYs, LAYOUT.minSpacing, LAYOUT.minY, LAYOUT.maxY)
      column.forEach((tile, i) => { tile.y = placed[i] })
    }

    // Right to left: align with successors.
    for (let col = columnCount - 2; col >= 0; col--) {
      const column = map.columns[col]
      const desiredYs = column.map(tile => averageY(successors.get(tile.id)) ?? tile.y)
      const placed = placeNodes(desiredYs, LAYOUT.minSpacing, LAYOUT.minY, LAYOUT.maxY)
      column.forEach((tile, i) => { tile.y = placed[i] })
    }
  }
}

function placeNodes(desiredYs, minSpacing, minY, maxY) {
  const ys = [...desiredYs]
  const n = ys.length
  if (n === 0) return ys

  // Resolve overlaps by spreading nodes symmetrically around their midpoints.
  for (let iter = 0; iter < 20; iter++) {
    let moved = false
    for (let i = 1; i < n; i++) {
      if (ys[i] - ys[i - 1] < minSpacing) {
        const mid = (ys[i] + ys[i - 1]) / 2
        ys[i - 1] = mid - minSpacing / 2
        ys[i] = mid + minSpacing / 2
        moved = true
      }
    }
    if (!moved) break
  }

  // Shift the whole group back inside the bounds if it overflowed.
  if (ys[0] < minY) {
    const shift = minY - ys[0]
    for (let i = 0; i < n; i++) ys[i] += shift
  }
  if (ys[n - 1] > maxY) {
    const shift = ys[n - 1] - maxY
    for (let i = 0; i < n; i++) ys[i] -= shift
  }

  return ys
}

function getTileCountForColumn(col, definition) {
  const constants = definition.constants || {}
  const homeColumn = constants.homeColumn ?? DEFAULT_HOME_COLUMN
  const bossColumn = constants.bossColumn ?? DEFAULT_BOSS_COLUMN
  if (col === homeColumn || col === bossColumn) return 1

  const layout = definition.layout || {}
  const colConfig = (definition.columns || [])[col] || {}

  if (colConfig.tileCount) {
    return randomInt(colConfig.tileCount.min, colConfig.tileCount.max)
  }

  // Column 1 is fed only by the home tile, which is capped at 3 paths.
  if (col === 1 && layout.column1TileCount) {
    return randomInt(layout.column1TileCount.min, layout.column1TileCount.max)
  }

  const defaultCount = layout.defaultTileCount || { min: 2, max: 5 }
  return randomInt(defaultCount.min, defaultCount.max)
}

function getTypePool(col, definition) {
  const constants = definition.constants || {}
  const homeColumn = constants.homeColumn ?? DEFAULT_HOME_COLUMN
  const bossColumn = constants.bossColumn ?? DEFAULT_BOSS_COLUMN
  const restColumn = constants.restColumn

  if (col === homeColumn || col === bossColumn) return null

  const colConfig = (definition.columns || [])[col] || {}

  // Explicit fixed type wins over everything else.
  if (colConfig.fixedType) {
    return { [colConfig.fixedType]: 1 }
  }

  // Backwards-compatible rest column forcing if the JSON omits fixedType.
  if (col === restColumn) {
    return { [TILE_TYPES.REST_CAMP]: 1 }
  }

  if (colConfig.weights) {
    return normalizeWeights(colConfig.weights)
  }

  return { [TILE_TYPES.BATTLE]: 1 }
}

function normalizeWeights(weights) {
  const total = Object.values(weights).reduce((sum, w) => sum + w, 0)
  if (total <= 0) return weights

  const normalized = {}
  for (const [type, weight] of Object.entries(weights)) {
    normalized[type] = weight / total
  }
  return normalized
}

function pickWeightedType(pool) {
  const total = Object.values(pool).reduce((sum, w) => sum + w, 0)
  let roll = Math.random() * total
  for (const [type, weight] of Object.entries(pool)) {
    roll -= weight
    if (roll <= 0) return type
  }
  return TILE_TYPES.BATTLE
}

// Types that may appear at most once on any path from column 0 to the boss.
const ONCE_PER_PATH_TYPES = [TILE_TYPES.MEMORY, TILE_TYPES.SHORT_CASCADE]
const MINI_BOSS = TILE_TYPES.MINI_BOSS
// Maximum mini-boss fights allowed on a single path.
const MAX_MINI_BOSSES_PER_PATH = 2

/**
 * Re-type tiles so path constraints hold. The map is a left-to-right DAG, so
 * every constraint is checked against already-finalized predecessor columns.
 *
 * Constraints:
 *  - memory / short_cascade: at most one of each on any path (ancestor rule).
 *  - mini_boss: at most MAX_MINI_BOSSES_PER_PATH on any path, and two
 *    mini-bosses on a path must be separated by a non-battle tile (a chain of
 *    battle tiles does not count as a separator).
 * Violating tiles are re-rolled from their column pool with the forbidden
 * types removed (battle as ultimate fallback).
 */
function enforceOncePerPath(columns, definition) {
  const predecessors = new Map()
  for (const column of columns) {
    for (const tile of column) {
      for (const nextId of tile.connections) {
        if (!predecessors.has(nextId)) predecessors.set(nextId, [])
        predecessors.get(nextId).push(tile)
      }
    }
  }

  const hasAncestorOfType = (tile, type) => {
    const seen = new Set()
    const stack = [...(predecessors.get(tile.id) || [])]
    while (stack.length > 0) {
      const cur = stack.pop()
      if (seen.has(cur.id)) continue
      seen.add(cur.id)
      if (cur.type === type) return true
      stack.push(...(predecessors.get(cur.id) || []))
    }
    return false
  }

  const predsOf = tile => predecessors.get(tile.id) || []

  // Per-tile DP state, keyed by tile id. Filled left-to-right; predecessors
  // always belong to earlier columns, so their values are final when read.
  // maxMiniBosses: maximum mini-boss count on any path home -> tile (inclusive).
  // battleChain: tile is a mini-boss, or a battle tile reachable from a
  //   mini-boss through battle tiles only (i.e. "no valid separator yet").
  const maxMiniBosses = new Map()
  const battleChain = new Map()

  const rerollWithout = (tile, col, colConfig, forbiddenTypes) => {
    const pool = getTypePool(col, definition) || { [TILE_TYPES.BATTLE]: 1 }
    const filtered = Object.fromEntries(
      Object.entries(pool).filter(([type]) => !forbiddenTypes.includes(type))
    )
    tile.type = pickWeightedType(
      Object.keys(filtered).length > 0 ? filtered : { [TILE_TYPES.BATTLE]: 1 }
    )
    attachEnemyPool(tile, definition, colConfig)
  }

  for (let col = 0; col < columns.length; col++) {
    const colConfig = (definition.columns || [])[col] || {}
    for (const tile of columns[col]) {
      // 1 + 2. Constraint checks, looping with an accumulating forbidden set.
      // A re-roll for one constraint can pick a type that violates the other
      // (e.g. a demoted memory re-rolling into mini_boss), so each violated
      // type is permanently removed from the pool for this tile. The set only
      // grows and the pool re-roll never picks a forbidden type, so this
      // terminates in at most one re-roll per restricted type.
      const forbidden = new Set()
      let guard = 0
      while (guard++ < 8) {
        let violated = null
        if (tile.type === MINI_BOSS) {
          const preds = predsOf(tile)
          const maxPredCount = Math.max(0, ...preds.map(p => maxMiniBosses.get(p.id) || 0))
          const tooClose = preds.some(p => battleChain.get(p.id))
          if (maxPredCount >= MAX_MINI_BOSSES_PER_PATH || tooClose) violated = MINI_BOSS
        } else if (ONCE_PER_PATH_TYPES.includes(tile.type)) {
          const conflicted = ONCE_PER_PATH_TYPES.filter(t => hasAncestorOfType(tile, t))
          if (conflicted.includes(tile.type)) violated = tile.type
        }
        if (!violated) break
        forbidden.add(violated)
        rerollWithout(tile, col, colConfig, [...forbidden])
      }

      // 3. Record DP state for this tile's final type.
      const preds = predsOf(tile)
      const predMax = Math.max(0, ...preds.map(p => maxMiniBosses.get(p.id) || 0))
      maxMiniBosses.set(tile.id, predMax + (tile.type === MINI_BOSS ? 1 : 0))
      battleChain.set(
        tile.id,
        tile.type === MINI_BOSS ||
          (isBattleTile(tile.type) && preds.some(p => battleChain.get(p.id)))
      )
    }
  }
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min
}

/**
 * Update reachability flags based on the current tile.
 */
export function updateReachability(map, currentTileId) {
  const current = findTileById(map, currentTileId)
  if (!current) return

  for (const column of map.columns) {
    for (const tile of column) {
      tile.reachable = false
    }
  }

  current.reachable = true
  for (const nextId of current.connections) {
    const next = findTileById(map, nextId)
    if (next) next.reachable = true
  }
}

export function findTile(map, predicateOrId) {
  if (typeof predicateOrId === 'function') {
    for (const column of map.columns) {
      const found = column.find(predicateOrId)
      if (found) return found
    }
    return null
  }
  return findTileById(map, predicateOrId)
}

export function findTileById(map, tileId) {
  for (const column of map.columns) {
    const found = column.find(t => t.id === tileId)
    if (found) return found
  }
  return null
}
