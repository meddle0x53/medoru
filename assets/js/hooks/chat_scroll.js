import { formatLocalTimes } from "./format_local_time"
import { CryptoState } from "./chat_crypto"

const ChatScroll = {
  mounted() {
    // Delay slightly to ensure flex layout is resolved before scrolling
    requestAnimationFrame(() => this.scrollToBottom())
    formatLocalTimes(this.el)

    this.handleEvent("scroll_to_bottom", () => {
      this.scrollToBottom()
    })

    this.handleEvent("jump_to_message", ({ message_id }) => {
      const el = document.getElementById("msg-" + message_id)
      if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "center" })
        el.classList.add("highlight-message")
        setTimeout(() => el.classList.remove("highlight-message"), 2000)
      }
    })

    // Scroll when async content (e.g. word/kanji previews) finishes loading
    this._contentLoadedHandler = () => {
      const threshold = 150
      const distanceFromBottom = this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight
      if (distanceFromBottom < threshold) {
        this.scrollToBottom()
      }
    }
    this.el.addEventListener("chat:content-loaded", this._contentLoadedHandler)

    // Message menu handling (event delegation)
    this._menuHandler = (e) => {
      const menuBtn = e.target.closest(".message-menu-btn")
      if (menuBtn) {
        e.stopPropagation()
        const msgId = menuBtn.dataset.messageId
        const dropdown = this.el.querySelector(`.message-menu-dropdown[data-message-id="${msgId}"]`)
        if (dropdown) {
          // Close all other menus first
          this.el.querySelectorAll(".message-menu-dropdown").forEach(d => {
            if (d !== dropdown) d.classList.add("hidden")
          })
          dropdown.classList.toggle("hidden")
        }
        return
      }

      const dictAction = e.target.closest("[data-action='add-to-dictionary']")
      if (dictAction) {
        e.stopPropagation()
        const msgId = dictAction.dataset.messageId
        if (msgId) this.addMessageToDictionary(msgId)
        this.el.querySelectorAll(".message-menu-dropdown").forEach(d => d.classList.add("hidden"))
        return
      }

      // Close menus when clicking outside
      const menuDropdown = e.target.closest(".message-menu-dropdown")
      if (!menuDropdown) {
        this.el.querySelectorAll(".message-menu-dropdown").forEach(d => d.classList.add("hidden"))
      }
    }

    this.el.addEventListener("click", this._menuHandler)
  },

  updated() {
    // Only auto-scroll if the user is already near the bottom.
    // This prevents jumping when the user is reading older messages.
    const threshold = 150
    const distanceFromBottom = this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight
    if (distanceFromBottom < threshold) {
      this.scrollToBottom()
    }
    formatLocalTimes(this.el)
  },

  destroyed() {
    if (this._menuHandler) {
      this.el.removeEventListener("click", this._menuHandler)
    }
    if (this._contentLoadedHandler) {
      this.el.removeEventListener("chat:content-loaded", this._contentLoadedHandler)
    }
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  },

  async addMessageToDictionary(messageId) {
    const contentEl = document.getElementById(`msg-content-${messageId}`)
    if (!contentEl) return

    let content = ""

    if (contentEl.dataset.encrypted === "true") {
      const ciphertext = contentEl.dataset.ciphertext
      const iv = contentEl.dataset.iv
      const wrapper = document.getElementById("chat-wrapper")
      const convId = wrapper?.dataset.conversationId

      if (ciphertext && iv && convId && CryptoState.ready) {
        try {
          content = await CryptoState.decrypt(convId, ciphertext, iv)
        } catch (e) {
          console.error("[ChatScroll] Failed to decrypt message for dictionary:", e)
          return
        }
      }
    } else {
      content = contentEl.textContent || ""
    }

    content = content.trim()
    if (!content) return

    this.pushEvent("add_message_to_dictionary", { message_id: messageId, content })
  }
}

export default ChatScroll
