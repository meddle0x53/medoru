const ClassroomChatScroll = {
  mounted() {
    this.scrollToBottom()

    this.handleEvent("scroll_to_bottom", () => {
      this.scrollToBottom()
    })
  },

  updated() {
    // Only auto-scroll if we're already near the bottom
    const threshold = 150
    const distanceFromBottom = this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight
    if (distanceFromBottom < threshold) {
      this.scrollToBottom()
    }
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

export default ClassroomChatScroll
