/**
 * Timer hook for countdown functionality in tests.
 * Handles countdown client-side to avoid re-rendering the form.
 * Only sends events to server when time is up or periodically for sync.
 */
export default {
  mounted() {
    this.timeRemaining = parseInt(this.el.dataset.timeRemaining) || 0
    this.syncInterval = parseInt(this.el.dataset.syncInterval) || 10 // Sync every 10 seconds
    this.tickCount = 0

    // Update display immediately
    this.updateDisplay()

    // Start countdown
    this.timer = setInterval(() => {
      this.timeRemaining--
      this.tickCount++

      // Update display directly (no server round-trip)
      this.updateDisplay()

      // Check if time is up
      if (this.timeRemaining <= 0) {
        this.pushEvent("time_up", {})
        clearInterval(this.timer)
        return
      }

      // Sync with server periodically (every N seconds)
      if (this.tickCount >= this.syncInterval) {
        this.tickCount = 0
        this.pushEvent("sync_time", {time_remaining: this.timeRemaining})
      }
    }, 1000)
  },

  updateDisplay() {
    // Format time as MM:SS
    const mins = Math.floor(this.timeRemaining / 60)
    const secs = this.timeRemaining % 60
    const formatted = `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`

    // Find the timer display element and update it directly
    const timerDisplay = document.getElementById('timer-display')
    if (timerDisplay) {
      timerDisplay.textContent = formatted

      // Update color based on time remaining
      timerDisplay.classList.remove('text-error', 'text-warning', 'text-base-content')
      if (this.timeRemaining < 60) {
        timerDisplay.classList.add('text-error')
      } else if (this.timeRemaining < 300) {
        timerDisplay.classList.add('text-warning')
      } else {
        timerDisplay.classList.add('text-base-content')
      }
    }
  },

  destroyed() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }
}
