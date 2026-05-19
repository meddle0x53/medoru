const LessonNavigation = {
  mounted() {
    this.handleKeyDown = (e) => {
      // Ignore if user is typing in an input, textarea, or contenteditable
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
      }
    }

    window.addEventListener("keydown", this.handleKeyDown)
  },

  destroyed() {
    window.removeEventListener("keydown", this.handleKeyDown)
  },
}

export default LessonNavigation
