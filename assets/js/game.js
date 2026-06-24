/**
 * Kill Medoru! - Game Entry Point
 * Rogue-like RPG battle system using Phaser 3.
 */
import { GAME_CONFIG } from './game/config.js'
import BootScene from './game/scenes/BootScene.js'
import MapScene from './game/scenes/MapScene.js'
import LoadoutScene from './game/scenes/LoadoutScene.js'
import BattleScene from './game/scenes/BattleScene.js'
import MemoryScene from './game/scenes/MemoryScene.js'
import ShopScene from './game/scenes/ShopScene.js'
import RestScene from './game/scenes/RestScene.js'
import SocketScene from './game/scenes/SocketScene.js'
import WinScene from './game/scenes/WinScene.js'

function startGame() {
  const container = document.getElementById('game-container')
  if (!container) {
    console.error('[Kill Medoru!] #game-container not found')
    return
  }

  const Phaser = window.Phaser
  if (!Phaser) {
    console.error('[Kill Medoru!] Phaser not loaded. Make sure phaser.min.js is loaded before game.js')
    return
  }

  console.log('[Kill Medoru!] Starting game...', { gameData: window.gameData })

  const config = {
    type: Phaser.AUTO,
    width: GAME_CONFIG.width,
    height: GAME_CONFIG.height,
    parent: 'game-container',
    backgroundColor: GAME_CONFIG.backgroundColor,
    scale: {
      mode: Phaser.Scale.FIT,
      autoCenter: Phaser.Scale.CENTER_BOTH,
    },
    scene: [BootScene, MapScene, LoadoutScene, BattleScene, MemoryScene, ShopScene, RestScene, SocketScene, WinScene],
    physics: {
      default: 'arcade',
      arcade: {
        gravity: { y: 0 },
        debug: false,
      },
    },
  }

  try {
    new Phaser.Game(config)
    console.log('[Kill Medoru!] Phaser initialized')
  } catch (err) {
    console.error('[Kill Medoru!] Phaser failed to start:', err)
  }
}

// Start when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', startGame)
} else {
  startGame()
}
