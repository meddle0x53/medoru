const LOOPBACK_KEYWORDS = ["mix", "loopback", "virtual", "cable", "stereo", "what u hear", "desktop"]

function isLoopbackDevice(label) {
  const lower = label.toLowerCase()
  return LOOPBACK_KEYWORDS.some(kw => lower.includes(kw))
}

function isMicrophoneDevice(label) {
  const lower = label.toLowerCase()
  return lower.includes("microphone") || lower.includes("mic") || lower.includes("built-in") || lower.includes("internal")
}

function getStorageKey() {
  const userId = document.getElementById("chat-wrapper")?.dataset.currentUserId || "default"
  return `medoru_mic_device_${userId}`
}

const ChatVoiceRecorder = {
  mounted() {
    this.button = this.el.querySelector("#chat-voice-button")
    this.statusEl = this.el.querySelector("#chat-voice-status")
    this.pickerEl = this.el.querySelector("#chat-mic-picker")
    this.pickerListEl = this.el.querySelector("#chat-mic-picker-list")
    this.pickerBtn = this.el.querySelector("#chat-mic-picker-button")

    if (!this.button) return

    this.isRecording = false
    this.mediaRecorder = null
    this.chunks = []
    this.startTime = null
    this.timerInterval = null
    this.selectedDeviceId = localStorage.getItem(getStorageKey()) || null
    this.devices = []

    this.button.addEventListener("click", () => this.toggleRecording())

    if (this.pickerBtn) {
      this.pickerBtn.addEventListener("click", (e) => this.togglePicker(e))
    }

    // Close picker on outside click
    this._outsideClick = (e) => {
      if (this.pickerEl && !this.pickerEl.contains(e.target) && !this.pickerBtn?.contains(e.target)) {
        this.hidePicker()
      }
    }
    document.addEventListener("click", this._outsideClick)

    // Load available microphones on mount (needs permission first)
    this.loadDevices()
  },

  destroyed() {
    if (this._outsideClick) {
      document.removeEventListener("click", this._outsideClick)
    }
    this.stopRecording()
  },

  async loadDevices() {
    try {
      // Request temporary permission to enumerate labeled devices
      const tempStream = await navigator.mediaDevices.getUserMedia({ audio: true })
      tempStream.getTracks().forEach(t => t.stop())

      const allDevices = await navigator.mediaDevices.enumerateDevices()
      this.devices = allDevices.filter(d => d.kind === "audioinput" && d.deviceId && d.deviceId !== "default" && d.deviceId !== "communications")

      // Filter out loopback devices
      const realMics = this.devices.filter(d => !isLoopbackDevice(d.label))

      if (realMics.length === 0) {
        // No real mic found, fallback to all non-loopback
        this.devices = this.devices.filter(d => !isLoopbackDevice(d.label))
      } else {
        this.devices = realMics
      }

      // Auto-select if nothing stored
      if (!this.selectedDeviceId && this.devices.length > 0) {
        // Prefer devices with "microphone" in the name
        const preferred = this.devices.find(d => isMicrophoneDevice(d.label))
        this.selectedDeviceId = preferred ? preferred.deviceId : this.devices[0].deviceId
        localStorage.setItem(getStorageKey(), this.selectedDeviceId)
      }

      // Always render the picker so user can see current selection
      this.renderDevicePicker()

      console.log("[VoiceRecorder] Available mics:", this.devices.map(d => d.label))
    } catch (e) {
      console.error("[VoiceRecorder] Could not enumerate devices:", e)
      this.renderDevicePicker()
    }
  },

  renderDevicePicker() {
    if (!this.pickerListEl) return

    if (this.devices.length === 0) {
      this.pickerListEl.innerHTML = `
        <div class="px-3 py-2 text-sm text-base-content/50">
          No microphones found
        </div>
      `
      return
    }

    this.pickerListEl.innerHTML = this.devices.map(d => {
      const isSelected = d.deviceId === this.selectedDeviceId
      const label = d.label || "Microphone"
      return `<button type="button" data-device-id="${d.deviceId}" class="flex items-center gap-2 px-3 py-2 w-full text-left text-sm hover:bg-base-200 rounded-lg transition-colors ${isSelected ? 'text-primary font-medium' : 'text-base-content'}">
        <span class="w-2 h-2 rounded-full ${isSelected ? 'bg-primary' : 'bg-transparent border border-base-content/30'}"></span>
        <span class="truncate">${label}</span>
      </button>`
    }).join("")

    this.pickerListEl.querySelectorAll("button").forEach(btn => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation()
        this.selectedDeviceId = btn.dataset.deviceId
        localStorage.setItem(getStorageKey(), this.selectedDeviceId)
        this.hidePicker()
        this.renderDevicePicker()
      })
    })
  },

  togglePicker(e) {
    e.stopPropagation()
    if (this.pickerEl) {
      this.pickerEl.classList.toggle("hidden")
    }
  },

  hidePicker() {
    if (this.pickerEl) {
      this.pickerEl.classList.add("hidden")
    }
  },

  async toggleRecording() {
    if (this.isRecording) {
      this.stopRecording()
    } else {
      await this.startRecording()
    }
  },

  async startRecording() {
    try {
      const constraints = {
        audio: this.selectedDeviceId
          ? { deviceId: { exact: this.selectedDeviceId }, echoCancellation: true, noiseSuppression: true }
          : { echoCancellation: true, noiseSuppression: true }
      }

      const stream = await navigator.mediaDevices.getUserMedia(constraints)

      const mimeType = MediaRecorder.isTypeSupported("audio/webm")
        ? "audio/webm"
        : MediaRecorder.isTypeSupported("audio/ogg")
          ? "audio/ogg"
          : "audio/mp4"

      this.mediaRecorder = new MediaRecorder(stream, { mimeType })
      this.chunks = []
      this.isRecording = true
      this.startTime = Date.now()

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this.chunks.push(e.data)
      }

      this.mediaRecorder.onstop = () => {
        this.handleRecordingComplete()
        stream.getTracks().forEach(t => t.stop())
      }

      this.mediaRecorder.start(100)
      this.updateUI(true)

      // Auto-stop after 60 seconds
      this.autoStopTimer = setTimeout(() => {
        if (this.isRecording) this.stopRecording()
      }, 60000)

      // Update timer display
      this.timerInterval = setInterval(() => {
        const elapsed = Math.floor((Date.now() - this.startTime) / 1000)
        if (this.statusEl) {
          this.statusEl.textContent = `${elapsed}s`
        }
      }, 1000)

    } catch (e) {
      console.error("[VoiceRecorder] Failed to start recording:", e)
      if (e.name === "NotAllowedError") {
        alert("Microphone access denied. Please allow microphone permission in your browser.")
      } else if (e.name === "NotFoundError" || e.name === "OverconstrainedError") {
        alert("Selected microphone not found. Trying default...")
        this.selectedDeviceId = null
        localStorage.removeItem(getStorageKey())
        await this.startRecording()
      } else {
        alert("Could not start recording: " + e.message)
      }
    }
  },

  stopRecording() {
    if (!this.isRecording || !this.mediaRecorder) return

    this.isRecording = false
    clearTimeout(this.autoStopTimer)
    clearInterval(this.timerInterval)

    if (this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop()
    }

    this.updateUI(false)
  },

  async handleRecordingComplete() {
    const duration = Math.floor((Date.now() - this.startTime) / 1000)
    if (duration < 1) {
      console.log("[VoiceRecorder] Recording too short, discarding")
      return
    }

    const blob = new Blob(this.chunks, { type: this.mediaRecorder.mimeType })

    try {
      const reader = new FileReader()
      reader.onloadend = () => {
        const base64 = reader.result.split(",")[1]
        this.pushEvent("send_voice_message", {
          audio_base64: base64,
          mime_type: blob.type,
          duration: duration
        })
      }
      reader.readAsDataURL(blob)
    } catch (e) {
      console.error("[VoiceRecorder] Failed to encode audio:", e)
    }
  },

  updateUI(recording) {
    if (recording) {
      this.button.classList.add("text-error", "animate-pulse")
      this.button.classList.remove("text-base-content/60", "hover:text-primary")
      this.button.title = "Stop recording"
      if (this.statusEl) {
        this.statusEl.classList.remove("hidden")
        this.statusEl.textContent = "0s"
      }
    } else {
      this.button.classList.remove("text-error", "animate-pulse")
      this.button.classList.add("text-base-content/60", "hover:text-primary")
      this.button.title = "Voice message"
      if (this.statusEl) {
        this.statusEl.classList.add("hidden")
      }
    }
  }
}

export default ChatVoiceRecorder
