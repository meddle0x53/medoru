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

function isMobile() {
  return (
    window.matchMedia('(pointer: coarse)').matches ||
    'ontouchstart' in window ||
    /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
  )
}

function tryEnterFullscreen() {
  if (!isMobile() || document.fullscreenElement) return
  const wrapper = document.getElementById('game-wrapper')
  if (!wrapper) return
  if (wrapper.requestFullscreen) {
    wrapper.requestFullscreen().catch(() => {})
  } else if (wrapper.webkitRequestFullscreen) {
    wrapper.webkitRequestFullscreen()
  }
}

function gameLoadoutKey() {
  return window.gameData?.devMode ? 'medoru_loadout_v1' : 'medoru_loadout_public_v1'
}

function abandonActiveDailyRun() {
  try {
    const key = gameLoadoutKey()
    const raw = localStorage.getItem(key)
    if (!raw) return

    const loadout = JSON.parse(raw)
    const map = loadout.mapState?.maps?.[loadout.mapState?.currentMapIndex]
    if (!map) return

    // Daily challenge runs must start fresh: wipe the in-progress map and
    // any run-scoped learning state so the player cannot continue an old run.
    loadout.mapState = null
    loadout.beingLearnedWords = []
    loadout.focusKanji = null
    loadout.focusKanjiData = null
    localStorage.setItem(key, JSON.stringify(loadout))
  } catch (e) {
    console.warn('[GameHook] Failed to abandon active daily run:', e)
  }
}

const GameHook = {
  mounted() {
    this.fullscreenHandler = () => {
      window.game?.scale?.refresh?.()
    }
    document.addEventListener('fullscreenchange', this.fullscreenHandler)

    // Lock the viewport on mobile so double-tap zoom doesn't break the game.
    this.viewportMeta = document.querySelector('meta[name="viewport"]')
    if (this.viewportMeta) {
      this.originalViewport = this.viewportMeta.getAttribute('content')
      this.viewportMeta.setAttribute(
        'content',
        'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no',
      )
    }

    // Auto-enter fullscreen on the first user interaction on touch devices.
    this.firstInteractionHandler = () => {
      tryEnterFullscreen()
    }
    document.addEventListener('pointerdown', this.firstInteractionHandler, { once: true })

    const el = this.el
    try {
      window.gameData = JSON.parse(el.dataset.gameData || '{}')
    } catch (e) {
      console.error('[GameHook] Failed to parse game data:', e)
      window.gameData = {}
    }

    window.gameData.devMode = el.dataset.devMode === 'true'
    window.gameData.dailyChallengeMode = el.dataset.dailyChallengeMode === 'true'

    if (window.gameData.dailyChallengeMode) {
      abandonActiveDailyRun()
    }

    this.startIfReady()
  },

  hideLoadingOverlay() {
    const overlay = document.getElementById('game-loading-overlay')
    if (overlay) overlay.remove()
  },

  startIfReady() {
    if (window.Phaser && window.startTheHollowOuroboros) {
      this.destroyExisting()
      window.startTheHollowOuroboros()
      this.hideLoadingOverlay()
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
    if (this.firstInteractionHandler) {
      document.removeEventListener('pointerdown', this.firstInteractionHandler)
      this.firstInteractionHandler = null
    }
    if (this.viewportMeta && this.originalViewport) {
      this.viewportMeta.setAttribute('content', this.originalViewport)
      this.viewportMeta = null
    }
  },
}

export default GameHook
