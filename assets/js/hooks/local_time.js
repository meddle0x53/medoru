// Global time formatter — no hook needed.
// Watches the document for [data-local-time] elements and formats them
// using the browser's local timezone.

function isToday(date) {
  const now = new Date()
  return (
    date.getDate() === now.getDate() &&
    date.getMonth() === now.getMonth() &&
    date.getFullYear() === now.getFullYear()
  )
}

function formatLocalDateTime(date) {
  const day = String(date.getDate()).padStart(2, "0")
  const month = String(date.getMonth() + 1).padStart(2, "0")
  const year = String(date.getFullYear()).slice(-2)
  const time = new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  }).format(date)

  if (isToday(date)) {
    return time
  }

  return `${day}.${month}.${year} ${time}`
}

function formatLocalTime(el) {
  const iso = el.dataset.localTime
  if (!iso || el.dataset.localTimeFormatted) return

  const date = new Date(iso)
  if (isNaN(date)) return

  const isDate = el.dataset.localTimeType === "date"
  if (isDate) {
    el.textContent = new Intl.DateTimeFormat(undefined, {
      year: "numeric",
      month: "long",
      day: "numeric"
    }).format(date)
  } else {
    el.textContent = formatLocalDateTime(date)
  }

  el.dataset.localTimeFormatted = "true"
}

let localTimeObserver = null

export function initLocalTime() {
  // Format all existing elements
  document.querySelectorAll("[data-local-time]").forEach(formatLocalTime)

  if (localTimeObserver) return

  // Watch for new elements added by LiveView
  localTimeObserver = new MutationObserver((mutations) => {
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
