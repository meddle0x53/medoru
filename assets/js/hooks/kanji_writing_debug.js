/**
 * Debug version of Kanji Writing Hook
 */
const KanjiWriting = {
  mounted() {
    console.log('=== KanjiWriting Debug ===')
    console.log('Hook element:', this.el)
    console.log('Hook element ID:', this.el?.id)
    console.log('Hook element classes:', this.el?.className)
    
    // Check if KanjiWriter is available
    if (typeof KanjiWriter === 'undefined') {
      console.error('KanjiWriting: KanjiWriter library not loaded!')
      return
    }
    console.log('KanjiWriter available:', typeof KanjiWriter)

    // Get kanji stroke data from the component
    const strokeDataEl = this.el.querySelector('[data-stroke-data]')
    console.log('Stroke data element:', strokeDataEl)
    
    this.strokeData = []
    
    if (strokeDataEl) {
      try {
        const rawData = JSON.parse(strokeDataEl.dataset.strokeData)
        console.log('Raw stroke data:', rawData)
        // Extract path strings from stroke data
        this.strokeData = rawData.map(stroke => stroke.path || '').filter(p => p)
        console.log('Extracted stroke paths:', this.strokeData)
      } catch (e) {
        console.error('KanjiWriting: Failed to parse stroke data', e)
      }
    } else {
      console.error('No [data-stroke-data] element found!')
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
    console.log('=== initWriter called ===')
    
    // Find the container element
    const container = this.el.querySelector('#writing-canvas-container')
    console.log('Container element:', container)
    
    if (!container) {
      console.error('KanjiWriting: No canvas container found')
      // List all children to debug
      console.log('Hook children:', this.el.children)
      return
    }

    console.log('Container innerHTML before:', container.innerHTML)
    
    // Clear any existing content
    container.innerHTML = ''
    console.log('Container cleared')

    // Create the KanjiWriter instance
    try {
      console.log('Creating KanjiWriter with', this.strokeData.length, 'strokes')
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
      console.log('KanjiWriter created:', this.writer)
      console.log('KanjiWriter svg:', this.writer.svg)
      console.log('Container innerHTML after:', container.innerHTML)
    } catch (e) {
      console.error('KanjiWriting: Failed to create KanjiWriter', e)
      return
    }

    // Set up callbacks with debug
    this.writer.onCorrect = () => {
      console.log('Stroke correct!')
      this.pushEvent('stroke_correct', {})
    }

    this.writer.onIncorrect = (result) => {
      console.log('Stroke incorrect:', result)
      setTimeout(() => {
        this.writer.clear()
      }, 500)
      this.pushEvent('stroke_incorrect', { error: result.error })
    }

    this.writer.onComplete = () => {
      console.log('Kanji complete!')
      this.pushEvent('kanji_complete', {})
    }

    // Add test event listeners
    if (this.writer.svg) {
      console.log('Adding debug event listeners to SVG')
      this.writer.svg.addEventListener('pointerdown', (e) => {
        console.log('SVG pointerdown:', e)
      })
    }

    // Setup control buttons
    this.setupControls()
  },

  setupControls() {
    console.log('Setting up controls')
    
    // Clear button
    const clearBtn = this.el.querySelector('[data-action="clear"]')
    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        console.log('Clear clicked')
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
        console.log('Hint clicked')
        this.writer.setOptions({ ghostOpacity: '0.5' })
        setTimeout(() => {
          this.writer.setOptions({ ghostOpacity: '0.15' })
        }, 1000)
      })
    }
  },

  submit() {
    console.log('Submit clicked, current stroke:', this.writer.currentStroke, 'of', this.writer.kanjiData.length)
    if (this.writer.currentStroke >= this.writer.kanjiData.length) {
      this.pushEvent('submit_writing', { 
        strokes: JSON.stringify(this.writer.userStrokes),
        completed: true 
      })
    } else {
      this.pushEvent('submit_writing', { 
        strokes: JSON.stringify(this.writer.userStrokes),
        completed: false
      })
    }
  },

  handleEvent(event, payload) {
    console.log('Received event:', event, payload)
    switch (event) {
      case 'clear_canvas':
        this.writer.clear()
        break
      case 'show_hint':
        this.writer.setOptions({ ghostOpacity: '0.6' })
        setTimeout(() => {
          this.writer.setOptions({ ghostOpacity: '0.15' })
        }, 800)
        break
    }
  },

  destroyed() {
    console.log('Hook destroyed')
    if (this.writer) {
      this.writer.destroy()
    }
  }
}

export default KanjiWriting
