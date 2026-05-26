const PresentationMode = {
  mounted() {
    this.isFullscreen = false
    this.isIOSPWA = window.navigator.standalone === true

    this.handleFullscreenChange = () => {
      this.isFullscreen = !!document.fullscreenElement
      if (!this.isFullscreen) {
        this.el.classList.remove("presentation-active")
      }
    }

    document.addEventListener("fullscreenchange", this.handleFullscreenChange)

    this.handleEvent("enter_presentation", () => {
      this.el.classList.add("presentation-active")
      this.enterFullscreen()
    })

    this.handleEvent("exit_presentation", () => {
      this.el.classList.remove("presentation-active")
      this.exitFullscreen()
    })
  },

  destroyed() {
    document.removeEventListener("fullscreenchange", this.handleFullscreenChange)
    this.exitFullscreen()
  },

  enterFullscreen() {
    if (this.isIOSPWA) {
      document.body.classList.add("ios-pwa-immersive")
      window.scrollTo(0, 0)
      return
    }

    const el = this.el
    if (el.requestFullscreen) {
      el.requestFullscreen().catch(() => {})
    } else if (el.webkitRequestFullscreen) {
      el.webkitRequestFullscreen()
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
}

export default PresentationMode
