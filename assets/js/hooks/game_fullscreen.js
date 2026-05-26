const GameFullscreen = {
  mounted() {
    this.isFullscreen = false

    // Detect mobile/touch devices
    const isMobile = window.matchMedia("(pointer: coarse)").matches ||
                     "ontouchstart" in window ||
                     /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)

    // Detect iOS PWA standalone mode (no fullscreen API available)
    this.isIOSPWA = window.navigator.standalone === true

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

    // Restore original viewport
    if (this.viewportMeta && this.originalViewport) {
      this.viewportMeta.setAttribute("content", this.originalViewport)
    }
  },

  enterFullscreen() {
    if (this.isIOSPWA) {
      document.body.classList.add("ios-pwa-immersive")
      window.scrollTo(0, 0)
      return
    }

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
    if (this.isIOSPWA) {
      document.body.classList.remove("ios-pwa-immersive")
      return
    }

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
