const KanaFallingInput = {
  mounted() {
    // this.el is the element with phx-hook="KanaFallingInput"
    this.isFullscreen = false

    // Detect mobile/touch devices
    const isMobile = window.matchMedia("(pointer: coarse)").matches ||
                     "ontouchstart" in window ||
                     /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)

    this.pushEvent("device_info", { is_mobile: isMobile })

    // Prevent iOS zoom on game pages by locking the viewport
    this.viewportMeta = document.querySelector('meta[name="viewport"]')
    if (this.viewportMeta) {
      this.originalViewport = this.viewportMeta.getAttribute("content")
      this.viewportMeta.setAttribute(
        "content",
        "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"
      )
    }

    this.handleKeyDown = (e) => {
      if (!this.el) return

      e.preventDefault()

      if (e.ctrlKey || e.altKey || e.metaKey) {
        e.stopPropagation()
      }
    }

    this.handleFullscreenChange = () => {
      this.isFullscreen = !!document.fullscreenElement
    }

    window.addEventListener("keydown", this.handleKeyDown, true)
    document.addEventListener("fullscreenchange", this.handleFullscreenChange)

    this.handleEvent("request_fullscreen", () => {
      // Only auto-fullscreen on mobile devices
      if (isMobile) {
        this.enterFullscreen()
      }
    })

    this.handleEvent("force_fullscreen", () => {
      this.enterFullscreen()
    })

    this.handleEvent("exit_fullscreen", () => {
      this.exitFullscreen()
    })

    this.handleEvent("kana_destroyed", ({ char, row }) => {
      this.showExplosion(char, row)
    })
  },

  showExplosion(char, row) {
    const gameField = this.el.querySelector("[data-game-field]") || this.el
    if (!gameField) return

    const explosion = document.createElement("div")
    explosion.className = "kana-explosion"
    explosion.textContent = char
    explosion.style.top = `${(row - 1) * 2.5}%`

    gameField.appendChild(explosion)

    setTimeout(() => {
      if (explosion.parentNode) {
        explosion.parentNode.removeChild(explosion)
      }
    }, 450)
  },

  destroyed() {
    window.removeEventListener("keydown", this.handleKeyDown, true)
    document.removeEventListener("fullscreenchange", this.handleFullscreenChange)
    this.exitFullscreen()

    // Restore original viewport
    if (this.viewportMeta && this.originalViewport) {
      this.viewportMeta.setAttribute("content", this.originalViewport)
    }
  },

  enterFullscreen() {
    const el = this.el || document.documentElement

    if (el.requestFullscreen) {
      el.requestFullscreen().catch(() => {
        this.hideMobileChrome()
      })
    } else if (el.webkitRequestFullscreen) {
      el.webkitRequestFullscreen()
    } else {
      this.hideMobileChrome()
    }
  },

  exitFullscreen() {
    if (document.exitFullscreen && document.fullscreenElement) {
      document.exitFullscreen()
    } else if (document.webkitExitFullscreen && document.webkitFullscreenElement) {
      document.webkitExitFullscreen()
    }
  },

  hideMobileChrome() {
    // Fallback for browsers without fullscreen API (iOS Safari)
    setTimeout(() => {
      window.scrollTo(0, 1)
    }, 100)
  },
}

export default KanaFallingInput
