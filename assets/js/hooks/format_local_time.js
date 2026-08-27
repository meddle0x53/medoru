/**
 * Format timestamps to browser-local time.
 * Finds all [data-local-time] elements within a container and formats them.
 */
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

export function formatLocalTimes(container) {
  if (!container) return

  const elements = container.querySelectorAll("[data-local-time]")
  elements.forEach((el) => {
    const iso = el.getAttribute("data-local-time")
    if (!iso) return

    const d = new Date(iso)
    if (isNaN(d)) return

    const isDate = el.getAttribute("data-local-time-type") === "date"
    if (isDate) {
      el.textContent = new Intl.DateTimeFormat(undefined, {
        year: "numeric",
        month: "long",
        day: "numeric"
      }).format(d)
    } else {
      el.textContent = formatLocalDateTime(d)
    }
  })
}
