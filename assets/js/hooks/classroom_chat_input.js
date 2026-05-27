const EMOJIS = [
  "😀", "😂", "❤️", "👍", "🎉", "🔥", "😊", "😭", "🙏", "✨",
  "🥰", "🤔", "😅", "👏", "🌸", "🍀", "⭐", "💯", "🎊", "🌟",
  "🎌", "🗾", "🍜", "🍱", "🍡", "🍣", "🍙", "🍥", "🍘", "🍮"
]

const ClassroomChatInput = {
  mounted() {
    this.textarea = this.el.querySelector("#classroom-chat-textarea")
    this.sendButton = this.el.querySelector("#classroom-chat-send-button")
    this.emojiBtn = this.el.querySelector("#classroom-emoji-button")
    this.emojiPanel = this.el.querySelector("#classroom-emoji-panel")
    this.imageBtn = this.el.querySelector("#classroom-image-button")
    this.imageInput = this.el.querySelector("#classroom-image-input")
    this.imagePreview = this.el.querySelector("#classroom-image-preview")

    if (!this.textarea) return

    this.typingTimer = null
    this.typingSent = false
    this.lastTypingSent = 0
    this.queuedImage = null

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
      this.textarea.style.height = Math.min(this.textarea.scrollHeight, 128) + "px"
      this.sendTypingIndicator()
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
      this.emojiPanel.addEventListener("click", (e) => {
        if (e.target.dataset.emoji) {
          this.insertEmoji(e.target.dataset.emoji)
        }
      })
    }

    if (this.imageBtn && this.imageInput) {
      this.imageBtn.addEventListener("click", () => this.imageInput.click())
      this.imageInput.addEventListener("change", (e) => this.handleImageSelect(e))
    }

    if (this.imagePreview) {
      // Use event delegation so the listener survives LiveView DOM patches
      this.imagePreview.addEventListener("click", (e) => {
        if (e.target.closest("#classroom-image-cancel")) {
          e.preventDefault()
          e.stopPropagation()
          this.clearImage()
        }
      })
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
        this.textarea.style.height = Math.min(this.textarea.scrollHeight, 128) + "px"
        this.textarea.focus()
      }
    })

    this.textarea.focus()
  },

  destroyed() {
    if (this._outsideClickHandler) {
      document.removeEventListener("click", this._outsideClickHandler)
    }
    if (this.typingTimer) {
      clearTimeout(this.typingTimer)
    }
  },

  handleImageSelect(e) {
    const file = e.target.files[0]
    if (!file) return

    if (!file.type.startsWith("image/")) {
      alert("Please select an image file.")
      return
    }

    if (file.size > 5 * 1024 * 1024) {
      alert("Image is too large. Maximum size is 5MB.")
      return
    }

    const reader = new FileReader()
    reader.onload = (ev) => {
      this.queuedImage = {
        dataUrl: ev.target.result,
        mimeType: file.type
      }
      this.showImagePreview(ev.target.result)
    }
    reader.readAsDataURL(file)
  },

  showImagePreview(dataUrl) {
    if (!this.imagePreview) return
    const img = this.imagePreview.querySelector("img")
    if (img) img.src = dataUrl
    this.imagePreview.classList.remove("hidden")
    this.imagePreview.classList.add("inline-block")
  },

  clearImage() {
    this.queuedImage = null
    if (this.imagePreview) {
      this.imagePreview.classList.add("hidden")
      this.imagePreview.classList.remove("inline-block")
    }
    if (this.imageInput) this.imageInput.value = ""
  },

  _base64FromDataUrl(dataUrl) {
    return dataUrl.split(",")[1]
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
  },

  hideEmojiPanel() {
    if (this.emojiPanel) {
      this.emojiPanel.classList.add("hidden")
    }
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

  submit() {
    const text = this.textarea.value.trim()
    const hasImage = this.queuedImage != null

    if (text === "" && !hasImage) return

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

    // Send image first, then text (both if present)
    if (hasImage) {
      const base64 = this._base64FromDataUrl(this.queuedImage.dataUrl)
      this.pushEvent("send_image_message", {
        image_base64: base64,
        mime_type: this.queuedImage.mimeType
      })
      this.clearImage()
    }

    if (text) {
      this.pushEvent("send_message", { content: text })
    }

    this.textarea.value = ""
    this.textarea.style.height = "auto"
    this.textarea.focus()
  }
}

export default ClassroomChatInput
