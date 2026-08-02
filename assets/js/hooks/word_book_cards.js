// Equalizes the height of every word-book card in the container so all
// cards in the book render at the SAME size. Each card's own aspect
// ratio (square / 5:7) still acts as the minimum size — the tallest
// card's content wins and every other card stretches to match.
const WordBookCards = {
  mounted() {
    this.equalize = () => {
      const cards = Array.from(this.el.querySelectorAll(".word-book-card-inner"))
      if (cards.length === 0) return

      cards.forEach((card) => {
        card.style.height = ""
      })

      // Square books: strict 1:1 is enforced in pure CSS
      // (.word-book-card-inner.aspect-square) — nothing to do here.
      if (this.el.dataset.cardShape === "square") return

      // Rectangle books: the tallest card's content wins and every other
      // card stretches to match (aspect ratio stays the minimum).
      const max = Math.max(...cards.map((card) => card.offsetHeight))
      cards.forEach((card) => {
        const target = `${max}px`
        if (card.style.height !== target) card.style.height = target
      })
    }

    // Debounce via rAF so bursts of resize/mutation events collapse.
    this.schedule = () => {
      if (this.frame) cancelAnimationFrame(this.frame)
      this.frame = requestAnimationFrame(this.equalize)
    }

    this.observer = new ResizeObserver(this.schedule)
    // Only the container is observed (width changes). The cards we resize
    // are deliberately NOT observed — reacting to our own writes would
    // feedback-loop. Content changes arrive via updated() and image loads.
    this.observer.observe(this.el)

    // Word images load asynchronously and can change a card's height.
    this.el.addEventListener("load", this.schedule, true)

    this.schedule()
  },

  updated() {
    this.schedule()
  },

  destroyed() {
    if (this.frame) cancelAnimationFrame(this.frame)
    if (this.observer) this.observer.disconnect()
  }
}

export default WordBookCards
