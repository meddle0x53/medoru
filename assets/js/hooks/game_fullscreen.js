const GameFullscreen = {
  mounted() {
    this.isFullscreen = false

    // Detect mobile/touch devices
    const isMobile = window.matchMedia("(pointer: coarse)").matches ||
                     "ontouchstart" in window ||
                     /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)

    this.pushEvent("device_info", { is_mobile: isMobile })

    this.handleFullscreenChange = () => {
      this.isFullscreen = !!document.fullscreenElement
    }

    document.addEventListener("fullscreenchange", this.handleFullscreenChange)

    this.handleEvent("request_fullscreen", () => {
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
  },

  destroyed() {
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
    setTimeout(() => {
      window.scrollTo(0, 1)
    }, 100)
  },
}

export default GameFullscreen
