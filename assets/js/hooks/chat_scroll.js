import { formatLocalTimes } from "./format_local_time"

const ChatScroll = {
  mounted() {
    this.scrollToBottom()
    formatLocalTimes(this.el)

    // Observe child list changes to auto-scroll
    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
    })

    this.observer.observe(this.el, { childList: true, subtree: true })

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
    this.scrollToBottom()
    formatLocalTimes(this.el)
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this._menuHandler) {
      this.el.removeEventListener("click", this._menuHandler)
    }
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

export default ChatScroll
