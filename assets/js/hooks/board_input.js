const ALLOWED_TYPES = [
  "image/jpeg", "image/png", "image/gif", "image/webp",
  "audio/mpeg", "audio/wav", "audio/wave", "audio/x-wav",
  "audio/webm", "audio/ogg"
]

const MAX_SIZE = 50 * 1024 * 1024

export default {
  mounted() {
    this.textarea = this.el.querySelector("textarea")
    this.emojiBtn = this.el.querySelector("[data-board-emoji-btn]")
    this.emojiPanel = this.el.querySelector("[data-board-emoji-panel]")
    this.attachmentBtn = this.el.querySelector("[data-board-attachment-btn]")
    this.fileInput = this.el.querySelector("[data-board-file-input]")
    this.voiceBtn = this.el.querySelector("[data-board-voice-btn]")
    this.voiceStatus = this.el.querySelector("[data-board-voice-status]")

    if (!this.textarea) return

    this.currentEmojiPage = 0
    this.totalEmojiPages = this.emojiPanel ? this.emojiPanel.querySelectorAll(".emoji-page").length : 0

    // Emoji toggle
    if (this.emojiBtn && this.emojiPanel) {
      this.emojiBtn.addEventListener("click", (e) => {
        e.stopPropagation()
        this.toggleEmojiPanel()
      })

      this.emojiPanel.addEventListener("click", (e) => {
        const btn = e.target.closest("[data-emoji]")
        if (btn) {
          this.insertEmoji(btn.dataset.emoji)
        }
      })

      // Pagination
      const prevBtn = this.emojiPanel.querySelector(".emoji-page-prev")
      const nextBtn = this.emojiPanel.querySelector(".emoji-page-next")
      if (prevBtn) {
        prevBtn.addEventListener("click", (e) => {
          e.stopPropagation()
          this.changeEmojiPage(-1)
        })
      }
      if (nextBtn) {
        nextBtn.addEventListener("click", (e) => {
          e.stopPropagation()
          this.changeEmojiPage(1)
        })
      }
    }

    // File upload
    if (this.attachmentBtn && this.fileInput) {
      this.attachmentBtn.addEventListener("click", () => this.fileInput.click())
      this.fileInput.addEventListener("change", (e) => this.handleFileSelect(e))
    }

    // Voice recording
    if (this.voiceBtn) {
      this.voiceBtn.addEventListener("click", () => this.toggleVoiceRecording())
    }

    // Outside click to close emoji panel
    this._outsideClickHandler = (e) => {
      if (this.emojiPanel && !this.emojiPanel.contains(e.target) && e.target !== this.emojiBtn) {
        this.hideEmojiPanel()
      }
    }
    document.addEventListener("click", this._outsideClickHandler)
  },

  destroyed() {
    if (this._outsideClickHandler) {
      document.removeEventListener("click", this._outsideClickHandler)
    }
    this.stopVoiceRecording()
  },

  // ============================================================================
  // Emoji Panel
  // ============================================================================

  toggleEmojiPanel() {
    if (!this.emojiPanel) return
    this.emojiPanel.classList.toggle("hidden")
  },

  hideEmojiPanel() {
    if (!this.emojiPanel) return
    this.emojiPanel.classList.add("hidden")
  },

  changeEmojiPage(delta) {
    if (!this.emojiPanel) return
    const pages = this.emojiPanel.querySelectorAll(".emoji-page")
    const newPage = this.currentEmojiPage + delta
    if (newPage < 0 || newPage >= pages.length) return

    pages[this.currentEmojiPage].classList.add("hidden")
    pages[newPage].classList.remove("hidden")
    this.currentEmojiPage = newPage

    const prevBtn = this.emojiPanel.querySelector(".emoji-page-prev")
    const nextBtn = this.emojiPanel.querySelector(".emoji-page-next")
    const info = this.emojiPanel.querySelector(".emoji-page-info")
    if (prevBtn) prevBtn.disabled = this.currentEmojiPage === 0
    if (nextBtn) nextBtn.disabled = this.currentEmojiPage === pages.length - 1
    if (info) info.textContent = `${this.currentEmojiPage + 1} / ${pages.length}`
  },

  insertEmoji(emoji) {
    if (!this.textarea) return
    const start = this.textarea.selectionStart
    const end = this.textarea.selectionEnd
    const value = this.textarea.value
    this.textarea.value = value.slice(0, start) + emoji + value.slice(end)
    this.textarea.selectionStart = this.textarea.selectionEnd = start + emoji.length
    this.textarea.focus()
    this.textarea.dispatchEvent(new Event("input", { bubbles: true }))
  },

  // ============================================================================
  // File Upload
  // ============================================================================

  handleFileSelect(e) {
    const file = e.target.files[0]
    if (!file) return
    this.processFile(file)
  },

  processFile(file) {
    if (!ALLOWED_TYPES.includes(file.type)) {
      alert("File type not allowed.")
      return
    }
    if (file.size > MAX_SIZE) {
      alert("File too large. Maximum size is 50MB.")
      return
    }
    this.uploadFile(file)
  },

  async uploadFile(file) {
    const formData = new FormData()
    formData.append("file", file)

    try {
      const resp = await fetch("/api/chat/uploads", {
        method: "POST",
        body: formData,
        headers: {
          "x-csrf-token": document.querySelector("meta[name='csrf-token']")?.content || ""
        }
      })

      if (!resp.ok) {
        const err = await resp.json().catch(() => ({}))
        alert(err.error || "Upload failed")
        return
      }

      const result = await resp.json()
      this.insertFileMarkdown(result, file.name)
    } catch (e) {
      console.error("[BoardInput] Upload failed:", e)
      alert("Upload failed")
    }
  },

  insertFileMarkdown(result, originalName) {
    if (!this.textarea) return
    const start = this.textarea.selectionStart
    const end = this.textarea.selectionEnd
    const value = this.textarea.value

    let markdown = ""
    if (result.type === "image") {
      markdown = `![${originalName}](${result.path})`
    } else if (result.type === "audio") {
      markdown = `[🎤 ${originalName}](${result.path})`
    }

    this.textarea.value = value.slice(0, start) + markdown + value.slice(end)
    this.textarea.selectionStart = this.textarea.selectionEnd = start + markdown.length
    this.textarea.focus()
    this.textarea.dispatchEvent(new Event("input", { bubbles: true }))
  },

  // ============================================================================
  // Voice Recording
  // ============================================================================

  async toggleVoiceRecording() {
    if (this.isRecording) {
      this.stopVoiceRecording()
    } else {
      await this.startVoiceRecording()
    }
  },

  async startVoiceRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const mimeType = MediaRecorder.isTypeSupported("audio/webm") ? "audio/webm" : "audio/ogg"
      this.mediaRecorder = new MediaRecorder(stream, { mimeType })
      this.chunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this.chunks.push(e.data)
      }

      this.mediaRecorder.onstop = () => {
        const blob = new Blob(this.chunks, { type: mimeType })
        this.uploadVoice(blob)
        stream.getTracks().forEach(t => t.stop())
      }

      this.mediaRecorder.start()
      this.isRecording = true
      this.startTime = Date.now()

      if (this.voiceBtn) {
        this.voiceBtn.classList.add("text-error", "animate-pulse")
        this.voiceBtn.classList.remove("text-base-content/60")
      }
      if (this.voiceStatus) {
        this.voiceStatus.classList.remove("hidden")
      }

      this.timerInterval = setInterval(() => {
        const secs = Math.floor((Date.now() - this.startTime) / 1000)
        if (this.voiceStatus) {
          this.voiceStatus.textContent = `${secs}s`
        }
      }, 1000)
    } catch (err) {
      console.error("[BoardInput] Voice recording failed:", err)
      alert("Could not access microphone.")
    }
  },

  async stopVoiceRecording() {
    if (!this.isRecording) return
    this.isRecording = false

    if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop()
    }

    if (this.timerInterval) {
      clearInterval(this.timerInterval)
      this.timerInterval = null
    }

    if (this.voiceBtn) {
      this.voiceBtn.classList.remove("text-error", "animate-pulse")
      this.voiceBtn.classList.add("text-base-content/60")
    }
    if (this.voiceStatus) {
      this.voiceStatus.classList.add("hidden")
    }
  },

  async getAudioDuration(blob) {
    try {
      const arrayBuffer = await blob.arrayBuffer()
      const audioContext = new (window.AudioContext || window.webkitAudioContext)()
      const audioBuffer = await audioContext.decodeAudioData(arrayBuffer)
      return Math.floor(audioBuffer.duration)
    } catch (e) {
      console.error("[BoardInput] Could not decode audio duration:", e)
      return 0
    }
  },

  async uploadVoice(blob) {
    const duration = await this.getAudioDuration(blob)
    const file = new File([blob], "voice-message.webm", { type: blob.type })
    const formData = new FormData()
    formData.append("file", file)

    try {
      const resp = await fetch("/api/chat/uploads", {
        method: "POST",
        body: formData,
        headers: {
          "x-csrf-token": document.querySelector("meta[name='csrf-token']")?.content || ""
        }
      })

      if (!resp.ok) {
        alert("Voice upload failed")
        return
      }

      const result = await resp.json()
      this.insertVoiceMarkdown(result, duration)
    } catch (e) {
      console.error("[BoardInput] Voice upload failed:", e)
      alert("Voice upload failed")
    }
  },

  insertVoiceMarkdown(result, duration) {
    if (!this.textarea) return
    const start = this.textarea.selectionStart
    const end = this.textarea.selectionEnd
    const value = this.textarea.value
    const markdown = `[🎤 Voice message](${result.path}#duration=${duration})`

    this.textarea.value = value.slice(0, start) + markdown + value.slice(end)
    this.textarea.selectionStart = this.textarea.selectionEnd = start + markdown.length
    this.textarea.focus()
    this.textarea.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
