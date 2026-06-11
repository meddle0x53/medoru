// Hero battle pose definitions.
// Each pose maps a logical pose key to a sprite texture key and an (x, y) offset.
// Offsets are applied in *addition* to the sprite origin so the feet stay on the
// same ground baseline across all AI-generated sprites without re-cropping.
//
// Example offsets you can tune per-sprite:
//   x > 0 → shift sprite right
//   y > 0 → shift sprite down
//
// When you crop the new master sprite sheet, drop the individual PNGs into
// /priv/static/images/game/ with names like hero_idle.png, hero_slash_01.png,
// then load them in BootScene and point `textureKey` here.

export const HERO_SPRITE_OFFSETS = {
  // Stances / movement
  idle:             { textureKey: 'player_sword_shield',  x: 0,  y: 0 },
  walk:             { textureKey: 'player_sword_shield',  x: 0,  y: 0 },
  run:              { textureKey: 'player_sword_shield',  x: 0,  y: 0 },

  // Attacks (sword)
  slash_light_01:   { textureKey: 'player_sword_slash',   x: 0,  y: 0 },
  slash_light_02:   { textureKey: 'player_sword_slash',   x: 0,  y: 0 },
  slash_heavy:      { textureKey: 'player_heavy_slash',   x: 0,  y: -50 },
  thrust:           { textureKey: 'player_sword_slash',   x: 0,  y: 0 },

  // Defence
  block_idle:       { textureKey: 'player_shield_block',  x: 0,  y: 0 },
  block_impact:     { textureKey: 'player_shield_block',  x: 0,  y: 0 },
  parry:            { textureKey: 'player_shield_block',  x: 0,  y: 0 },

  // Damage / defeat
  hit:              { textureKey: 'player_shield_block',  x: 0,  y: 0 },
  defeated:         { textureKey: 'player_defeated',      x: 0,  y: 0 },

  // Misc
  use_item:         { textureKey: 'player_sword_shield',  x: 0,  y: 0 },
  channel:          { textureKey: 'player_sword_shield',  x: 0,  y: 0 },
}

// Default pose used when nothing is specified.
export const HERO_DEFAULT_POSE = 'idle'

export function getHeroPose(poseKey) {
  return HERO_SPRITE_OFFSETS[poseKey] || HERO_SPRITE_OFFSETS[HERO_DEFAULT_POSE]
}

export function listHeroPoseKeys() {
  return Object.keys(HERO_SPRITE_OFFSETS)
}
