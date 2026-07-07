import { toPng } from "html-to-image"

const ShareAsPicture = {
  mounted() {
    this.el.addEventListener("click", async (e) => {
      e.preventDefault()

      const target = this.el.closest("[data-share-picture]")
      if (!target) {
        console.warn("ShareAsPicture: no [data-share-picture] container found")
        window.alert("Share picture is not available for this step.")
        return
      }

      const filename = this.el.dataset.filename || "medoru-question.png"
      const originalHTML = this.el.innerHTML
      const themedAncestor = target.closest("[data-theme]")
      const inheritedTheme = themedAncestor && themedAncestor.getAttribute("data-theme")
      const hadTheme = target.hasAttribute("data-theme")

      if (inheritedTheme && !hadTheme) {
        target.setAttribute("data-theme", inheritedTheme)
      }

      this.el.disabled = true
      this.el.innerHTML = `<span class="loading loading-spinner loading-xs"></span>`

      try {
        const dataUrl = await toPng(target, {
          pixelRatio: 2,
          backgroundColor: "#ffffff",
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
      }
    })
  }
}

export default ShareAsPicture
