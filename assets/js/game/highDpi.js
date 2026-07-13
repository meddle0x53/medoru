/**
 * High-DPI helper for Phaser 4.
 *
 * The game canvas is created at physical resolution (960*PX × 540*PX) while the
 * logical design stays 960×540. The main camera is zoomed by PX and scrolled so
 * the design fills the physical canvas. Phaser's FIT scale mode then scales the
 * whole canvas down to the displayed size, giving crisp pixels on DPR > 1 screens.
 */

const DESIGN_WIDTH = 960
const DESIGN_HEIGHT = 540

export function getGamePX() {
  if (typeof window === 'undefined') return 1
  if (window.GAME_PX) return window.GAME_PX

  const dpr = window.devicePixelRatio || 1
  // Cap at 2 to keep fill-rate reasonable. Devices with DPR > 2 still get
  // a crisp 2× render.
  let maxPx = 2
  // Phones have very high DPR but small screens; rendering at 2× is too heavy
  // for the GPU and drains battery. Drop to 1× on small screens.
  if (typeof window.screen !== 'undefined') {
    const minScreenDim = Math.min(window.screen.width, window.screen.height)
    if (minScreenDim < 720) {
      maxPx = 1
    }
  }
  const px = Math.max(1, Math.min(maxPx, Math.round(dpr)))
  window.GAME_PX = px
  return px
}

export function getPhysicalSize() {
  const px = getGamePX()
  return {
    width: DESIGN_WIDTH * px,
    height: DESIGN_HEIGHT * px,
  }
}

function applyHighDPI(cam, px) {
  if (px > 1) {
    cam.setZoom(px)
    cam.setViewport(0, 0, DESIGN_WIDTH * px, DESIGN_HEIGHT * px)
    // With zoom > 1 the camera is centered on the middle of the world by default.
    // Scroll back so the 960×540 design area starts at the top-left of the viewport.
    cam.setScroll(
      -(DESIGN_WIDTH * (px - 1)) / 2,
      -(DESIGN_HEIGHT * (px - 1)) / 2,
    )
  } else {
    cam.setZoom(1)
    cam.setViewport(0, 0, DESIGN_WIDTH, DESIGN_HEIGHT)
    cam.setScroll(0, 0)
  }
}

/**
 * Zooms and scrolls the scene's main camera so logical 960×540 coordinates map
 * to the physical-resolution canvas.
 *
 * Call this once at the top of a scene's create() method.
 */
export function setupHighDPIWorld(scene) {
  const px = getGamePX()
  const cam = scene.cameras.main

  applyHighDPI(cam, px)

  // Re-apply after any Scale Manager resize (e.g. entering/exiting fullscreen).
  const handler = () => applyHighDPI(cam, getGamePX())
  scene.scale.on('resize', handler)
  scene.events.once('shutdown', () => {
    scene.scale.off('resize', handler)
  })
}
