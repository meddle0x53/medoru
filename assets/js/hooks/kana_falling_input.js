const KanaFallingInput = {
  mounted() {
    // this.el is the element with phx-hook="KanaFallingInput"
    this.isFullscreen = false

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
      this.enterFullscreen()
    })

    this.handleEvent("exit_fullscreen", () => {
      this.exitFullscreen()
    })
  },

  destroyed() {
    window.removeEventListener("keydown", this.handleKeyDown, true)
    document.removeEventListener("fullscreenchange", this.handleFullscreenChange)
    this.exitFullscreen()
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
