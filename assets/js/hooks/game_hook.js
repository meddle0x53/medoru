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

function perfNow() {
  return performance.now()
}

function perfLog(label, detail = null) {
  const elapsed = window.__gamePerfStart ? Math.round(perfNow() - window.__gamePerfStart) : null
  const prefix = `[GamePerf] ${label}`
  if (elapsed !== null) {
    console.log(prefix, { elapsedMs: elapsed, ...(detail || {}) })
  } else {
    console.log(prefix, detail || '')
  }
}

function logCacheSummary() {
  if (!('caches' in window)) return
  caches.keys().then((names) => {
    return Promise.all(
      names.map(async (name) => {
        const cache = await caches.open(name)
        const requests = await cache.keys()
        let size = 0
        for (const req of requests) {
          const resp = await cache.match(req)
          if (resp && resp.headers) {
            const contentLength = resp.headers.get('content-length')
            if (contentLength) {
              size += parseInt(contentLength, 10) || 0
            } else {
              const blob = await resp.blob()
              size += blob.size
            }
          }
        }
        return { cache: name, entries: requests.length, sizeBytes: size, sizeMb: (size / 1024 / 1024).toFixed(2) }
      })
    )
  }).then((rows) => {
    console.log('[GamePerf] Service Worker cache summary')
    console.table(rows)
  }).catch((err) => {
    console.warn('[GamePerf] Could not inspect caches:', err)
  })
}

function logServiceWorkerState() {
  if (!('serviceWorker' in navigator)) {
    perfLog('Service Worker not supported')
    return
  }
  navigator.serviceWorker.ready.then((reg) => {
    perfLog('Service Worker state', {
      controller: navigator.serviceWorker.controller?.scriptURL || null,
      state: reg.active?.state || null,
      scope: reg.scope,
    })
  })
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

    // If the active run was already started as a daily challenge, the player
    // is just reloading the page. Preserve their progress instead of wiping it.
    if (loadout.dailyRunActive) return

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
    window.__gamePerfStart = perfNow()
    perfLog('GameHook mounted')
    logServiceWorkerState()

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
    const rawData = el.dataset.gameData || '{}'
    perfLog('Game data attribute size', { bytes: rawData.length })
    const parseStart = perfNow()
    try {
      window.gameData = JSON.parse(rawData)
    } catch (e) {
      console.error('[GameHook] Failed to parse game data:', e)
      window.gameData = {}
    }
    perfLog('Game data parsed', { durationMs: Math.round(perfNow() - parseStart) })

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
      perfLog('Starting Phaser game')
      this.destroyExisting()
      const gameStart = perfNow()
      window.startTheHollowOuroboros()
      perfLog('Phaser Game created', { durationMs: Math.round(perfNow() - gameStart) })
      this.hideLoadingOverlay()
      perfLog('Loading overlay removed')
      setTimeout(logCacheSummary, 500)
      return
    }

    if (!window.Phaser) {
      perfLog('Loading Phaser script', { url: PHASER_URL })
      const phaserStart = perfNow()
      loadScript(PHASER_URL)
        .then(() => {
          perfLog('Phaser script loaded', { durationMs: Math.round(perfNow() - phaserStart) })
          this.startIfReady()
        })
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
      perfLog('Loading game.js', { url })
      const gameJsStart = perfNow()
      loadScript(url)
        .then(() => {
          perfLog('game.js loaded', { durationMs: Math.round(perfNow() - gameJsStart) })
          this.startIfReady()
        })
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
