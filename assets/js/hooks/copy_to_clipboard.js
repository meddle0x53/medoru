const CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const text = this.el.dataset.text
      if (!text) {
        console.warn("CopyToClipboard: no data-text attribute")
        return
      }

      const showCopied = () => {
        const original = this.el.innerHTML
        this.el.innerHTML = `<span class="text-success flex items-center gap-1"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4"><path fill-rule="evenodd" d="M19.916 4.626a.75.75 0 0 1 .208 1.04l-9 13.5a.75.75 0 0 1-1.154.114l-6-6a.75.75 0 0 1 1.06-1.06l5.353 5.353 8.493-12.739a.75.75 0 0 1 1.04-.208Z" clip-rule="evenodd" /></svg> Copied!</span>`
        setTimeout(() => {
          this.el.innerHTML = original
        }, 2000)
      }

      const showFailed = () => {
        const original = this.el.innerHTML
        this.el.innerHTML = `<span class="text-error text-sm">Failed</span>`
        setTimeout(() => {
          this.el.innerHTML = original
        }, 2000)
      }

      // Try modern Clipboard API first
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(showCopied).catch((err) => {
          console.warn("Clipboard API failed, trying fallback:", err)
          // Fallback to execCommand
          if (this.copyWithExecCommand(text)) {
            showCopied()
          } else {
            showFailed()
          }
        })
      } else {
        // Fallback for browsers without Clipboard API
        if (this.copyWithExecCommand(text)) {
          showCopied()
        } else {
          showFailed()
        }
      }
    })
  },

  copyWithExecCommand(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.left = "-9999px"
    textarea.style.top = "0"
    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()
    try {
      const successful = document.execCommand("copy")
      document.body.removeChild(textarea)
      return successful
    } catch (err) {
      document.body.removeChild(textarea)
      console.error("execCommand copy failed:", err)
      return false
    }
  }
}

export default CopyToClipboard
