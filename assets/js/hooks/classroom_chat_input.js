import { ChatDictionary } from "../lib/chat_dictionary"

const ALLOWED_TYPES = [
  "image/jpeg", "image/png", "image/gif", "image/webp",
  "audio/mpeg", "audio/wav", "audio/wave", "audio/x-wav",
  "video/mp4", "video/webm", "video/ogg", "video/quicktime",
  "application/pdf", "text/plain", "text/csv",
  "application/json", "text/markdown", "text/x-markdown",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/epub+zip"
]

const MAX_SIZE_DEFAULT = 50 * 1024 * 1024
const MAX_SIZE_VIDEO = 200 * 1024 * 1024

const CHAT_DRAFTS = window.__medoruChatDrafts || (window.__medoruChatDrafts = {})

function saveChatDraft(key, value) {
  if (key) CHAT_DRAFTS[key] = value
}

function getChatDraft(key) {
  return key ? CHAT_DRAFTS[key] : undefined
}

function clearChatDraft(key) {
  delete CHAT_DRAFTS[key]
}

const ClassroomChatInput = {
  beforeUpdate() {
    this._saveDraft()
  },

  updated() {
    this._restoreDraft()
  },

  _draftKey() {
    return this.el.id || "classroom-chat-draft"
  },

  _saveDraft() {
    if (this.textarea) {
      this._draftHadFocus = document.activeElement === this.textarea
      saveChatDraft(this._draftKey(), this.textarea.value)
    }
  },

  _restoreDraft() {
    this.textarea = this.el.querySelector("#classroom-chat-textarea")
    if (!this.textarea) return

    const draft = getChatDraft(this._draftKey())
    if (draft && this.textarea.value === "") {
      this.textarea.value = draft
      this.textarea.style.height = "auto"
      const maxHeight = parseInt(getComputedStyle(this.textarea).maxHeight, 10) || 128
      this.textarea.style.height = Math.min(this.textarea.scrollHeight, maxHeight) + "px"
      if (this._draftHadFocus) {
        this.textarea.focus()
      }
    }

    clearChatDraft(this._draftKey())
    this._draftHadFocus = false
  },

  _clearDraft() {
    clearChatDraft(this._draftKey())
  },

  mounted() {
    this.textarea = this.el.querySelector("#classroom-chat-textarea")
    this.sendButton = this.el.querySelector("#classroom-chat-send-button")
    this.emojiBtn = this.el.querySelector("#classroom-emoji-button")
    this.emojiPanel = this.el.querySelector("#classroom-emoji-panel")
    this.attachmentBtn = this.el.querySelector("#classroom-attachment-button")
    this.fileInput = this.el.querySelector("#classroom-file-input")
    this.filePreview = this.el.querySelector("#classroom-file-preview")
    this.filePreviewName = this.el.querySelector("#classroom-file-preview-name")
    this.messagesContainer = document.getElementById("classroom-chat-messages")
    this.dragOverlay = document.getElementById("classroom-chat-drag-overlay")

    if (!this.textarea) return

    this.typingTimer = null
    this.typingSent = false
    this.lastTypingSent = 0
    this.queuedFile = null
    this.isUploading = false

    const dictionaryWrapper =
      this.el.closest("[data-dictionary-enabled]") ||
      document.getElementById("chat-wrapper")
    this.chatDictionary = new ChatDictionary(this.textarea, {
      hook: this,
      wrapper: dictionaryWrapper
    })

    this.enterSends = this.el.dataset.enterSends !== "false"

    this.textarea.addEventListener("keydown", (e) => {
      if (e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) {
        this.sendTypingIndicator()
      }

      // Enter behavior depends on user preference
      if (this.enterSends) {
        // Enter sends, Shift+Enter creates paragraph
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault()
          this.submit()
          return
        }
      } else {
        // Shift+Enter sends, Enter creates paragraph
        if (e.key === "Enter" && e.shiftKey) {
          e.preventDefault()
          this.submit()
          return
        }
      }

      if (e.key === "Escape") {
        this.hideEmojiPanel()
        if (window.classroomEditingMessage) {
          window.classroomEditingMessage = null
          this.textarea.value = ""
          this.textarea.style.height = "auto"
          this._clearDraft()
          this.pushEvent("cancel_edit", {})
        }
        return
      }

      if (e.key === "ArrowUp" && this.textarea.value.trim() === "" && !window.classroomEditingMessage) {
        e.preventDefault()
        this.editLastMessage()
        return
      }
    })

    this.textarea.addEventListener("input", () => {
      this.textarea.style.height = "auto"
      const maxHeight = parseInt(getComputedStyle(this.textarea).maxHeight, 10) || 128
      this.textarea.style.height = Math.min(this.textarea.scrollHeight, maxHeight) + "px"
      this.sendTypingIndicator()
    })

    this._restoreDraft()

    this.textarea.addEventListener("paste", (e) => {
      const files = e.clipboardData?.files
      if (!files || files.length === 0) return

      const imageFile = Array.from(files).find(f => f.type.startsWith("image/"))
      if (!imageFile) return

      e.preventDefault()
      this.processFile(imageFile)
    })

    if (this.sendButton) {
      this.sendButton.addEventListener("click", () => this.submit())
    }

    if (this.emojiBtn) {
      this.emojiBtn.addEventListener("click", (e) => {
        e.stopPropagation()
        this.toggleEmojiPanel()
      })
    }

    if (this.emojiPanel) {
      this.currentEmojiPage = 0
      this.totalEmojiPages = this.emojiPanel.querySelectorAll(".emoji-page").length
      this.emojiPrevBtn = this.emojiPanel.querySelector(".emoji-page-prev")
      this.emojiNextBtn = this.emojiPanel.querySelector(".emoji-page-next")

      if (this.emojiPrevBtn) {
        this.emojiPrevBtn.addEventListener("click", (e) => {
          e.stopPropagation()
          this.changeEmojiPage(-1)
        })
      }
      if (this.emojiNextBtn) {
        this.emojiNextBtn.addEventListener("click", (e) => {
          e.stopPropagation()
          this.changeEmojiPage(1)
        })
      }

      this.emojiPanel.addEventListener("click", (e) => {
        const btn = e.target.closest("[data-emoji]")
        if (btn) {
          this.insertEmoji(btn.dataset.emoji)
        }
      })
    }

    if (this.attachmentBtn && this.fileInput) {
      this.attachmentBtn.addEventListener("click", () => this.fileInput.click())
      this.fileInput.addEventListener("change", (e) => this.handleFileSelect(e))
    }

    if (this.filePreview) {
      this.filePreview.addEventListener("click", (e) => {
        if (e.target.closest("#classroom-file-cancel")) {
          e.preventDefault()
          e.stopPropagation()
          this.clearFile()
        }
      })
    }

    // Drag & Drop
    if (this.messagesContainer && this.dragOverlay) {
      this._dragCounter = 0

      this._dragEnterHandler = (e) => {
        e.preventDefault()
        this._dragCounter++
        if (e.dataTransfer.types.includes("Files")) {
          this.dragOverlay.classList.remove("hidden")
        }
      }
      this._dragLeaveHandler = (e) => {
        e.preventDefault()
        this._dragCounter--
        if (this._dragCounter <= 0) {
          this.dragOverlay.classList.add("hidden")
          this._dragCounter = 0
        }
      }
      this._dragOverHandler = (e) => {
        e.preventDefault()
      }
      this._dropHandler = (e) => {
        e.preventDefault()
        this._dragCounter = 0
        this.dragOverlay.classList.add("hidden")
        const files = e.dataTransfer.files
        if (files.length > 0) {
          this.processFile(files[0])
        }
      }

      this.messagesContainer.addEventListener("dragenter", this._dragEnterHandler)
      this.messagesContainer.addEventListener("dragleave", this._dragLeaveHandler)
      this.messagesContainer.addEventListener("dragover", this._dragOverHandler)
      this.messagesContainer.addEventListener("drop", this._dropHandler)
    }

    // Close emoji panel on outside click
    this._outsideClickHandler = (e) => {
      if (this.emojiPanel && !this.emojiPanel.contains(e.target) && e.target !== this.emojiBtn) {
        this.hideEmojiPanel()
      }
    }
    document.addEventListener("click", this._outsideClickHandler)

    // Handle edit mode start from server
    this.handleEvent("start_edit_text", ({ text, message_id }) => {
      window.classroomEditingMessage = { message_id, text }
      if (this.textarea) {
        this.textarea.value = text
        this.textarea.style.height = "auto"
        const maxHeight = parseInt(getComputedStyle(this.textarea).maxHeight, 10) || 128
        this.textarea.style.height = Math.min(this.textarea.scrollHeight, maxHeight) + "px"
        this.textarea.focus()
      }
    })

    this.textarea.focus()
  },

  destroyed() {
    if (this.chatDictionary) {
      this.chatDictionary.destroy()
      this.chatDictionary = null
    }

    if (this._outsideClickHandler) {
      document.removeEventListener("click", this._outsideClickHandler)
    }
    if (this.typingTimer) {
      clearTimeout(this.typingTimer)
    }
    if (this.messagesContainer) {
      if (this._dragEnterHandler) this.messagesContainer.removeEventListener("dragenter", this._dragEnterHandler)
      if (this._dragLeaveHandler) this.messagesContainer.removeEventListener("dragleave", this._dragLeaveHandler)
      if (this._dragOverHandler) this.messagesContainer.removeEventListener("dragover", this._dragOverHandler)
      if (this._dropHandler) this.messagesContainer.removeEventListener("drop", this._dropHandler)
    }
  },

  handleFileSelect(e) {
    const file = e.target.files[0]
    if (!file) return
    this.processFile(file)
  },

  processFile(file) {
    const isAllowedType = ALLOWED_TYPES.includes(file.type) || this.allowedByExtension(file.name)

    if (!isAllowedType) {
      alert("File type not allowed.")
      return
    }

    const isVideo = file.type.startsWith("video/") || this.isVideoExtension(file.name)
    const canUploadVideo = this.el.dataset.canUploadVideo === "true"

    if (isVideo && !canUploadVideo) {
      alert("Video uploads are only available for teachers and admins.")
      return
    }

    const maxSize = isVideo ? MAX_SIZE_VIDEO : MAX_SIZE_DEFAULT
    const maxSizeMb = maxSize / (1024 * 1024)

    if (file.size > maxSize) {
      alert(`File too large. Maximum size is ${maxSizeMb}MB.`)
      return
    }

    this.queuedFile = file
    this.showFilePreview(file.name)
  },

  allowedByExtension(filename) {
    const ext = filename.split('.').pop()?.toLowerCase()
    const allowedExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp3', 'wav', 'webm', 'ogg', 'mp4', 'mov', 'ogv', 'pdf', 'txt', 'csv', 'json', 'md', 'docx', 'xlsx', 'epub']
    return allowedExts.includes(ext)
  },

  isVideoExtension(filename) {
    const ext = filename.split('.').pop()?.toLowerCase()
    return ['mp4', 'mov', 'ogv', 'webm'].includes(ext)
  },

  showFilePreview(name) {
    if (!this.filePreview || !this.filePreviewName) return
    this.filePreviewName.textContent = name
    this.filePreview.classList.remove("hidden")
  },

  clearFile() {
    this.queuedFile = null
    if (this.filePreview) this.filePreview.classList.add("hidden")
    if (this.fileInput) this.fileInput.value = ""
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
        return null
      }

      return await resp.json()
    } catch (e) {
      console.error("[ClassroomChatInput] Upload failed:", e)
      alert("Upload failed")
      return null
    }
  },

  sendTypingIndicator() {
    const now = Date.now()
    if (now - this.lastTypingSent < 300) return

    if (!this.typingSent) {
      this.pushEvent("set_typing", { typing: true })
      this.typingSent = true
    }
    this.lastTypingSent = now

    if (this.typingTimer) clearTimeout(this.typingTimer)
    this.typingTimer = setTimeout(() => {
      this.pushEvent("set_typing", { typing: false })
      this.typingSent = false
    }, 3000)
  },

  editLastMessage() {
    const messages = document.querySelectorAll(".message-bubble")
    for (let i = messages.length - 1; i >= 0; i--) {
      const bubble = messages[i]
      if (bubble.textContent.includes("This message was deleted")) continue
      if (bubble.querySelector(".chat-audio-el")) continue

      const editBtn = bubble.closest(".group/message")?.querySelector("button[phx-click='start_edit']")
      if (editBtn) {
        editBtn.click()
        return
      }
    }
  },

  toggleEmojiPanel() {
    if (!this.emojiPanel) return
    this.emojiPanel.classList.toggle("hidden")
    if (!this.emojiPanel.classList.contains("hidden")) {
      this.resetEmojiPage()
    }
  },

  hideEmojiPanel() {
    if (this.emojiPanel) {
      this.emojiPanel.classList.add("hidden")
    }
  },

  resetEmojiPage() {
    this.currentEmojiPage = 0
    this.emojiPanel.querySelectorAll(".emoji-page").forEach((page, i) => {
      page.classList.toggle("hidden", i !== 0)
    })
    const info = this.emojiPanel.querySelector(".emoji-page-info")
    if (info) info.textContent = `1 / ${this.totalEmojiPages}`
    if (this.emojiPrevBtn) this.emojiPrevBtn.disabled = true
    if (this.emojiNextBtn) this.emojiNextBtn.disabled = this.totalEmojiPages <= 1
  },

  changeEmojiPage(delta) {
    const newPage = this.currentEmojiPage + delta
    if (newPage < 0 || newPage >= this.totalEmojiPages) return

    this.emojiPanel.querySelectorAll(".emoji-page").forEach((page, i) => {
      page.classList.toggle("hidden", i !== newPage)
    })

    this.currentEmojiPage = newPage

    const info = this.emojiPanel.querySelector(".emoji-page-info")
    if (info) info.textContent = `${newPage + 1} / ${this.totalEmojiPages}`
    if (this.emojiPrevBtn) this.emojiPrevBtn.disabled = newPage === 0
    if (this.emojiNextBtn) this.emojiNextBtn.disabled = newPage === this.totalEmojiPages - 1
  },

  insertEmoji(emoji) {
    const start = this.textarea.selectionStart
    const end = this.textarea.selectionEnd
    const value = this.textarea.value
    this.textarea.value = value.substring(0, start) + emoji + value.substring(end)
    this.textarea.selectionStart = this.textarea.selectionEnd = start + emoji.length
    this.textarea.focus()
    this.textarea.dispatchEvent(new Event("input"))
  },

  async submit() {
    const rawText = this.textarea.value.trim()
    const text = this.chatDictionary
      ? this.chatDictionary.substituteAliases(rawText)
      : rawText
    const hasFile = this.queuedFile != null

    if (text === "" && !hasFile) return

    if (text.startsWith("/ai ") && this.chatDictionary?.isEnabled()) {
      const prompt = text.slice(4).trim()
      if (prompt !== "") {
        this.pushEvent("generate_ai_response", {
          prompt: prompt,
          context: collectClassroomChatContext()
        })
      }
      this.textarea.value = ""
      this.textarea.style.height = "auto"
      this.textarea.focus()
      this._clearDraft()
      return
    }

    // Validate /kanji, /word, \kanji, and \word commands
    if (text.startsWith("/kanji ") || text.startsWith("/k ") || text.startsWith("\\kanji ") || text.startsWith("\\k ")) {
      const char = text.startsWith("/k ") || text.startsWith("\\k ") ? text.slice(3).trim() : text.slice(7).trim()
      if (!isSingleKanji(char)) {
        alert("Invalid /kanji command. Usage: /kanji <single kanji>, /k <single kanji>, \\kanji <single kanji>, or \\k <single kanji>")
        return
      }
    }
    if (text.startsWith("/word ") || text.startsWith("/w ") || text.startsWith("\\word ") || text.startsWith("\\w ")) {
      const word = text.startsWith("/w ") || text.startsWith("\\w ") ? text.slice(3).trim() : text.slice(6).trim()
      if (!word) {
        alert("Invalid /word command. Usage: /word <word>, /w <word>, \\word <word>, or \\w <word>")
        return
      }
    }

    if (this.typingTimer) {
      clearTimeout(this.typingTimer)
      this.typingTimer = null
    }
    if (this.typingSent) {
      this.pushEvent("set_typing", { typing: false })
      this.typingSent = false
    }

    if (window.classroomEditingMessage) {
      const edit = window.classroomEditingMessage
      window.classroomEditingMessage = null
      this.pushEvent("edit_message", { content: text, message_id: edit.message_id })
      this.textarea.value = ""
      this.textarea.style.height = "auto"
      this.textarea.focus()
      return
    }

    // Upload file first, then send message
    if (hasFile) {
      this.isUploading = true
      const result = await this.uploadFile(this.queuedFile)
      this.isUploading = false
      this.clearFile()

      if (!result) return

      const content =
        result.type === "image" ? "📷 Image" :
        result.type === "audio" ? "🔊 Audio" :
        result.type === "video" ? "🎬 Video" :
        `📎 ${result.name}`
      this.pushEvent("send_file_message", {
        path: result.path,
        type: result.type,
        name: result.name,
        size: result.size,
        content
      })
    }

    if (text) {
      this.pushEvent("send_message", { content: text })
    }

    this.textarea.value = ""
    this.textarea.style.height = "auto"
    this.textarea.focus()
    this._clearDraft()
  }
}

function isSingleKanji(str) {
  if (str.length !== 1) return false
  const code = str.codePointAt(0)
  return (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3400 && code <= 0x4DBF)
}

function collectClassroomChatContext() {
  const container = document.getElementById("classroom-chat-messages")
  if (!container) return []

  const rows = Array.from(container.querySelectorAll(".group\\/message"))
  const context = []

  for (const row of rows.slice(-20)) {
    const bubble = row.querySelector(".message-bubble")
    if (!bubble) continue

    const text = bubble.textContent?.replace(/\s+/g, " ").trim() || ""
    if (!text || text === "[...]") continue

    const isMe = row.classList.contains("justify-end")
    context.push({
      sender_id: row.dataset.senderId,
      role: isMe ? "user" : "other",
      text: text
    })
  }

  return context
}

export default ClassroomChatInput
