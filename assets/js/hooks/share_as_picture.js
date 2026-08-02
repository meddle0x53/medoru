import { toPng } from "../../vendor/html-to-image.js"

const ShareAsPicture = {
  mounted() {
    this.el.addEventListener("click", async (e) => {
      e.preventDefault()

      const frontId = this.el.dataset.shareFront
      const backId = this.el.dataset.shareBack
      let explicitTargetId = this.el.dataset.shareTarget
      let filename = this.el.dataset.filename || "medoru-question.png"

      // Flip-aware card button: one button downloads whichever face is
      // currently visible (front unless the card is flipped).
      if (frontId && backId) {
        const frontEl = document.getElementById(frontId)
        const inner = frontEl && frontEl.closest(".word-book-card-inner")
        const flipped = inner && inner.classList.contains("word-book-card-flipped")
        explicitTargetId = flipped ? backId : frontId
        filename = `${filename}-${flipped ? "back" : "front"}.png`
      }

      const target = explicitTargetId
        ? document.getElementById(explicitTargetId)
        : this.el.closest("[data-share-picture]")
      if (!target) {
        console.warn("ShareAsPicture: no [data-share-picture] container found")
        window.alert("Share picture is not available for this step.")
        return
      }
      const originalHTML = this.el.innerHTML
      const themedAncestor = target.closest("[data-theme]")
      const inheritedTheme = themedAncestor && themedAncestor.getAttribute("data-theme")
      const hadTheme = target.hasAttribute("data-theme")

      if (inheritedTheme && !hadTheme) {
        target.setAttribute("data-theme", inheritedTheme)
      }

      // When an explicit target is given (e.g. a word-book card face), it may
      // be hidden by 3D flip transforms. Neutralize them during capture.
      const flipInner = explicitTargetId && target.closest(".word-book-card-inner")
      const flipStyles = []

      if (flipInner) {
        flipStyles.push([flipInner, flipInner.style.cssText])
        flipInner.style.transform = "none"
        flipStyles.push([target, target.style.cssText])
        target.style.transform = "none"
        target.style.backfaceVisibility = "visible"
      }

      // Tailwind v4 / daisyUI define their palette as CSS custom properties on
      // :root and on [data-theme] containers. html-to-image clones the target
      // into a detached fragment where those selectors no longer match, so
      // var(--color-*) would resolve to nothing and the export loses all theme
      // colors. Copy the resolved custom properties from the nearest themed
      // ancestor (e.g. the word-book viewer carrying the BOOK's theme, not the
      // site-wide one on <html>) onto the target so they survive the clone.
      const copiedVars = []

      if (explicitTargetId) {
        const themeSource = target.closest("[data-theme]") || document.documentElement
        const rootStyles = getComputedStyle(themeSource)
        for (const name of rootStyles) {
          if (name.startsWith("--")) {
            copiedVars.push([name, target.style.getPropertyValue(name)])
            target.style.setProperty(name, rootStyles.getPropertyValue(name))
          }
        }
      }

      const backgroundColor = explicitTargetId
        ? getComputedStyle(target).backgroundColor
        : "#ffffff"

      this.el.disabled = true
      this.el.innerHTML = `<span class="loading loading-spinner loading-xs"></span>`

      try {
        const dataUrl = await toPng(target, {
          pixelRatio: 2,
          backgroundColor: backgroundColor,
          filter: (node) => !node.hasAttribute || !node.hasAttribute("data-share-exclude")
        })
        const link = document.createElement("a")
        link.download = filename
        link.href = dataUrl
        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)
      } catch (err) {
        console.error("ShareAsPicture failed:", err)
        window.alert("Could not create picture: " + (err.message || "unknown error"))
      } finally {
        this.el.disabled = false
        this.el.innerHTML = originalHTML

        if (inheritedTheme && !hadTheme) {
          target.removeAttribute("data-theme")
        }

        for (const [el, cssText] of flipStyles) {
          el.style.cssText = cssText
        }

        for (const [name, previous] of copiedVars) {
          if (previous) {
            target.style.setProperty(name, previous)
          } else {
            target.style.removeProperty(name)
          }
        }
      }
    })
  }
}

export default ShareAsPicture
