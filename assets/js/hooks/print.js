// Simple print trigger: calls window.print() when the element is clicked.
// Used for "Print / Save as PDF" buttons; print visibility is handled via
// CSS classes (see .no-print / .test-results-container rules in app.css).
const PrintPage = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      window.print()
    })
  },
}

export default PrintPage
