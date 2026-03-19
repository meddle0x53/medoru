// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/medoru"
import topbar from "../vendor/topbar"
import KanjiWriting from "./hooks/kanji_writing"
import StepSorter from "./hooks/step_sorter"
import OptionInput from "./hooks/option_input"
import Timer from "./hooks/timer"
import AutoDismiss from "./hooks/auto_dismiss"
import StrokeAnimator from "./hooks/stroke_animator"

// Make KanjiRecognizer available globally for hooks
import { KanjiWriter, KanjiVGParser } from "../vendor/kanji-recognizer-bundle.js"
window.KanjiWriter = KanjiWriter
window.KanjiVGParser = KanjiVGParser

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, KanjiWriting, StepSorter, OptionInput, Timer, AutoDismiss, StrokeAnimator},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Handle locale setting from LiveView
window.addEventListener("phx:set_locale", e => {
  const locale = e.detail.locale
  if (locale) {
    // Set cookie for 1 year
    const expires = new Date()
    expires.setFullYear(expires.getFullYear() + 1)
    document.cookie = `medoru_locale=${locale};expires=${expires.toUTCString()};path=/;SameSite=Lax`
  }
})

// Handle data export download
window.addEventListener("phx:download-data", e => {
  const { filename, content } = e.detail
  const blob = new Blob([content], { type: 'application/json' })
  const url = window.URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  window.URL.revokeObjectURL(url)
  document.body.removeChild(a)
})

// Cookie Consent Management
const COOKIE_CONSENT_KEY = 'medoru_cookie_consent'

function getCookieConsent() {
  const match = document.cookie.match(new RegExp('(^| )' + COOKIE_CONSENT_KEY + '=([^;]+)'))
  return match ? match[2] : null
}

function setCookieConsent(consent) {
  const expires = new Date()
  expires.setFullYear(expires.getFullYear() + 1)
  document.cookie = `${COOKIE_CONSENT_KEY}=${consent};expires=${expires.toUTCString()};path=/;SameSite=Lax`
}

function showCookieBanner() {
  const banner = document.getElementById('cookie-banner')
  if (banner) {
    banner.classList.remove('hidden')
  }
}

function hideCookieBanner() {
  const banner = document.getElementById('cookie-banner')
  if (banner) {
    banner.classList.add('hidden')
  }
}

function initCookieConsent() {
  const consent = getCookieConsent()
  if (!consent) {
    showCookieBanner()
  } else {
    hideCookieBanner()
  }

  // Accept button
  const acceptBtn = document.getElementById('cookie-accept')
  if (acceptBtn) {
    acceptBtn.addEventListener('click', () => {
      setCookieConsent('accepted')
      hideCookieBanner()
    })
  }

  // Reject button
  const rejectBtn = document.getElementById('cookie-reject')
  if (rejectBtn) {
    rejectBtn.addEventListener('click', () => {
      setCookieConsent('rejected')
      hideCookieBanner()
    })
  }
}

// Initialize on initial page load
document.addEventListener('DOMContentLoaded', initCookieConsent)

// Re-initialize after LiveView navigation
window.addEventListener('phx:page-loading-stop', initCookieConsent)

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

