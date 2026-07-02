/**
 * Lock the game wrapper in its current on-screen position while a mobile
 * virtual keyboard is open. This prevents the keyboard from scrolling or
 * pushing the game canvas up.
 */

const LOCK_CLASS = 'game-keyboard-open'

function isMobile() {
  return window.matchMedia('(pointer: coarse)').matches
}

export function lockGameWrapper() {
  if (!isMobile()) return
  const wrapper = document.getElementById('game-wrapper')
  if (!wrapper || document.body.classList.contains(LOCK_CLASS)) return

  const rect = wrapper.getBoundingClientRect()
  wrapper.style.setProperty('--gk-top', `${rect.top}px`)
  wrapper.style.setProperty('--gk-left', `${rect.left}px`)
  wrapper.style.setProperty('--gk-width', `${rect.width}px`)
  wrapper.style.setProperty('--gk-height', `${rect.height}px`)
  document.body.classList.add(LOCK_CLASS)
}

export function unlockGameWrapper() {
  document.body.classList.remove(LOCK_CLASS)
}
