/**
 * Stroke Animator Hook
 * 
 * Automatically advances to the next stroke when the CSS animation completes.
 */
const StrokeAnimator = {
  mounted() {
    this.handleAnimationEnd = this.handleAnimationEnd.bind(this)
    this.observeStrokeAnimation()
  },

  updated() {
    // Re-observe when the component updates (new stroke becomes active)
    this.observeStrokeAnimation()
  },

  destroyed() {
    this.removeListeners()
  },

  observeStrokeAnimation() {
    // Remove any existing listeners first
    this.removeListeners()

    // Find the currently animated stroke path
    const animatedPath = this.el.querySelector('path[style*="animation: draw"]')
    
    if (animatedPath) {
      // Listen for animation end
      animatedPath.addEventListener('animationend', this.handleAnimationEnd)
      // Also listen for animationiteration in case of looping
      animatedPath.addEventListener('animationiteration', this.handleAnimationEnd)
      
      // Store reference for cleanup
      this.currentPath = animatedPath
    }
  },

  handleAnimationEnd(event) {
    // Only handle the draw animation
    if (event.animationName === 'draw') {
      // Push next event to LiveView
      this.pushEventTo(this.el, 'next', {})
    }
  },

  removeListeners() {
    if (this.currentPath) {
      this.currentPath.removeEventListener('animationend', this.handleAnimationEnd)
      this.currentPath.removeEventListener('animationiteration', this.handleAnimationEnd)
      this.currentPath = null
    }
  }
}

export default StrokeAnimator
