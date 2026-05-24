const ClassroomChatInput = {
  mounted() {
    this.textarea = this.el.querySelector("textarea")
    this.sendButton = this.el.querySelector("#classroom-chat-send-button")

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

  submit() {
    const text = this.textarea.value.trim()
    if (text === "") return

    this.pushEvent("send_message", { content: text })
    this.textarea.value = ""
    this.textarea.style.height = "auto"
    this.textarea.focus()
  }
}

export default ClassroomChatInput
