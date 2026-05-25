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
    this.convId = document.getElementById("chat-wrapper")?.dataset.conversationId

    if (!this.textarea) return

    this.typingTimer = null
    this.typingSent = false
    this.lastTypingSent = 0

    this.textarea.addEventListener("keydown", (e) => {
      // Trigger typing on printable characters
      if (e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) {
        this.sendTypingIndicator()
      }

      // Enter to send
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.submit()
        return
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

    // Close emoji panel on outside click
    this._outsideClickHandler = (e) => {
      if (this.emojiPanel && !this.emojiPanel.contains(e.target) && e.target !== this.emojiBtn) {
        this.hideEmojiPanel()
      }
    }
    document.addEventListener("click", this._outsideClickHandler)

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
    } else {
      this.emojiPanel.classList.add("hidden")
    }
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

  async submit() {
    const text = this.textarea.value.trim()
    if (text === "") return

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
      window.chatPendingMessage = text
      this.pushEvent("ensure_conversation_key", {})
      return
    }

    try {
      const { ciphertext, iv } = await CryptoState.encrypt(convId, text)
      this.pushEvent("send_encrypted_message", { ciphertext, iv })
    } catch (e) {
      console.error("[ChatInput] Encryption failed:", e)
      return
    }

    this.textarea.value = ""
    this.textarea.style.height = "auto"
    this.textarea.focus()
  }
}

export default ChatInput
