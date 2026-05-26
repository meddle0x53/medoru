const GameFullscreenButton = {
  mounted() {
    this.isIOSPWA = window.navigator.standalone === true

    this.handleClick = (e) => {
      // iOS PWA: use CSS immersive mode (no fullscreen API available)
      if (this.isIOSPWA) {
        document.body.classList.add("ios-pwa-immersive")
        window.scrollTo(0, 0)
        return
      }

      // iOS Safari (not PWA): attempt to hide the chrome by scrolling.
      const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent)
      if (isIOS) {
        // Try to collapse the Safari address bar by scrolling down then up.
        // We do this inside a rAF so the browser registers it as part of the gesture.
        requestAnimationFrame(() => {
          window.scrollTo(0, document.body.scrollHeight)
          requestAnimationFrame(() => {
            window.scrollTo(0, 0)
          })
        })
        return
      }

      // For Android / others, try real fullscreen on the game container.
      const container = document.getElementById("kanji-falling-game-container")
      if (container) {
        if (container.requestFullscreen) {
          container.requestFullscreen().catch(() => {})
        } else if (container.webkitRequestFullscreen) {
          container.webkitRequestFullscreen()
        }
      }
    }

    this.el.addEventListener("click", this.handleClick)
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
  },
}

export default GameFullscreenButton
