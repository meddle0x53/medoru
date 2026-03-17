/**
 * Kanji Writing Hook with Stroke Validation
 */
const KanjiWriting = {
  mounted() {
    console.log('=== KanjiWriting MOUNTED ===')

    // Find the canvas container within this hook element
    const container = this.el.querySelector('.writing-canvas-container')
    if (!container) {
      console.error('Container not found!')
      return
    }

    // Clean up any existing canvas from previous renders
    const existingCanvas = container.querySelector('canvas')
    if (existingCanvas) {
      console.log('Removing existing canvas')
      existingCanvas.remove()
    }

    // Get stroke data
    const strokeDataEl = this.el.querySelector('[data-stroke-data]')
    let expectedStrokes = []
    if (strokeDataEl) {
      try {
        const rawData = strokeDataEl.dataset.strokeData
        console.log('Raw stroke data:', rawData.substring(0, 200))
        const raw = JSON.parse(rawData)
        expectedStrokes = raw.map((s, i) => ({
          path: s.path,
          index: i
        })).filter(s => s.path)
        console.log('Expected strokes:', expectedStrokes.length)
      } catch (e) {
        console.error('Failed to parse stroke data:', e)
      }
    }

    // Store state on the hook instance
    this._state = {
      isDrawing: false,
      currentStroke: 0,
      points: [],
      drawnStrokes: [],
      expectedStrokes: expectedStrokes,
      ctx: null,
      canvas: null,
      showingHint: false,
      showingGrid: false
    }

    // Parse SVG path - handles KanjiVG format with bezier curves
    const parsePath = (pathStr) => {
      const points = []
      let currentX = 0, currentY = 0

      // Normalize path
      let normalized = pathStr
        .replace(/([MmLlHhVvCcSsQqTtAaZz])/g, ' $1 ')
        .replace(/,/g, ' ')

      // Handle minus signs
      for (let i = 0; i < 5; i++) {
        normalized = normalized.replace(/(\d)(-)/g, '$1 $2')
      }

      normalized = normalized.replace(/\s+/g, ' ').trim()

      const tokens = normalized.split(/\s+/)

      for (let i = 0; i < tokens.length; i++) {
        const cmd = tokens[i]
        const type = cmd.toUpperCase()
        const isRelative = cmd !== type

        switch (type) {
          case 'M':
            if (i + 2 < tokens.length) {
              currentX = parseFloat(tokens[++i])
              currentY = parseFloat(tokens[++i])
              points.push({x: currentX, y: currentY})
            }
            break
          case 'L':
            if (i + 2 < tokens.length) {
              const x = parseFloat(tokens[++i])
              const y = parseFloat(tokens[++i])
              currentX = isRelative ? currentX + x : x
              currentY = isRelative ? currentY + y : y
              points.push({x: currentX, y: currentY})
            }
            break
          case 'H':
            if (i + 1 < tokens.length) {
              const x = parseFloat(tokens[++i])
              currentX = isRelative ? currentX + x : x
              points.push({x: currentX, y: currentY})
            }
            break
          case 'V':
            if (i + 1 < tokens.length) {
              const y = parseFloat(tokens[++i])
              currentY = isRelative ? currentY + y : y
              points.push({x: currentX, y: currentY})
            }
            break
          case 'C':
            if (i + 6 < tokens.length) {
              i += 5
              const x = parseFloat(tokens[i])
              const y = parseFloat(tokens[++i])
              currentX = isRelative ? currentX + x : x
              currentY = isRelative ? currentY + y : y
              points.push({x: currentX, y: currentY})
            }
            break
        }
      }

      return points
    }

    // Analyze stroke properties
    const analyzeStroke = (points) => {
      if (points.length < 2) return null

      const start = points[0]
      const end = points[points.length - 1]
      const dx = end.x - start.x
      const dy = end.y - start.y
      const length = Math.sqrt(dx*dx + dy*dy)

      if (length < 1) return null

      let direction
      const absDx = Math.abs(dx)
      const absDy = Math.abs(dy)
      const ratio = absDx > 0 ? absDy / absDx : 999

      if (ratio < 0.3) {
        direction = 'horizontal'
      } else if (ratio > 3) {
        direction = 'vertical'
      } else if (dx * dy > 0) {
        direction = 'diagonal_down'
      } else {
        direction = 'diagonal_up'
      }

      let directionality
      if (direction === 'horizontal') {
        directionality = dx > 0 ? 'left-to-right' : 'right-to-left'
      } else if (direction === 'vertical') {
        directionality = dy > 0 ? 'top-to-bottom' : 'bottom-to-top'
      } else {
        const h = dx > 0 ? 'left-to-right' : 'right-to-left'
        const v = dy > 0 ? 'top-to-bottom' : 'bottom-to-top'
        directionality = v + '-' + h
      }

      let minX = start.x, maxX = start.x
      let minY = start.y, maxY = start.y
      for (const p of points) {
        minX = Math.min(minX, p.x)
        maxX = Math.max(maxX, p.x)
        minY = Math.min(minY, p.y)
        maxY = Math.max(maxY, p.y)
      }

      return {
        length,
        direction,
        directionality,
        centerX: (minX + maxX) / 2,
        centerY: (minY + maxY) / 2,
        minX, maxX, minY, maxY,
        start, end
      }
    }

    // Analyze expected strokes - store both analyzed data AND original path
    this._state.analyzedExpected = expectedStrokes.map(s => {
      const points = parsePath(s.path)
      const analyzed = analyzeStroke(points)
      if (!analyzed) return null
      return { ...analyzed, index: s.index, originalPath: s.path, originalPoints: points }
    })

    const validExpectedCount = this._state.analyzedExpected.filter(s => s !== null).length
    const rawCount = expectedStrokes.length
    
    // Kanji always have multiple strokes (rarely just 1).
    // If we have less than 2 strokes, the data is incomplete - don't auto-complete
    this._state.validExpectedCount = validExpectedCount >= 2 ? validExpectedCount : 
                                     rawCount >= 2 ? rawCount : 999
    
    console.log('Valid expected strokes:', this._state.validExpectedCount)

    // Detect viewBox size
    const viewBoxSize = (expectedStrokes[0] && expectedStrokes[0].path && expectedStrokes[0].path.includes('109')) ? 109 : 100
    // Kanji draws slightly to the left and up from center
    this._state.scale = 300 / viewBoxSize
    this._state.offsetX = -15  // Shift 15px left
    this._state.offsetY = -15  // Shift 15px up

    // Create canvas
    const canvas = document.createElement('canvas')
    canvas.width = 300
    canvas.height = 300
    canvas.style.cursor = 'crosshair'
    container.appendChild(canvas)
    this._state.canvas = canvas

    const ctx = canvas.getContext('2d')
    this._state.ctx = ctx

    // Clear canvas (no grid)
    const clearCanvas = () => {
      ctx.clearRect(0, 0, 300, 300)
    }

    // Draw grid lines (center cross and diagonals)
    const drawGrid = () => {
      ctx.strokeStyle = '#e5e7eb'
      ctx.lineWidth = 1
      ctx.beginPath()
      // Horizontal center
      ctx.moveTo(0, 150); ctx.lineTo(300, 150)
      // Vertical center
      ctx.moveTo(150, 0); ctx.lineTo(150, 300)
      // Diagonals
      ctx.moveTo(0, 0); ctx.lineTo(300, 300)
      ctx.moveTo(300, 0); ctx.lineTo(0, 300)
      ctx.stroke()
    }

    clearCanvas()

    const getPoint = (e) => {
      const rect = canvas.getBoundingClientRect()
      return {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top
      }
    }

    const toKanjiVGCoords = (canvasX, canvasY) => {
      return {
        x: (canvasX - this._state.offsetX) / this._state.scale,
        y: (canvasY - this._state.offsetY) / this._state.scale
      }
    }

    // Validate drawn stroke
    const validateStroke = (drawnPoints, expectedIndex) => {
      if (drawnPoints.length < 3) return { valid: false, reason: 'too_short' }

      const vgPoints = drawnPoints.map(p => toKanjiVGCoords(p.x, p.y))
      const drawn = analyzeStroke(vgPoints)

      if (!drawn || drawn.length < 5) return { valid: false, reason: 'too_short' }

      const validExpected = this._state.analyzedExpected.filter(s => s !== null)
      if (validExpected.length === 0) {
        // No valid stroke data to compare against - reject the stroke
        // This forces the user to skip the question rather than accepting invalid strokes
        return { valid: false, reason: 'no_reference_data' }
      }

      const expected = this._state.analyzedExpected[expectedIndex]
      if (!expected) {
        return { valid: false, reason: 'no_expected' }
      }

      const lengthRatio = drawn.length / expected.length
      if (lengthRatio < 0.3 || lengthRatio > 3.0) {
        return { valid: false, reason: 'wrong_size' }
      }

      const startDist = Math.sqrt(
        Math.pow(drawn.start.x - expected.start.x, 2) +
        Math.pow(drawn.start.y - expected.start.y, 2)
      )
      if (startDist > 12) {
        return { valid: false, reason: 'wrong_start_position' }
      }

      const endDist = Math.sqrt(
        Math.pow(drawn.end.x - expected.end.x, 2) +
        Math.pow(drawn.end.y - expected.end.y, 2)
      )
      if (endDist > 18) {
        return { valid: false, reason: 'wrong_end_position' }
      }

      const centerDist = Math.sqrt(
        Math.pow(drawn.centerX - expected.centerX, 2) +
        Math.pow(drawn.centerY - expected.centerY, 2)
      )
      if (centerDist > 25) {
        return { valid: false, reason: 'wrong_position' }
      }

      if (drawn.direction !== expected.direction) {
        const bothDiagonal =
          (drawn.direction.startsWith('diagonal') && expected.direction.startsWith('diagonal'))
        if (!bothDiagonal) {
          return { valid: false, reason: 'wrong_direction' }
        }
      }

      if (drawn.directionality && expected.directionality) {
        if (drawn.direction === 'horizontal' || drawn.direction === 'vertical') {
          if (drawn.directionality !== expected.directionality) {
            return { valid: false, reason: 'wrong_directionality' }
          }
        }
        if (drawn.direction.startsWith('diagonal')) {
          const drawnParts = drawn.directionality.split('-')
          const expectedParts = expected.directionality.split('-')
          const match = drawnParts.some(p => expectedParts.includes(p))
          if (!match) {
            return { valid: false, reason: 'wrong_directionality' }
          }
        }
      }

      return { valid: true }
    }

    // Snap user's stroke to exactly match the expected (yellow) stroke
    this.snapStrokeToExpected = (userPoints, expected) => {
      if (!expected || !expected.originalPoints || expected.originalPoints.length < 2) {
        return userPoints
      }
      
      const scale = this._state.scale
      const expectedPoints = expected.originalPoints
      
      // Map each user point to the corresponding point on the expected stroke
      // This makes the green stroke exactly overlay the yellow hint
      const snapped = userPoints.map((p, i) => {
        // Find the corresponding index in expected points
        const ratio = userPoints.length > 1 ? i / (userPoints.length - 1) : 0
        const expectedIndex = Math.min(Math.floor(ratio * expectedPoints.length), expectedPoints.length - 1)
        const expPoint = expectedPoints[expectedIndex]
        
        // Return the exact expected position (scaled to canvas with offset)
        return {
          x: expPoint.x * scale + this._state.offsetX,
          y: expPoint.y * scale + this._state.offsetY
        }
      })
      
      return snapped
    }

    // Draw yellow hint stroke
    const drawHintStroke = () => {
      if (!this._state.showingHint) return
      if (this._state.currentStroke >= this._state.analyzedExpected.length) return
      
      const expected = this._state.analyzedExpected[this._state.currentStroke]
      if (!expected || !expected.originalPoints) return

      // Draw the actual expected stroke path in yellow
      ctx.save()
      ctx.strokeStyle = '#fbbf24'  // amber-400
      ctx.lineWidth = 5
      ctx.lineCap = 'round'
      ctx.lineJoin = 'round'
      ctx.globalAlpha = 0.7
      
      const points = expected.originalPoints
      const scale = this._state.scale
      const offsetX = this._state.offsetX
      const offsetY = this._state.offsetY
      
      ctx.beginPath()
      ctx.moveTo(points[0].x * scale + offsetX, points[0].y * scale + offsetY)
      for (let i = 1; i < points.length; i++) {
        ctx.lineTo(points[i].x * scale + offsetX, points[i].y * scale + offsetY)
      }
      ctx.stroke()
      
      ctx.restore()
    }

    // Redraw all strokes
    const redrawStrokes = () => {
      ctx.clearRect(0, 0, 300, 300)
      clearCanvas()
      
      // Draw grid if showing (hint button toggles this)
      if (this._state.showingGrid) {
        drawGrid()
      }
      
      // Draw yellow hint if showing
      drawHintStroke()

      ctx.strokeStyle = '#22c55e'
      ctx.lineWidth = 4
      ctx.lineCap = 'round'
      ctx.lineJoin = 'round'

      for (const stroke of this._state.drawnStrokes) {
        if (stroke.length < 2) continue
        ctx.beginPath()
        ctx.moveTo(stroke[0].x, stroke[0].y)
        for (let i = 1; i < stroke.length; i++) {
          ctx.lineTo(stroke[i].x, stroke[i].y)
        }
        ctx.stroke()
      }
    }

    // Store handlers for cleanup
    this._handlers = {
      pointerdown: (e) => {
        e.preventDefault()
        this._state.isDrawing = true
        this._state.points = [getPoint(e)]
        ctx.strokeStyle = '#1f2937'
        ctx.lineWidth = 4
        ctx.lineCap = 'round'
        ctx.lineJoin = 'round'
        ctx.beginPath()
        ctx.moveTo(this._state.points[0].x, this._state.points[0].y)
      },

      pointermove: (e) => {
        if (!this._state.isDrawing) return
        e.preventDefault()
        const p = getPoint(e)
        this._state.points.push(p)
        ctx.lineTo(p.x, p.y)
        ctx.stroke()
      },

      pointerup: () => {
        if (!this._state.isDrawing) return
        this._state.isDrawing = false

        if (this._state.points.length < 3) {
          this._state.points = []
          return
        }

        const validation = validateStroke(this._state.points, this._state.currentStroke)

        if (validation.valid) {
          // CORRECT STROKE - snap to expected and save
          this._state.showingHint = false
          
          // Get expected stroke for snapping
          const expected = this._state.analyzedExpected[this._state.currentStroke]
          const snappedPoints = this.snapStrokeToExpected(this._state.points, expected)
          
          this._state.drawnStrokes.push(snappedPoints)
          this._state.currentStroke++
          redrawStrokes()

          if (this._state.currentStroke >= this._state.validExpectedCount) {
            setTimeout(() => this.pushEvent('kanji_complete', {}), 300)
          }
        } else {
          // WRONG STROKE - show hint
          this._state.showingHint = true
          
          // Show wrong stroke in red temporarily
          ctx.strokeStyle = '#ef4444'
          ctx.beginPath()
          ctx.moveTo(this._state.points[0].x, this._state.points[0].y)
          for (let i = 1; i < this._state.points.length; i++) {
            ctx.lineTo(this._state.points[i].x, this._state.points[i].y)
          }
          ctx.stroke()

          // Redraw with hint after short delay
          setTimeout(() => redrawStrokes(), 300)
        }

        this._state.points = []
      }
    }

    // Attach event listeners
    canvas.addEventListener('pointerdown', this._handlers.pointerdown)
    canvas.addEventListener('pointermove', this._handlers.pointermove)
    canvas.addEventListener('pointerup', this._handlers.pointerup)

    // Clear button
    this._clearBtn = this.el.querySelector('[data-action="clear"]')
    this._handlers.clear = () => {
      this._state.currentStroke = 0
      this._state.drawnStrokes = []
      this._state.showingHint = false
      this._state.showingGrid = false
      redrawStrokes()
    }
    if (this._clearBtn) {
      this._clearBtn.addEventListener('click', this._handlers.clear)
    }

    // Submit button
    this._submitBtn = this.el.querySelector('[data-action="submit"]')
    this._handlers.submit = () => {
      this.pushEvent('submit_writing', {
        completed: this._state.currentStroke >= this._state.validExpectedCount
      })
    }
    if (this._submitBtn) {
      this._submitBtn.addEventListener('click', this._handlers.submit)
    }

    // Hint button - toggles grid lines
    this._hintBtn = this.el.querySelector('[data-action="hint"]')
    this._handlers.hint = () => {
      this._state.showingGrid = !this._state.showingGrid
      redrawStrokes()
    }
    if (this._hintBtn) {
      this._hintBtn.addEventListener('click', this._handlers.hint)
    }

    console.log('Setup complete')
  },

  destroyed() {
    console.log('=== KanjiWriting DESTROYED ===')

    // Remove canvas
    if (this._state && this._state.canvas) {
      this._state.canvas.remove()
    }

    // Remove event listeners from buttons
    if (this._clearBtn && this._handlers && this._handlers.clear) {
      this._clearBtn.removeEventListener('click', this._handlers.clear)
    }
    if (this._submitBtn && this._handlers && this._handlers.submit) {
      this._submitBtn.removeEventListener('click', this._handlers.submit)
    }
    if (this._hintBtn && this._handlers && this._handlers.hint) {
      this._hintBtn.removeEventListener('click', this._handlers.hint)
    }

    // Clear state
    this._state = null
    this._handlers = null
  }
}

export default KanjiWriting
