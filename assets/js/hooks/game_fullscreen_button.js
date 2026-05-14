const GameFullscreenButton = {
  mounted() {
    this.handleClick = (e) => {
      // iOS Safari / WebKit: attempt to hide the chrome by scrolling.
      // This MUST run synchronously inside the user gesture.
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
      } else {
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
    }

    this.el.addEventListener("click", this.handleClick)
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
  },
}

export default GameFullscreenButton
