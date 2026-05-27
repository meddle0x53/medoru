// Loopback/virtual audio devices to deprioritize in the picker.
// "stereo" is intentionally NOT in this list — many real USB microphones
// contain "Stereo" in their driver name (e.g. "Blue Yeti Stereo Microphone")
// and would be wrongly hidden.
const LOOPBACK_KEYWORDS = ["mix", "loopback", "virtual", "cable", "what u hear", "desktop"]

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
    this.devicesLoaded = false

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

    // Do NOT enumerate microphones on mount — that triggers a permission
    // prompt on iOS before the user has clicked anything. Devices are loaded
    // lazily on first interaction with the mic button or picker.
  },

  destroyed() {
    if (this._outsideClick) {
      document.removeEventListener("click", this._outsideClick)
    }
    this.stopRecording()
  },

  async loadDevices() {
    try {
      // Request temporary permission to enumerate labeled devices.
      // On Firefox this is required before enumerateDevices() returns labels.
      const tempStream = await navigator.mediaDevices.getUserMedia({ audio: true })
      tempStream.getTracks().forEach(t => t.stop())

      // Give Firefox a moment to fully release the stream before enumerating.
      // Without this, devices can appear missing or with stale data.
      await new Promise(r => setTimeout(r, 100))

      const allDevices = await navigator.mediaDevices.enumerateDevices()

      // Log raw output for debugging
      console.log("[VoiceRecorder] Raw devices:", allDevices
        .filter(d => d.kind === "audioinput")
        .map(d => ({ id: d.deviceId, label: d.label })))

      // Keep every audio input that has a deviceId (including default/communications).
      // Filtering out default/communications can hide the only available entry
      // for a microphone on some systems (especially Firefox + PulseAudio).
      let inputs = allDevices.filter(d => d.kind === "audioinput" && d.deviceId)

      // Sort real microphones first, then default/communications aliases, then loopback last
      inputs.sort((a, b) => {
        const aLoopback = isLoopbackDevice(a.label)
        const bLoopback = isLoopbackDevice(b.label)
        const aDefault = a.deviceId === "default" || a.deviceId === "communications"
        const bDefault = b.deviceId === "default" || b.deviceId === "communications"

        if (aLoopback && !bLoopback) return 1
        if (!aLoopback && bLoopback) return -1
        if (aDefault && !bDefault) return 1
        if (!aDefault && bDefault) return -1
        return 0
      })

      this.devices = inputs

      // If the previously selected device disappeared, clear it
      if (this.selectedDeviceId && !this.devices.find(d => d.deviceId === this.selectedDeviceId)) {
        console.log("[VoiceRecorder] Previously selected device gone, clearing")
        this.selectedDeviceId = null
        localStorage.removeItem(getStorageKey())
      }

      // Auto-select if nothing stored
      if (!this.selectedDeviceId && this.devices.length > 0) {
        const preferred = this.devices.find(d => isMicrophoneDevice(d.label) && !isLoopbackDevice(d.label))
        this.selectedDeviceId = preferred ? preferred.deviceId : this.devices[0].deviceId
        localStorage.setItem(getStorageKey(), this.selectedDeviceId)
      }

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

  async togglePicker(e) {
    e.stopPropagation()
    if (this.pickerEl) {
      const isHidden = this.pickerEl.classList.contains("hidden")
      if (isHidden) {
        // Load/refresh devices when opening (needs user gesture for permission on iOS)
        await this.loadDevices()
        this.devicesLoaded = true
      }
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
      return
    }

    // Load devices on first use (needs user gesture for permission on iOS)
    if (!this.devicesLoaded) {
      await this.loadDevices()
      this.devicesLoaded = true
    }

    await this.startRecording()
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
