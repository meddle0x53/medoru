/**
 * Plays a soft notification sound when a chat message arrives.
 * Uses the Web Audio API — no external sound files needed.
 */
const NotificationSound = {
  mounted() {
    this.handleEvent("play_sound", () => {
      try {
        const AudioContext = window.AudioContext || window.webkitAudioContext
        if (!AudioContext) return

        const ctx = new AudioContext()
        if (ctx.state === "suspended") {
          ctx.resume()
        }

        const osc = ctx.createOscillator()
        const gain = ctx.createGain()
        osc.connect(gain)
        gain.connect(ctx.destination)

        // Alerting three-tone chime: G5 → C6 → E6
        osc.type = "sine"
        osc.frequency.setValueAtTime(783.99, ctx.currentTime)
        osc.frequency.setValueAtTime(1046.5, ctx.currentTime + 0.08)
        osc.frequency.setValueAtTime(1318.51, ctx.currentTime + 0.16)

        gain.gain.setValueAtTime(0.3, ctx.currentTime)
        gain.gain.setValueAtTime(0.25, ctx.currentTime + 0.08)
        gain.gain.setValueAtTime(0.2, ctx.currentTime + 0.16)
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.4)

        osc.start()
        osc.stop(ctx.currentTime + 0.4)
      } catch (_e) {
        // Silently fail if audio is blocked
      }
    })
  }
}

export default NotificationSound
