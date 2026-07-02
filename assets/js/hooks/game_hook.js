const PHASER_URL = '/assets/js/phaser.min.js'
const PHASER_FALLBACK = 'https://cdn.jsdelivr.net/npm/phaser@4.1.0/dist/phaser.min.js'

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = src
    script.async = true
    script.onload = () => resolve()
    script.onerror = () => reject(new Error(`Failed to load ${src}`))
    document.body.appendChild(script)
  })
}

const GameHook = {
  mounted() {
    this.fullscreenHandler = () => {
      window.game?.scale?.refresh?.()
    }
    document.addEventListener('fullscreenchange', this.fullscreenHandler)

    const el = this.el
    try {
      window.gameData = JSON.parse(el.dataset.gameData || '{}')
    } catch (e) {
      console.error('[GameHook] Failed to parse game data:', e)
      window.gameData = {}
    }

    this.startIfReady()
  },

  startIfReady() {
    if (window.Phaser && window.startTheHollowOuroboros) {
      this.destroyExisting()
      window.startTheHollowOuroboros()
      return
    }

    if (!window.Phaser) {
      loadScript(PHASER_URL)
        .then(() => this.startIfReady())
        .catch(() => {
          console.warn('[GameHook] Failed to load local Phaser, trying CDN fallback')
          loadScript(PHASER_FALLBACK)
            .then(() => this.startIfReady())
            .catch(err => console.error('[GameHook] Failed to load Phaser:', err))
        })
      return
    }

    if (!window.startTheHollowOuroboros) {
      const url = this.el.dataset.gameScriptUrl || '/assets/js/game.js'
      loadScript(url)
        .then(() => this.startIfReady())
        .catch(err => console.error('[GameHook] Failed to load game.js:', err))
    }
  },

  destroyExisting() {
    if (window.game) {
      try {
        window.game.destroy(true)
      } catch (e) {
        console.warn('[GameHook] Error destroying previous game:', e)
      }
      window.game = null
    }
  },

  destroyed() {
    this.destroyExisting()
    if (this.fullscreenHandler) {
      document.removeEventListener('fullscreenchange', this.fullscreenHandler)
      this.fullscreenHandler = null
    }
  },
}

export default GameHook
