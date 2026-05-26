// Global time formatter — no hook needed.
// Watches the document for [data-local-time] elements and formats them
// using the browser's local timezone.

function formatLocalTime(el) {
  const iso = el.dataset.localTime
  if (!iso || el.dataset.localTimeFormatted) return

  const date = new Date(iso)
  if (isNaN(date)) return

  const isDate = el.dataset.localTimeType === "date"
  const formatter = new Intl.DateTimeFormat(undefined, isDate
    ? { year: "numeric", month: "long", day: "numeric" }
    : { hour: "2-digit", minute: "2-digit", hour12: false }
  )

  el.textContent = formatter.format(date)
  el.dataset.localTimeFormatted = "true"
}

export function initLocalTime() {
  // Format all existing elements
  document.querySelectorAll("[data-local-time]").forEach(formatLocalTime)

  // Watch for new elements added by LiveView
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          if (node.matches && node.matches("[data-local-time]")) {
            formatLocalTime(node)
          }
          if (node.querySelectorAll) {
            node.querySelectorAll("[data-local-time]").forEach(formatLocalTime)
          }
        }
      }
    }
  })

  observer.observe(document.body, { childList: true, subtree: true })
}
