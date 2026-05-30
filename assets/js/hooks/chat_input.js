import { CryptoState } from "./chat_crypto"

const EMOJIS = [
  "😀", "😂", "❤️", "👍", "🎉", "🔥", "😊", "😭", "🙏", "✨",
  "🥰", "🤔", "😅", "👏", "🌸", "🍀", "⭐", "💯", "🎊", "🌟",
  "🎌", "🗾", "🍜", "🍱", "🍡", "🍣", "🍙", "🍥", "🍘", "🍮"
]

// Typing indicator debounce
const TYPING_DELAY = 3000
const TYPING_SEND_DEBOUNCE = 300

const ChatInput = {
  mounted() {
    this.textarea = this.el.querySelector("textarea")
    this.sendButton = this.el.querySelector("#chat-send-button")
    this.emojiBtn = this.el.querySelector("#chat-emoji-button")
    this.emojiPanel = this.el.querySelector("#chat-emoji-panel")
    this.imageBtn = this.el.querySelector("#chat-image-button")
    this.imageInput = this.el.querySelector("#chat-image-input")
    this.imagePreview = this.el.querySelector("#chat-image-preview")
    this.convId = document.getElementById("chat-wrapper")?.dataset.conversationId

    if (!this.textarea) return

    this.typingTimer = null
    this.typingSent = false
    this.lastTypingSent = 0
    this.queuedImage = null

    this.enterSends = this.el.dataset.enterSends !== "false"

    this.textarea.addEventListener("keydown", (e) => {
      // Trigger typing on printable characters
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

      // Escape to cancel edit/emoji
      if (e.key === "Escape") {
        this.hideEmojiPanel()
        if (window.chatEditingMessage) {
          window.chatEditingMessage = null
          this.textarea.value = ""
          this.textarea.style.height = "auto"
          this.pushEvent("cancel_edit", {})
        }
        return
      }

      // Up arrow to edit last message (when textarea is empty and not in edit mode)
      if (e.key === "ArrowUp" && this.textarea.value.trim() === "" && !window.chatEditingMessage) {
        e.preventDefault()
        this.editLastMessage()
        return
      }
    })

    // Typing detection on input (for paste, delete, mobile input)
    this.textarea.addEventListener("input", () => {
      this.textarea.style.height = "auto"
      const maxHeight = parseInt(getComputedStyle(this.textarea).maxHeight, 10) || 128
      this.textarea.style.height = Math.min(this.textarea.scrollHeight, maxHeight) + "px"
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

    if (this.imageBtn && this.imageInput) {
      this.imageBtn.addEventListener("click", () => this.imageInput.click())
      this.imageInput.addEventListener("change", (e) => this.handleImageSelect(e))
    }

    if (this.imagePreview) {
      // Use event delegation so the listener survives LiveView DOM patches
      this.imagePreview.addEventListener("click", (e) => {
        if (e.target.closest("#chat-image-cancel")) {
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

    this.textarea.focus()

    this.handleEvent("focus_chat_input", () => {
      this.textarea.scrollIntoView({ behavior: "smooth", block: "end" })
      setTimeout(() => this.textarea.focus(), 50)
    })
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

    // Validate type
    if (!file.type.startsWith("image/")) {
      alert("Please select an image file.")
      return
    }

    // Validate size (5MB)
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
    // Debounce: don't send more than once per TYPING_SEND_DEBOUNCE ms
    if (now - this.lastTypingSent < TYPING_SEND_DEBOUNCE) return

    if (!this.typingSent) {
      console.log("[ChatInput] Sending typing: true")
      this.pushEvent("set_typing", { typing: true })
      this.typingSent = true
    }
    this.lastTypingSent = now

    // Clear previous timer
    if (this.typingTimer) clearTimeout(this.typingTimer)

    // Stop typing after delay
    this.typingTimer = setTimeout(() => {
      console.log("[ChatInput] Sending typing: false")
      this.pushEvent("set_typing", { typing: false })
      this.typingSent = false
    }, TYPING_DELAY)
  },

  editLastMessage() {
    // Find the last message from current user that is editable
    const currentUserId = document.getElementById("chat-wrapper")?.dataset.currentUserId
    const messages = document.querySelectorAll("[data-msg-id]")

    // Iterate in reverse to find the last editable message
    for (let i = messages.length - 1; i >= 0; i--) {
      const msgEl = messages[i]
      const bubble = msgEl.closest(".message-bubble")

      // Skip deleted messages, voice messages, and messages from others
      if (bubble && bubble.textContent.includes("This message was deleted")) continue
      if (msgEl.closest("[data-encrypted='true']")) {
        // Check if this is a voice message (look for audio in the bubble)
        if (bubble && bubble.querySelector(".chat-audio-el")) continue
      }

      // Find the edit button for this message
      const msgId = msgEl.dataset.msgId
      const editBtn = document.querySelector(`button[phx-click='start_edit'][phx-value-id='${msgId}']`)
      if (editBtn) {
        editBtn.click()
        return
      }
    }
  },

  toggleEmojiPanel() {
    if (!this.emojiPanel) return
    if (this.emojiPanel.classList.contains("hidden")) {
      this.emojiPanel.classList.remove("hidden")
      this.resetEmojiPage()
    } else {
      this.emojiPanel.classList.add("hidden")
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
    const text = this.textarea.value.trim()
    const hasImage = this.queuedImage != null

    if (text === "" && !hasImage) return

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

    // Stop typing indicator on send
    if (this.typingTimer) {
      clearTimeout(this.typingTimer)
      this.typingTimer = null
    }
    if (this.typingSent) {
      console.log("[ChatInput] Sending typing: false (message sent)")
      this.pushEvent("set_typing", { typing: false })
      this.typingSent = false
    }

    const convId = this.convId || document.getElementById("chat-wrapper")?.dataset.conversationId
    if (!convId) {
      console.error("[ChatInput] No conversation ID found")
      return
    }

    if (!CryptoState.ready) {
      console.error("[ChatInput] Encryption not ready")
      return
    }

    // Check if we're in edit mode
    if (window.chatEditingMessage) {
      const edit = window.chatEditingMessage
      window.chatEditingMessage = null
      try {
        const { ciphertext, iv } = await CryptoState.encrypt(convId, text)
        this.pushEvent("edit_message", { ciphertext, iv, message_id: edit.message_id })
      } catch (e) {
        console.error("[ChatInput] Encryption failed:", e)
        return
      }
      this.textarea.value = ""
      this.textarea.style.height = "auto"
      this.textarea.focus()
      return
    }

    // If no conversation key, request one and queue the message
    if (!CryptoState.conversationKeys.has(convId)) {
      if (hasImage) {
        alert("Please wait for encryption to be ready before sending images.")
        return
      }
      window.chatPendingMessage = text
      this.pushEvent("ensure_conversation_key", {})
      return
    }

    // Send image first, then text (both if present)
    if (hasImage) {
      try {
        const { ciphertext, iv } = await CryptoState.encrypt(convId, "📷 Image")
        const base64 = this._base64FromDataUrl(this.queuedImage.dataUrl)
        this.pushEvent("send_image_message", {
          image_base64: base64,
          mime_type: this.queuedImage.mimeType,
          ciphertext,
          iv
        })
        this.clearImage()
      } catch (e) {
        console.error("[ChatInput] Image encryption failed:", e)
        return
      }
    }

    if (text) {
      try {
        const { ciphertext, iv } = await CryptoState.encrypt(convId, text)
        this.pushEvent("send_encrypted_message", { ciphertext, iv })
      } catch (e) {
        console.error("[ChatInput] Encryption failed:", e)
        return
      }
    }

    this.textarea.value = ""
    this.textarea.style.height = "auto"
    this.textarea.focus()
  }
}

function isSingleKanji(str) {
  if (str.length !== 1) return false
  const code = str.codePointAt(0)
  return (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3400 && code <= 0x4DBF)
}

export default ChatInput
