import { formatLocalTimes } from "./format_local_time"

const ChatScroll = {
  mounted() {
    // Delay slightly to ensure flex layout is resolved before scrolling
    requestAnimationFrame(() => this.scrollToBottom())
    formatLocalTimes(this.el)

    this.handleEvent("scroll_to_bottom", () => {
      this.scrollToBottom()
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
  }
}

export default ChatScroll
