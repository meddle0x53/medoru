/**
 * WordColorApplyTo Hook
 *
 * Sends word color "apply_to" changes with the color index and field metadata.
 * LiveView's default phx-change for <select> does not read phx-value-* from the
 * element itself, so this hook pushes the event manually with the required
 * context.
 */
const WordColorApplyTo = {
  mounted() {
    this.handleChange = () => {
      this.pushEvent(this.el.dataset.event, {
        index: this.el.dataset.index,
        field: "apply_to",
        apply_to: this.el.value
      })
    }

    this.el.addEventListener("change", this.handleChange)
  },

  destroyed() {
    this.el.removeEventListener("change", this.handleChange)
  }
}

export default WordColorApplyTo
