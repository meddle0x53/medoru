const PreviewOverlay = {
  mounted() {
    // Scroll the preview body to the bottom so the newest content is visible
    const body = this.el.querySelector(".preview-body")
    if (body) {
      body.scrollTop = body.scrollHeight
    }

    // Ensure the text input is visible and focused
    const input =
      document.getElementById("chat-message-input") ||
      document.getElementById("classroom-chat-textarea")
    if (input) {
      input.scrollIntoView({ behavior: "smooth", block: "end" })
      setTimeout(() => input.focus(), 50)
    }
  }
}

export default PreviewOverlay
