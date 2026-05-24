import { CryptoState } from "./chat_crypto"

const ChatInput = {
  mounted() {
    this.textarea = this.el.querySelector("textarea")
    this.sendButton = this.el.querySelector("#chat-send-button")
    this.convId = document.getElementById("chat-wrapper")?.dataset.conversationId

    if (!this.textarea) return

    this.textarea.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.submit()
      }
    })

    if (this.sendButton) {
      this.sendButton.addEventListener("click", () => this.submit())
    }

    this.textarea.addEventListener("input", () => {
      this.textarea.style.height = "auto"
      this.textarea.style.height = Math.min(this.textarea.scrollHeight, 128) + "px"
    })

    this.textarea.focus()
  },

  async submit() {
    const text = this.textarea.value.trim()
    if (text === "") return

    const convId = this.convId || document.getElementById("chat-wrapper")?.dataset.conversationId
    if (!convId) {
      console.error("[ChatInput] No conversation ID found")
      return
    }

    if (!CryptoState.ready) {
      console.error("[ChatInput] Encryption not ready")
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
