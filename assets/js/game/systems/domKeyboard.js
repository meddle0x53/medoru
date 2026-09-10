// DOM-level touch keyboard binding.
//
// Binds pointerdown directly on the game canvas and hit-tests keys in design
// coordinates (960x540). This bypasses Phaser's input-manager pipeline,
// which adds a consistently perceptible delay to per-tap feedback on some
// Android touch devices (measured 100ms+ on a Redmagic Astra while other
// game buttons felt instant). DOM pointerdown handlers run synchronously in
// the browser's input dispatch, so the key highlight and typed letter appear
// in the very next rendered frame.
//
// Keys are described by their world-space bounds (Phaser getBounds()), so
// parent containers/overlay offsets and camera zoom are already accounted for.

import { GAME_CONFIG } from '../config.js'

/**
 * @param {Phaser.Scene} scene
 * @param {Array} keys [{ getBounds(): {x,y,width,height}, onPress(e), enabled?: () => bool }]
 * @param {object} opts { isActive?: () => boolean }  overall gate (e.g. keyboard visible)
 * @returns {() => void} unbind
 */
export function bindDomKeyboard(scene, keys, opts = {}) {
  const canvas = scene.sys.game.canvas
  if (!canvas) return () => {}

  const onPointerDown = (e) => {
    if (opts.isActive && !opts.isActive()) return
    const rect = canvas.getBoundingClientRect()
    if (!rect.width || !rect.height) return
    const gx = ((e.clientX - rect.left) / rect.width) * GAME_CONFIG.width
    const gy = ((e.clientY - rect.top) / rect.height) * GAME_CONFIG.height

    // Topmost key wins: later entries render on top.
    for (let i = keys.length - 1; i >= 0; i--) {
      const k = keys[i]
      if (k.enabled && !k.enabled()) continue
      let b
      try {
        b = k.getBounds()
      } catch (_) {
        continue // key's scene/objects already destroyed
      }
      if (!b) continue
      if (gx >= b.x && gx <= b.x + b.width && gy >= b.y && gy <= b.y + b.height) {
        k.onPress(e)
        return
      }
    }
  }

  canvas.addEventListener('pointerdown', onPointerDown)
  return () => canvas.removeEventListener('pointerdown', onPointerDown)
}

// Shared release-visual helper: call onPress visuals on pointerdown and reset
// them on the next window pointerup (covers drag-off and multi-key presses).
export function bindPressRelease(onPressVisual, onReleaseVisual) {
  const release = () => {
    onReleaseVisual()
    window.removeEventListener('pointerup', release)
    window.removeEventListener('pointercancel', release)
  }
  onPressVisual()
  window.addEventListener('pointerup', release)
  window.addEventListener('pointercancel', release)
}
