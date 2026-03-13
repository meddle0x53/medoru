/**
 * Hook for the option input field in the step builder.
 * Prevents form submission when pressing Enter in the option input,
 * and instead triggers the add_option event.
 */
export default {
  mounted() {
    this.handleKeyDown = (e) => {
      if (e.key === "Enter") {
        // Prevent form submission
        e.preventDefault()
        e.stopPropagation()

        // Only trigger if there's text
        if (this.el.value.trim() !== "") {
          // Push the event to the LiveView
          this.pushEvent("add_option", {})
        }
      }
    }

    this.el.addEventListener("keydown", this.handleKeyDown)

    // Clear input when LiveView clears the value
    this.handleEvent("clear_option_input", () => {
      this.el.value = ""
    })
  },

  destroyed() {
    this.el.removeEventListener("keydown", this.handleKeyDown)
  }
}
