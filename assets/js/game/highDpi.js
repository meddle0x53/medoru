/**
 * High-DPI helper for Phaser 4.
 *
 * NOTE: High-DPI rendering is currently disabled while we stabilize the game.
 * `getGamePX()` returns 1, so the game renders at the design resolution 960×540.
 * The helper is kept in place so it can be re-enabled later.
 */

const DESIGN_WIDTH = 960
const DESIGN_HEIGHT = 540

export function getGamePX() {
  // Temporarily disabled. Change this to use window.devicePixelRatio to re-enable.
  return 1
}

export function getPhysicalSize() {
  const px = getGamePX()
  return {
    width: DESIGN_WIDTH * px,
    height: DESIGN_HEIGHT * px,
  }
}

/**
 * Zooms and resizes the scene's main camera so logical 960×540 coordinates map
 * to the physical-resolution canvas.
 *
 * With high-DPI disabled this is a no-op.
 */
export function setupHighDPIWorld(scene) {
  const px = getGamePX()
  if (px > 1) {
    const cam = scene.cameras.main
    cam.setZoom(px)
    cam.setViewport(0, 0, DESIGN_WIDTH * px, DESIGN_HEIGHT * px)
  }
}
