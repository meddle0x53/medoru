const ChatAudioPlayer = {
  mounted() {
    this.playBtn = this.el.querySelector(".chat-audio-play")
    this.playIcon = this.el.querySelector(".chat-audio-play-icon")
    this.pauseIcon = this.el.querySelector(".chat-audio-pause-icon")
    this.progressBar = this.el.querySelector(".chat-audio-progress-bar")
    this.progressContainer = this.el.querySelector(".chat-audio-progress")
    this.currentTimeEl = this.el.querySelector(".chat-audio-current")
    this.durationEl = this.el.querySelector(".chat-audio-duration")
    this.audio = this.el.querySelector(".chat-audio-el")

    if (!this.audio) {
      console.error("[ChatAudio] No audio element found")
      return
    }

    this.isPlaying = false
    this.hasLoaded = false
    this.duration = parseInt(this.el.dataset.duration || "0", 10)
    this.pollInterval = null

    // Ensure src is set
    const srcFromData = this.el.dataset.src
    if (srcFromData && !this.audio.src) {
      this.audio.src = srcFromData
    }

    // Update duration display when metadata loads
    this.audio.addEventListener("loadedmetadata", () => {
      if (this.audio.duration && !isNaN(this.audio.duration) && this.audio.duration !== Infinity) {
        this.duration = Math.floor(this.audio.duration)
        this.hasLoaded = true
        if (this.durationEl) {
          this.durationEl.textContent = this.formatTime(this.duration)
        }
      }
    })

    this.audio.addEventListener("canplaythrough", () => {
      if (this.audio.duration && !isNaN(this.audio.duration) && this.audio.duration !== Infinity) {
        this.duration = Math.floor(this.audio.duration)
        this.hasLoaded = true
        if (this.durationEl) {
          this.durationEl.textContent = this.formatTime(this.duration)
        }
      }
    })

    this.audio.addEventListener("durationchange", () => {
      if (this.audio.duration && !isNaN(this.audio.duration) && this.audio.duration !== Infinity) {
        this.duration = Math.floor(this.audio.duration)
        this.hasLoaded = true
        if (this.durationEl) {
          this.durationEl.textContent = this.formatTime(this.duration)
        }
      }
    })

    this.audio.addEventListener("timeupdate", () => {
      this.updateProgress()
    })

    this.audio.addEventListener("ended", () => {
      this.isPlaying = false
      this.stopPolling()
      this.updatePlayIcon()
      if (this.progressBar) this.progressBar.style.width = "0%"
      if (this.currentTimeEl) this.currentTimeEl.textContent = "0:00"
    })

    this.audio.addEventListener("pause", () => {
      this.isPlaying = false
      this.stopPolling()
      this.updatePlayIcon()
    })

    this.audio.addEventListener("play", () => {
      this.isPlaying = true
      this.startPolling()
      this.updatePlayIcon()
    })

    this.audio.addEventListener("error", (e) => {
      console.error("[ChatAudio] Audio error:", e)
      this.isPlaying = false
      this.stopPolling()
      this.updatePlayIcon()
    })

    if (this.playBtn) {
      this.playBtn.addEventListener("click", () => this.togglePlay())
    }

    if (this.progressContainer) {
      this.progressContainer.addEventListener("click", (e) => this.seek(e))
    }

    // Try to load duration immediately if already cached
    if (this.audio.readyState >= 1 && this.audio.duration && !isNaN(this.audio.duration)) {
      this.duration = Math.floor(this.audio.duration)
      this.hasLoaded = true
      if (this.durationEl) {
        this.durationEl.textContent = this.formatTime(this.duration)
      }
    }
  },

  destroyed() {
    this.stopPolling()
    if (this.audio) {
      this.audio.pause()
      this.audio.src = ""
    }
  },

  togglePlay() {
    if (!this.audio) return
    if (this.isPlaying) {
      this.audio.pause()
    } else {
      // Pause all other audio players in this conversation
      document.querySelectorAll(".chat-audio-el").forEach(el => {
        if (el !== this.audio) {
          el.pause()
        }
      })
      this.audio.play().catch(e => {
        console.error("[ChatAudio] Play failed:", e)
        this.isPlaying = false
        this.updatePlayIcon()
      })
    }
  },

  seek(e) {
    if (!this.audio || !this.audio.duration || this.audio.duration === Infinity || !this.hasLoaded) {
      // If not loaded yet, try to seek anyway
      if (!this.audio || !this.audio.duration) return
    }
    const rect = this.progressContainer.getBoundingClientRect()
    const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width))
    this.audio.currentTime = pct * this.audio.duration
    this.updateProgress()
  },

  startPolling() {
    this.stopPolling()
    this.pollInterval = setInterval(() => {
      this.updateProgress()
    }, 100)
  },

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  },

  updateProgress() {
    if (!this.audio) return
    const current = this.audio.currentTime || 0
    const duration = this.audio.duration || 0

    if (duration && !isNaN(duration) && this.progressBar) {
      const pct = Math.min(100, (current / duration) * 100)
      this.progressBar.style.width = pct + "%"
    }
    if (this.currentTimeEl) {
      this.currentTimeEl.textContent = this.formatTime(Math.floor(current))
    }
  },

  updatePlayIcon() {
    if (!this.playIcon || !this.pauseIcon) return
    if (this.isPlaying) {
      this.playIcon.classList.add("hidden")
      this.pauseIcon.classList.remove("hidden")
    } else {
      this.playIcon.classList.remove("hidden")
      this.pauseIcon.classList.add("hidden")
    }
  },

  formatTime(seconds) {
    if (!seconds || seconds < 0) return "0:00"
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m}:${String(s).padStart(2, "0")}`
  }
}

export default ChatAudioPlayer
