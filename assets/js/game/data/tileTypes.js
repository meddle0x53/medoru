/**
 * Map tile types for the rogue-like map scene.
 */

export const TILE_TYPES = {
  HOME: 'home',
  BATTLE: 'battle',
  MEMORY: 'memory',
  EVENT: 'event',
  SHOP: 'shop',
  SHORT_CASCADE: 'short_cascade',
  CHEST: 'chest',
  MINI_BOSS: 'mini_boss',
  BOSS: 'boss',
  REST_CAMP: 'rest_camp',
}

export const TILE_CONFIG = {
  [TILE_TYPES.HOME]: {
    label: 'Home',
    color: 0x3498db,
    textColor: '#ecf0f1',
    isBattle: false,
  },
  [TILE_TYPES.BATTLE]: {
    label: 'Battle',
    color: 0xc0392b,
    textColor: '#ecf0f1',
    isBattle: true,
  },
  [TILE_TYPES.MEMORY]: {
    label: 'Memory',
    color: 0x9b59b6,
    textColor: '#ecf0f1',
    isBattle: false,
  },
  [TILE_TYPES.EVENT]: {
    label: 'Event',
    color: 0xf39c12,
    textColor: '#ecf0f1',
    isBattle: false,
  },
  [TILE_TYPES.SHOP]: {
    label: 'Shop',
    color: 0x27ae60,
    textColor: '#ecf0f1',
    isBattle: false,
  },
  [TILE_TYPES.SHORT_CASCADE]: {
    label: 'Cascade',
    color: 0x2980b9,
    textColor: '#ecf0f1',
    isBattle: false,
  },
  [TILE_TYPES.CHEST]: {
    label: 'Chest',
    color: 0xe67e22,
    textColor: '#ecf0f1',
    isBattle: false,
  },
  [TILE_TYPES.MINI_BOSS]: {
    label: 'Mini Boss',
    color: 0x8e44ad,
    textColor: '#ecf0f1',
    isBattle: true,
  },
  [TILE_TYPES.BOSS]: {
    label: 'Boss',
    color: 0xe74c3c,
    textColor: '#ecf0f1',
    isBattle: true,
  },
  [TILE_TYPES.REST_CAMP]: {
    label: 'Rest',
    color: 0x2ecc71,
    textColor: '#ecf0f1',
    isBattle: false,
  },
}

export function getTileConfig(type) {
  return TILE_CONFIG[type] || TILE_CONFIG[TILE_TYPES.EVENT]
}

export function isBattleTile(type) {
  return getTileConfig(type).isBattle
}
