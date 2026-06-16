/**
 * Ability data loader.
 *
 * All ability definitions live in JSON files under this folder. They are
 * imported at build time, so the game bundle remains fully offline-capable.
 */

import warriorData from './warrior.json'

export const ALL_ABILITIES = [
  ...(warriorData.abilities || []),
]
