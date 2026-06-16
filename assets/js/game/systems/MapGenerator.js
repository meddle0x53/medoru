import { GAME_CONFIG } from '../config.js'
import { TILE_TYPES } from '../data/tileTypes.js'

/**
 * Generate a planar layered graph for the rogue-like map.
 *
 * Structure:
 *   - 11 columns (0 = home, 1-9 = intermediate, 10 = boss)
 *   - Column 0 and 10 always have exactly 1 tile
 *   - Columns 1-9 have 2-5 tiles (column 1 capped at 3 because home can only
 *     branch to 1-3 tiles)
 *   - Connections between adjacent columns are non-crossing and each tile
 *     has 1-3 outgoing paths to the next column.
 */

const COLUMN_COUNT = 11
const HOME_COLUMN = 0
const BOSS_COLUMN = 10
const MAX_CONNECTIONS_PER_TILE = 3

const LAYOUT = {
  paddingX: 70,
  minY: 100,
  maxY: 440,
  minSpacing: 60,
}

const MAP_TEMPLATES = {
  0: {
    nameEn: 'Japanese Fields',
    nameJa: '日本の田園風景',
    backgroundImage: 'map_level_1',
  },
  1: {
    nameEn: 'The Dark Path',
    nameJa: '暗黒の道',
    backgroundImage: null,
  },
}

export function getMapName(map, userLevel = 1) {
  if (!map) return ''
  const localized = userLevel >= 10 ? (map.nameJa || map.nameEn) : (map.nameEn || map.nameJa)
  // Backwards compatibility for saves created before the localized-name change.
  return localized || map.name || ''
}

const TYPE_WEIGHTS = {
  early: {
    [TILE_TYPES.BATTLE]: 0.55,
    [TILE_TYPES.EVENT]: 0.15,
    [TILE_TYPES.CHEST]: 0.15,
    [TILE_TYPES.REST_CAMP]: 0.15,
  },
  mid: {
    [TILE_TYPES.BATTLE]: 0.35,
    [TILE_TYPES.MEMORY]: 0.15,
    [TILE_TYPES.EVENT]: 0.1,
    [TILE_TYPES.SHOP]: 0.1,
    [TILE_TYPES.SHORT_CASCADE]: 0.1,
    [TILE_TYPES.CHEST]: 0.1,
    [TILE_TYPES.REST_CAMP]: 0.1,
  },
  late: {
    [TILE_TYPES.BATTLE]: 0.25,
    [TILE_TYPES.MINI_BOSS]: 0.2,
    [TILE_TYPES.MEMORY]: 0.1,
    [TILE_TYPES.EVENT]: 0.1,
    [TILE_TYPES.SHOP]: 0.1,
    [TILE_TYPES.SHORT_CASCADE]: 0.1,
    [TILE_TYPES.CHEST]: 0.05,
    [TILE_TYPES.REST_CAMP]: 0.1,
  },
}

export function generateMap(mapIndex = 0) {
  const columns = []
  let tileCounter = 0

  for (let col = 0; col < COLUMN_COUNT; col++) {
    const tileCount = getTileCountForColumn(col)
    const column = []
    const typePool = getTypePool(col)

    for (let row = 0; row < tileCount; row++) {
      const type = col === HOME_COLUMN
        ? TILE_TYPES.HOME
        : col === BOSS_COLUMN
          ? TILE_TYPES.BOSS
          : pickWeightedType(typePool)

      column.push({
        id: `map-${mapIndex}-tile-${tileCounter++}`,
        col,
        row,
        type,
        completed: false,
        reachable: col === HOME_COLUMN,
        connections: [],
      })
    }

    columns.push(column)
  }

  // Connect columns with non-crossing, capped intervals
  for (let col = 0; col < COLUMN_COUNT - 1; col++) {
    connectColumns(columns[col], columns[col + 1])
  }

  const template = MAP_TEMPLATES[mapIndex] || MAP_TEMPLATES[0]
  const map = {
    id: `map-${mapIndex}`,
    index: mapIndex,
    nameEn: template.nameEn,
    nameJa: template.nameJa,
    backgroundImage: template.backgroundImage,
    columns,
  }

  computeLayout(map)
  return map
}

function connectColumns(sourceColumn, targetColumn) {
  const intervals = buildNonCrossingIntervals(
    sourceColumn.length,
    targetColumn.length,
    MAX_CONNECTIONS_PER_TILE,
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

function getTileCountForColumn(col) {
  if (col === HOME_COLUMN || col === BOSS_COLUMN) return 1
  // Column 1 is fed only by the home tile, which is capped at 3 paths.
  if (col === 1) return randomInt(2, 3)
  return randomInt(2, 5)
}

function getTypePool(col) {
  if (col <= 3) return TYPE_WEIGHTS.early
  if (col <= 6) return TYPE_WEIGHTS.mid
  return TYPE_WEIGHTS.late
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
