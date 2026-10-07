import { PageFlip } from "page-flip"

// Full-page presentation flipbook for word books (StPageFlip).
// Server-rendered .wb-page elements inside #word-book-flipbook become the
// pages; one card face per page plus a cover. Portrait = single page,
// landscape = two-page spread (usePortrait), recomputed on resize and
// orientation change.
const WordBookPresent = {
  mounted() {
    this.viewportEl = this.el.querySelector(".wb-flipbook-viewport")
    this.flipbookEl = this.el.querySelector("#word-book-flipbook")
    this.pageIndex = 0
    this.initFlipbook()

    this.printBtn = this.el.querySelector("#wb-print-btn")
    if (this.printBtn) {
      this.onPrintClick = () => this.printWhenReady()
      this.printBtn.addEventListener("click", this.onPrintClick)
    }

    // Start fetching print-section images as soon as the book opens, so
    // printing is usually instant by the time the user hits the button.
    this.preloadPrintImages()

    // Arrow buttons live outside the flipbook block that StPageFlip
    // destroys/rebuilds, so binding once here survives re-inits.
    this.prevBtn = this.el.querySelector("#wb-prev-btn")
    this.nextBtn = this.el.querySelector("#wb-next-btn")
    if (this.prevBtn) {
      this.prevBtn.addEventListener("click", () => {
        if (this.flipbook) this.flipbook.flipPrev()
      })
    }
    if (this.nextBtn) {
      this.nextBtn.addEventListener("click", () => {
        if (this.flipbook) this.flipbook.flipNext()
      })
    }

    this.onResize = this.debounce(() => this.reinitFlipbook(), 200)
    window.addEventListener("resize", this.onResize)
    window.addEventListener("orientationchange", this.onResize)

    // Keyboard page turning. Bound once here; the handler reads the current
    // flipbook instance from component state, so it survives the re-inits
    // triggered by resize/orientation change.
    this.onKeydown = (e) => {
      const target = e.target
      const inEditable =
        target &&
        (target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.tagName === "SELECT" ||
          target.isContentEditable)
      if (inEditable || !this.flipbook) return

      switch (e.key) {
        case "ArrowRight":
        case "ArrowDown":
        case "PageDown":
          e.preventDefault()
          this.flipbook.flipNext()
          break
        case "ArrowLeft":
        case "ArrowUp":
        case "PageUp":
          e.preventDefault()
          this.flipbook.flipPrev()
          break
      }
    }
    window.addEventListener("keydown", this.onKeydown)
  },

  reconnected() {
    // LiveView patched the DOM; rebuild the flipbook from the fresh pages.
    this.reinitFlipbook()
  },

  destroyed() {
    window.removeEventListener("resize", this.onResize)
    window.removeEventListener("orientationchange", this.onResize)
    window.removeEventListener("keydown", this.onKeydown)
    this.flipbook = null
    if (this.printBtn && this.onPrintClick) {
      this.printBtn.removeEventListener("click", this.onPrintClick)
    }
    if (this.prevBtn) this.prevBtn.replaceWith(this.prevBtn.cloneNode(true))
    if (this.nextBtn) this.nextBtn.replaceWith(this.nextBtn.cloneNode(true))
    this.destroyFlipbook()
  },

  // The browser snapshots the page when window.print() is called, so any
  // image that hasn't finished loading/decoding prints blank or partial.
  // Wait for every image in the print section (with a timeout so a broken
  // image can never hang printing), then print.
  async printWhenReady() {
    const btn = this.printBtn
    if (btn) {
      btn.disabled = true
      btn.setAttribute("aria-busy", "true")
      btn.title = "Preparing print…"
    }
    try {
      await this.whenPrintImagesReady(12000)
    } finally {
      if (btn) {
        btn.disabled = false
        btn.removeAttribute("aria-busy")
        btn.title = ""
      }
    }
    window.print()
  },

  preloadPrintImages() {
    this.printImages().forEach((img) => {
      // Print-section images are rendered with loading="eager"; assigning
      // src again is a no-op for the browser but forces a fetch if the
      // element was patched in before the fetch started.
      const src = img.getAttribute("src")
      if (src && !img.complete) {
        const preloader = new Image()
        preloader.src = src
      }
    })
  },

  printImages() {
    const section = this.el.querySelector(".wb-print")
    return section ? Array.from(section.querySelectorAll("img")) : []
  },

  whenPrintImagesReady(timeoutMs) {
    const images = this.printImages()
    const decoded = images.map((img) => {
      if (img.complete && img.naturalWidth > 0) {
        return img.decode ? img.decode().catch(() => {}) : Promise.resolve()
      }
      return new Promise((resolve) => {
        img.addEventListener("load", resolve, { once: true })
        img.addEventListener("error", resolve, { once: true })
      })
    })
    return Promise.race([
      Promise.all(decoded),
      new Promise((resolve) => setTimeout(resolve, timeoutMs)),
    ])
  },

  initFlipbook() {
    if (!this.viewportEl || !this.flipbookEl) return

    const pages = Array.from(this.flipbookEl.querySelectorAll(".wb-page"))
    if (pages.length === 0) return

    const { width, height } = this.pageSize()
    this.flipbook = new PageFlip(this.flipbookEl, {
      width: width,
      height: height,
      usePortrait: true,
      showCover: true,
      flippingTime: 700,
      maxShadowOpacity: 0.4,
      mobileScrollSupport: false,
    })
    // StPageFlip detaches the elements into its own block on init and
    // destroy() drops that block, so keep references to restore later.
    this.pages = pages
    this.flipbook.loadFromHTML(pages)
    this.flipbook.on("flip", (e) => {
      this.pageIndex = e.data
    })
    if (this.pageIndex > 0) {
      this.flipbook.flip(this.pageIndex, "manual")
    }
  },

  reinitFlipbook() {
    // Guard against a pending debounced resize firing after teardown.
    if (!this.el.isConnected) return
    this.destroyFlipbook()
    // Re-attach the page elements (removed with the lib's block) so both
    // the re-init below and any later LiveView patch see them in place.
    if (this.pages) {
      this.pages.forEach((page) => this.flipbookEl.appendChild(page))
    }
    this.initFlipbook()
  },

  destroyFlipbook() {
    if (this.flipbook) {
      this.pageIndex = this.flipbook.getCurrentPageIndex() || 0
      try {
        this.flipbook.destroy()
      } catch (_e) {
        // already destroyed
      }
      this.flipbook = null
    }
  },

  pageSize() {
    const rect = this.viewportEl.getBoundingClientRect()
    const ratio = this.el.dataset.cardShape === "square" ? 1 : 5 / 7
    let height = Math.max(200, rect.height - 16)
    let width = height * ratio
    const maxWidth = rect.width - 16
    if (width > maxWidth) {
      width = maxWidth
      height = width / ratio
    }
    return { width: Math.floor(width), height: Math.floor(height) }
  },

  debounce(fn, delay) {
    let timer = null
    return (...args) => {
      clearTimeout(timer)
      timer = setTimeout(() => fn(...args), delay)
    }
  },
}

export default WordBookPresent
