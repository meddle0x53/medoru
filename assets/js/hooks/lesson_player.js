const LessonPlayer = {
  mounted() {
    this.isFullscreen = false

    // Keyboard navigation
    this.handleKeyDown = (e) => {
      const activeElement = document.activeElement
      const isTyping =
        activeElement && (
          activeElement.tagName === "INPUT" ||
          activeElement.tagName === "TEXTAREA" ||
          activeElement.isContentEditable
        )

      if (isTyping) return

      if (e.key === "ArrowLeft") {
        e.preventDefault()
        this.pushEvent("prev", {})
      } else if (e.key === "ArrowRight") {
        e.preventDefault()
        this.pushEvent("next", {})
      } else if (e.key === "p" || e.key === "P") {
        e.preventDefault()
        this.pushEvent("toggle_presentation", {})
      }
    }

    window.addEventListener("keydown", this.handleKeyDown)

    // Fullscreen change detection
    this.handleFullscreenChange = () => {
      this.isFullscreen = !!document.fullscreenElement
      if (!this.isFullscreen) {
        this.el.classList.remove("presentation-active")
        this.pushEvent("presentation_exited", {})
      }
    }

    document.addEventListener("fullscreenchange", this.handleFullscreenChange)

    // LiveView events
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
    window.removeEventListener("keydown", this.handleKeyDown)
    document.removeEventListener("fullscreenchange", this.handleFullscreenChange)
    this.exitFullscreen()
  },

  enterFullscreen() {
    const el = this.el
    if (el.requestFullscreen) {
      el.requestFullscreen().catch(() => {})
    } else if (el.webkitRequestFullscreen) {
      el.webkitRequestFullscreen()
    }
  },

  exitFullscreen() {
    if (document.exitFullscreen && document.fullscreenElement) {
      document.exitFullscreen()
    } else if (document.webkitExitFullscreen && document.webkitFullscreenElement) {
      document.webkitExitFullscreen()
    }
  },
}

export default LessonPlayer
