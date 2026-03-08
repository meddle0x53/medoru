/**
 * Kanji Writing Hook with Stroke Validation
 */
const KanjiWriting = {
  mounted() {
    console.log('=== KanjiWriting MOUNTED ===')

    const container = document.getElementById('writing-canvas-container')
    if (!container) {
      console.error('Container not found!')
      return
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

    // Parse SVG path - handles KanjiVG format with bezier curves
    function parsePath(pathStr) {
      const points = []
      let currentX = 0, currentY = 0

      // Normalize path:
      // 1. Add spaces around commands
      // 2. Replace commas with spaces
      // 3. Add space between number and minus sign (e.g., "7-0.62" -> "7 -0.62")
      //    Match digit followed by minus, insert space before minus
      // 4. Clean up whitespace
      let normalized = pathStr
        .replace(/([MmLlHhVvCcSsQqTtAaZz])/g, ' $1 ')
        .replace(/,/g, ' ')

      // Handle minus signs: digit-minus should become digit space minus
      // Use a loop because one pass may not catch all (overlapping matches)
      for (let i = 0; i < 5; i++) {
        normalized = normalized.replace(/(\d)(-)/g, '$1 $2')
      }

      normalized = normalized.replace(/\s+/g, ' ').trim()

      console.log('Normalized:', normalized.substring(0, 100))

      const tokens = normalized.split(/\s+/)
      console.log('Tokens:', tokens.slice(0, 15))

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
            // Cubic bezier - C cp1x cp1y cp2x cp2y x y
            // Skip control points, only take end point
            if (i + 6 < tokens.length) {
              i += 5 // Skip cp1x, cp1y, cp2x, cp2y, move to x
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
    function analyzeStroke(points) {
      if (points.length < 2) return null

      const start = points[0]
      const end = points[points.length - 1]
      const dx = end.x - start.x
      const dy = end.y - start.y
      const length = Math.sqrt(dx*dx + dy*dy)

      if (length < 1) return null

      // Determine direction type
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

      // Determine directionality (which way the stroke goes)
      let directionality
      if (direction === 'horizontal') {
        directionality = dx > 0 ? 'left-to-right' : 'right-to-left'
      } else if (direction === 'vertical') {
        directionality = dy > 0 ? 'top-to-bottom' : 'bottom-to-top'
      } else {
        // For diagonals, check both components
        const h = dx > 0 ? 'left-to-right' : 'right-to-left'
        const v = dy > 0 ? 'top-to-bottom' : 'bottom-to-top'
        directionality = `${v}-${h}`
      }

      // Calculate center and bounding box
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

    // Analyze expected strokes - keep nulls to maintain index alignment
    const analyzedExpected = expectedStrokes.map(s => {
      const points = parsePath(s.path)
      console.log('Parsing stroke', s.index, 'path:', s.path.substring(0, 60))
      console.log('  -> points:', points.length, 'first:', points[0], 'last:', points[points.length-1])
      const analyzed = analyzeStroke(points)
      if (!analyzed) {
        console.log('Failed to analyze stroke', s.index)
        return null
      }
      console.log('  -> analyzed:', analyzed.direction, 'center:', analyzed.centerX.toFixed(1), analyzed.centerY.toFixed(1), 'len:', analyzed.length.toFixed(1))
      return { ...analyzed, index: s.index }
    })

    const validExpectedCount = analyzedExpected.filter(s => s !== null).length
    console.log('Analyzed expected strokes:', analyzedExpected.length, 'valid:', validExpectedCount)
    analyzedExpected.forEach((s, i) => {
      if (s) {
        console.log('Expected', i, ':', s.direction, 'center:', s.centerX?.toFixed?.(1), s.centerY?.toFixed?.(1), 'len:', s.length?.toFixed?.(1))
      } else {
        console.log('Expected', i, ': null')
      }
    })

    // Detect viewBox size from stroke data (KanjiVG uses 109, simple format uses 100)
    const viewBoxSize = (expectedStrokes[0] && expectedStrokes[0].path && expectedStrokes[0].path.includes('109')) ? 109 : 100
    const SCALE = 300 / viewBoxSize
    console.log('Using viewBox size:', viewBoxSize, 'scale:', SCALE.toFixed(2))

    // Create canvas
    const canvas = document.createElement('canvas')
    canvas.width = 300
    canvas.height = 300
    canvas.style.cursor = 'crosshair'
    container.appendChild(canvas)

    const ctx = canvas.getContext('2d')

    // Draw grid
    function drawGrid() {
      ctx.strokeStyle = '#e5e7eb'
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(0, 150); ctx.lineTo(300, 150)
      ctx.moveTo(150, 0); ctx.lineTo(150, 300)
      ctx.moveTo(0, 0); ctx.lineTo(300, 300)
      ctx.moveTo(300, 0); ctx.lineTo(0, 300)
      ctx.stroke()
    }

    drawGrid()

    let isDrawing = false
    let currentStroke = 0
    let points = []
    let drawnStrokes = []

    const getPoint = (e) => {
      const rect = canvas.getBoundingClientRect()
      return {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top
      }
    }

    // Scale canvas point to KanjiVG coordinates
    function toKanjiVGCoords(canvasX, canvasY) {
      return {
        x: canvasX / SCALE,
        y: canvasY / SCALE
      }
    }

    // Validate drawn stroke
    function validateStroke(drawnPoints, expectedIndex) {
      if (drawnPoints.length < 3) return { valid: false, reason: 'too_short' }

      // Convert to KanjiVG coordinate space
      const vgPoints = drawnPoints.map(p => toKanjiVGCoords(p.x, p.y))
      const drawn = analyzeStroke(vgPoints)

      if (!drawn || drawn.length < 5) return { valid: false, reason: 'too_short' }

      // Fallback: if no valid expected data, just check stroke count
      const validExpected = analyzedExpected.filter(s => s !== null)
      if (validExpected.length === 0) {
        return { valid: true, fallback: true }
      }

      const expected = analyzedExpected[expectedIndex]
      if (!expected) {
        console.log('No expected stroke at index', expectedIndex)
        return { valid: false, reason: 'no_expected' }
      }

      // Check size similarity (within 30%-300%)
      const lengthRatio = drawn.length / expected.length
      console.log('Length ratio:', lengthRatio.toFixed(2), 'drawn:', drawn.length.toFixed(1), 'expected:', expected.length.toFixed(1))
      if (lengthRatio < 0.3 || lengthRatio > 3.0) {
        return { valid: false, reason: 'wrong_size' }
      }

      // Check start point position (stroke must start near the expected start)
      const startDist = Math.sqrt(
        Math.pow(drawn.start.x - expected.start.x, 2) +
        Math.pow(drawn.start.y - expected.start.y, 2)
      )
      console.log('Start dist:', startDist.toFixed(1), 'drawn:', drawn.start.x.toFixed(1), drawn.start.y.toFixed(1), 'expected:', expected.start.x.toFixed(1), expected.start.y.toFixed(1))
      if (startDist > 12) {
        return { valid: false, reason: 'wrong_start_position' }
      }

      // Check end point position (stroke must end near the expected end)
      const endDist = Math.sqrt(
        Math.pow(drawn.end.x - expected.end.x, 2) +
        Math.pow(drawn.end.y - expected.end.y, 2)
      )
      console.log('End dist:', endDist.toFixed(1))
      if (endDist > 18) {
        return { valid: false, reason: 'wrong_end_position' }
      }

      // Check center position overlap
      const centerDist = Math.sqrt(
        Math.pow(drawn.centerX - expected.centerX, 2) +
        Math.pow(drawn.centerY - expected.centerY, 2)
      )
      console.log('Center dist:', centerDist.toFixed(1), 'drawn:', drawn.centerX.toFixed(1), drawn.centerY.toFixed(1), 'expected:', expected.centerX.toFixed(1), expected.centerY.toFixed(1))
      if (centerDist > 25) {
        return { valid: false, reason: 'wrong_position' }
      }

      // Check direction type
      console.log('Direction check - drawn:', drawn.direction, 'expected:', expected.direction)
      if (drawn.direction !== expected.direction) {
        // Allow diagonals to be flexible
        const bothDiagonal =
          (drawn.direction.startsWith('diagonal') && expected.direction.startsWith('diagonal'))
        if (!bothDiagonal) {
          return { valid: false, reason: 'wrong_direction' }
        }
      }

      // Check directionality (stroke direction)
      // For horizontals: left-to-right vs right-to-left
      // For verticals: top-to-bottom vs bottom-to-top
      console.log('Directionality check - drawn:', drawn.directionality, 'expected:', expected.directionality)
      if (drawn.directionality && expected.directionality) {
        // For horizontal/vertical, require matching directionality
        if (drawn.direction === 'horizontal' || drawn.direction === 'vertical') {
          if (drawn.directionality !== expected.directionality) {
            return { valid: false, reason: 'wrong_directionality' }
          }
        }
        // For diagonals, be more lenient - just check general quadrant
        if (drawn.direction.startsWith('diagonal')) {
          const drawnParts = drawn.directionality.split('-')
          const expectedParts = expected.directionality.split('-')
          // Should share at least one direction component (horizontal or vertical)
          const match = drawnParts.some(p => expectedParts.includes(p))
          if (!match) {
            return { valid: false, reason: 'wrong_directionality' }
          }
        }
      }

      return { valid: true }
    }

    // Redraw all strokes
    function redrawStrokes() {
      ctx.clearRect(0, 0, 300, 300)
      drawGrid()

      ctx.strokeStyle = '#22c55e'
      ctx.lineWidth = 4
      ctx.lineCap = 'round'
      ctx.lineJoin = 'round'

      for (const stroke of drawnStrokes) {
        if (stroke.length < 2) continue
        ctx.beginPath()
        ctx.moveTo(stroke[0].x, stroke[0].y)
        for (let i = 1; i < stroke.length; i++) {
          ctx.lineTo(stroke[i].x, stroke[i].y)
        }
        ctx.stroke()
      }
    }

    // Drawing events
    canvas.addEventListener('pointerdown', (e) => {
      e.preventDefault()
      isDrawing = true
      points = [getPoint(e)]
      ctx.strokeStyle = '#1f2937'
      ctx.lineWidth = 4
      ctx.lineCap = 'round'
      ctx.lineJoin = 'round'
      ctx.beginPath()
      ctx.moveTo(points[0].x, points[0].y)
    })

    canvas.addEventListener('pointermove', (e) => {
      if (!isDrawing) return
      e.preventDefault()
      const p = getPoint(e)
      points.push(p)
      ctx.lineTo(p.x, p.y)
      ctx.stroke()
    })

    canvas.addEventListener('pointerup', () => {
      if (!isDrawing) return
      isDrawing = false

      if (points.length < 3) {
        points = []
        return
      }

      const validation = validateStroke(points, currentStroke)
      console.log('Validation:', validation)

      if (validation.valid) {
        drawnStrokes.push([...points])
        currentStroke++
        redrawStrokes()

        if (currentStroke >= validExpectedCount) {
          console.log('KANJI COMPLETE!')
          setTimeout(() => this.pushEvent('kanji_complete', {}), 300)
        }
      } else {
        // Flash red
        ctx.strokeStyle = '#ef4444'
        ctx.beginPath()
        ctx.moveTo(points[0].x, points[0].y)
        for (let i = 1; i < points.length; i++) {
          ctx.lineTo(points[i].x, points[i].y)
        }
        ctx.stroke()

        setTimeout(() => redrawStrokes(), 300)
      }

      points = []
    })

    // Clear button
    const clearBtn = this.el.querySelector('[data-action="clear"]')
    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        currentStroke = 0
        drawnStrokes = []
        redrawStrokes()
      })
    }

    // Submit button
    const submitBtn = this.el.querySelector('[data-action="submit"]')
    if (submitBtn) {
      submitBtn.addEventListener('click', () => {
        this.pushEvent('submit_writing', {
          completed: currentStroke >= validExpectedCount
        })
      })
    }

    console.log('Setup complete')
  }
}

export default KanjiWriting
