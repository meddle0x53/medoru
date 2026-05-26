/**
 * Format timestamps to browser-local time.
 * Finds all [data-local-time] elements within a container and formats them.
 */
export function formatLocalTimes(container) {
  if (!container) return

  const elements = container.querySelectorAll("[data-local-time]")
  elements.forEach((el) => {
    const iso = el.getAttribute("data-local-time")
    if (!iso) return

    const d = new Date(iso)
    if (isNaN(d)) return

    const isDate = el.getAttribute("data-local-time-type") === "date"
    const opts = isDate
      ? { year: "numeric", month: "long", day: "numeric" }
      : { hour: "2-digit", minute: "2-digit", hour12: false }

    el.textContent = new Intl.DateTimeFormat(undefined, opts).format(d)
  })
}
