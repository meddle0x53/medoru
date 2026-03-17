// Auto-dismiss hook for feedback toasts
// Automatically clears feedback after 3 seconds
const AutoDismiss = {
  mounted() {
    this.timeout = setTimeout(() => {
      this.pushEvent("clear_feedback", {})
    }, 1000)
  },

  destroyed() {
    // Clear the timeout if the element is removed
    // This prevents the event from firing after user navigates to next question
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}

export default AutoDismiss
