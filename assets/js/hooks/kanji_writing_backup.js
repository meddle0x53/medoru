/**
 * Kanji Writing Hook using kanji-recognizer library
 * 
 * Provides canvas-based drawing with real-time stroke validation
 * using the mxggle/kanji-recognizer library.
 */
const KanjiWriting = {
  mounted() {
    console.log('KanjiWriting: Hook mounted')
    
    // Check if KanjiWriter is available
    if (typeof KanjiWriter === 'undefined') {
      console.error('KanjiWriting: KanjiWriter library not loaded!')
      return
    }

    // Get kanji stroke data from the component
    const strokeDataEl = this.el.querySelector('[data-stroke-data]')
    this.strokeData = []
    
    if (strokeDataEl) {
      try {
        const rawData = JSON.parse(strokeDataEl.dataset.strokeData)
        // Extract path strings from stroke data
        this.strokeData = rawData.map(stroke => stroke.path || '').filter(p => p)
        console.log('KanjiWriting: Loaded', this.strokeData.length, 'strokes')
      } catch (e) {
        console.error('KanjiWriting: Failed to parse stroke data', e)
      }
    }

    if (this.strokeData.length === 0) {
      console.error('KanjiWriting: No stroke data available')
      return
    }

    // Wait for DOM to be ready then create writer
    setTimeout(() => {
      this.initWriter()
    }, 100)
  },

  initWriter() {
    // Find the container element
    const container = this.el.querySelector('#writing-canvas-container')
    if (!container) {
      console.error('KanjiWriting: No canvas container found')
      return
    }

    // Clear any existing content
    container.innerHTML = ''

    // Create the KanjiWriter instance
    try {
      this.writer = new KanjiWriter(container, this.strokeData, {
        width: 300,
        height: 300,
        strokeColor: '#1f2937',
        correctColor: '#22c55e',
        incorrectColor: '#ef4444',
        hintColor: '#06b6d4',
        gridColor: '#e5e7eb',
        ghostColor: '#ef4444',
        showGhost: true,
        showGrid: true,
        checkMode: 'stroke',
        strokeWidth: 4,
        gridWidth: 0.5,
        ghostOpacity: '0.15',
        passThreshold: 18,
        startDistThreshold: 35,
        lengthRatioMin: 0.4,
        lengthRatioMax: 1.6
      })
      console.log('KanjiWriting: KanjiWriter created successfully')
    } catch (e) {
      console.error('KanjiWriting: Failed to create KanjiWriter', e)
      return
    }

    // Set up callbacks
    this.writer.onCorrect = () => {
      this.pushEvent('stroke_correct', {})
    }

    this.writer.onIncorrect = (result) => {
      // Clear the wrong stroke after a brief delay
      setTimeout(() => {
        this.writer.clear()
      }, 500)
      
      this.pushEvent('stroke_incorrect', { error: result.error })
    }

    this.writer.onComplete = () => {
      this.pushEvent('kanji_complete', {})
    }

    // Setup control buttons
    this.setupControls()
  },

  setupControls() {
    // Undo button
    const undoBtn = this.el.querySelector('[data-action="undo"]')
    if (undoBtn) {
      undoBtn.addEventListener('click', () => {
        this.writer.clear()
      })
    }

    // Clear button
    const clearBtn = this.el.querySelector('[data-action="clear"]')
    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        this.writer.clear()
      })
    }

    // Submit button
    const submitBtn = this.el.querySelector('[data-action="submit"]')
    if (submitBtn) {
      submitBtn.addEventListener('click', () => this.submit())
    }

    // Hint button
    const hintBtn = this.el.querySelector('[data-action="hint"]')
    if (hintBtn) {
      hintBtn.addEventListener('click', () => {
        // Show ghost stroke more prominently
        this.writer.setOptions({ ghostOpacity: '0.5' })
        setTimeout(() => {
          this.writer.setOptions({ ghostOpacity: '0.15' })
        }, 1000)
      })
    }
  },

  submit() {
    // Check if all strokes are completed
    if (this.writer.currentStroke >= this.writer.kanjiData.length) {
      this.pushEvent('submit_writing', { 
        strokes: JSON.stringify(this.writer.userStrokes),
        completed: true 
      })
    } else {
      // Not complete - show error
      this.pushEvent('submit_writing', { 
        strokes: JSON.stringify(this.writer.userStrokes),
        completed: false,
        current_stroke: this.writer.currentStroke,
        total_strokes: this.writer.kanjiData.length
      })
    }
  },

  // Handle server-sent events
  handleEvent(event, payload) {
    switch (event) {
      case 'clear_canvas':
        this.writer.clear()
        break
      case 'show_hint':
        // Flash the ghost stroke
        this.writer.setOptions({ ghostOpacity: '0.6' })
        setTimeout(() => {
          this.writer.setOptions({ ghostOpacity: '0.15' })
        }, 800)
        break
    }
  },

  destroyed() {
    if (this.writer) {
      this.writer.destroy()
    }
  }
}

export default KanjiWriting
