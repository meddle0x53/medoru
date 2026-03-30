// Auto-dismiss hook for feedback toasts and flash messages
// Configurable via data attributes:
//   data-timeout: milliseconds to wait before dismissing (default: 1000)
//   data-event: event to send (default: "clear_feedback")
const AutoDismiss = {
  mounted() {
    // Get configuration from data attributes
    const timeout = parseInt(this.el.dataset.timeout || "1000", 10)
    const eventName = this.el.dataset.event || "clear_feedback"

    this.timeout = setTimeout(() => {
      this.pushEvent(eventName, {})
    }, timeout)
  },

  destroyed() {
    // Clear the timeout if the element is removed
    // This prevents the event from firing after user navigates away
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}

export default AutoDismiss
