import { GAME_CONFIG } from '../config.js'

/**
 * KanjiDrawingSystem - Replicates the KanjiWriting hook logic inside Phaser.
 * Uses a DOM canvas overlay for drawing with the exact same stroke validation.
 */
export default class KanjiDrawingSystem {
  constructor(scene, x, y, size = 300, options = {}) {
    this.scene = scene
    this.size = size
    this.centerX = x
    this.centerY = y
    this.halfSize = size / 2
    this.options = {
      offsetXPercent: 0.05,
      offsetYPercent: 0.05,
      offsetYAdjust: -40,
      timeLimit: 7000,
      ...options,
    }

    // Hint text element (above canvas)
    this.hintText = document.createElement('div')
    this.hintText.style.position = 'absolute'
    this.hintText.style.left = `${x - this.halfSize}px`
    this.hintText.style.top = `${y - this.halfSize - 80}px`
    this.hintText.style.width = `${size}px`
    this.hintText.style.textAlign = 'center'
    this.hintText.style.color = '#ecf0f1'
    this.hintText.style.fontFamily = '"Helvetica Neue", Helvetica, Arial, sans-serif'
    this.hintText.style.fontSize = '16px'
    this.hintText.style.fontWeight = 'bold'
    this.hintText.style.zIndex = '101'
    this.hintText.style.display = 'none'
    this.hintText.style.background = 'rgba(139, 0, 0, 0.95)'
    this.hintText.style.padding = '8px 16px'
    this.hintText.style.borderRadius = '12px'
    this.hintText.style.backdropFilter = 'blur(4px)'
    this.hintText.style.lineHeight = '1.4'
    this.hintText.style.maxHeight = '72px'
    this.hintText.style.overflow = 'hidden'
    this.hintText.style.touchAction = 'none'
    this.hintText.style.userSelect = 'none'

    // Optional info label shown below the hint (e.g. current armor during setup)
    this.infoText = document.createElement('div')
    this.infoText.style.position = 'absolute'
    this.infoText.style.left = `${x - this.halfSize}px`
    this.infoText.style.top = `${y - this.halfSize - 36}px`
    this.infoText.style.width = `${size}px`
    this.infoText.style.textAlign = 'center'
    this.infoText.style.color = '#c0392b'
    this.infoText.style.fontFamily = '"Helvetica Neue", Helvetica, Arial, sans-serif'
    this.infoText.style.fontSize = '14px'
    this.infoText.style.fontWeight = 'bold'
    this.infoText.style.zIndex = '101'
    this.infoText.style.display = 'none'
    this.infoText.style.textShadow = '0 1px 2px rgba(0,0,0,0.8)'

    // Canvas element (DOM overlay)
    this.canvas = document.createElement('canvas')
    this.canvas.width = size
    this.canvas.height = size
    this.canvas.style.position = 'absolute'
    this.canvas.style.left = `${x - this.halfSize}px`
    this.canvas.style.top = `${y - this.halfSize + 10}px`
    this.canvas.style.width = `${size}px`
    this.canvas.style.height = `${size}px`
    this.canvas.style.cursor = 'crosshair'
    this.canvas.style.zIndex = '100'
    this.canvas.style.borderRadius = '16px'
    this.canvas.style.background = 'rgba(26, 26, 46, 0.92)'
    this.canvas.style.boxShadow = '0 8px 32px rgba(0,0,0,0.5)'
    this.canvas.style.display = 'none'
    this.canvas.style.touchAction = 'none'
    this.canvas.style.userSelect = 'none'
    this.canvas.style.webkitUserSelect = 'none'
    this.canvas.style.pointerEvents = 'auto'

    // Scaled DOM wrapper that maps the logical 960×540 design onto the displayed wrapper.
    this.gameWrapper = document.getElementById('game-wrapper')
    this.domWrapper = document.createElement('div')
    this.domWrapper.style.position = 'absolute'
    this.domWrapper.style.top = '0'
    this.domWrapper.style.left = '0'
    this.domWrapper.style.width = `${GAME_CONFIG.width}px`
    this.domWrapper.style.height = `${GAME_CONFIG.height}px`
    this.domWrapper.style.zIndex = '300'
    this.domWrapper.style.pointerEvents = 'none'

    this._updateScale = this._updateScale.bind(this)
    if (this.gameWrapper) {
      this._updateScale()
      this.gameWrapper.appendChild(this.domWrapper)
      if (typeof ResizeObserver !== 'undefined') {
        this._resizeObserver = new ResizeObserver(this._updateScale)
        this._resizeObserver.observe(this.gameWrapper)
      } else {
        window.addEventListener('resize', this._updateScale)
      }
    }

    this.domWrapper.appendChild(this.hintText)
    this.domWrapper.appendChild(this.infoText)
    this.domWrapper.appendChild(this.canvas)

    this.ctx = this.canvas.getContext('2d')

    this.state = {
      isDrawing: false,
      currentStroke: 0,
      points: [],
      drawnStrokes: [],
      expectedStrokes: [],
      analyzedExpected: [],
      validExpectedCount: 0,
      wrongStrokes: 0,
      showingHint: false,
      scale: 1,
      offsetX: 0,
      offsetY: 0,
    }

    this.callbacks = {
      onComplete: null,
      onWrongStroke: null,
      onCancel: null,
    }

    this.focusKanjiData = null
    this.timer = null
    this.timeLimit = this.options.timeLimit
    this.timeRemaining = this.timeLimit

    this._bindEvents()
  }

  // ---------- Public API ----------

  start(strokeData, hint = '', callbacks = {}, kanjiData = null, options = {}) {
    // 20% chance to override the challenge with the run's focus kanji.
    let actualKanjiData = kanjiData
    if (options.allowFocusOverride !== false && this.focusKanjiData && Math.random() < 0.2) {
      const focus = this.focusKanjiData
      if (focus.stroke_data && focus.stroke_data.strokes && focus.stroke_data.strokes.length > 0) {
        strokeData = focus.stroke_data
        hint = `Focus lesson! Draw ${focus.character}:`
        actualKanjiData = focus
      }
    }

    if (callbacks.onStart) {
      callbacks.onStart(actualKanjiData)
    }

    this.callbacks = { ...this.callbacks, ...callbacks }
    this._resetState()
    this._loadStrokeData(strokeData)
    this.hintText.textContent = hint
    this.hintText.style.display = 'block'
    if (callbacks.info) {
      this.infoText.textContent = callbacks.info
      this.infoText.style.display = 'block'
    } else {
      this.infoText.style.display = 'none'
    }
    this.canvas.style.display = 'block'
    this._drawBackground()
    this._startTimer()
  }

  hide() {
    this.hintText.style.display = 'none'
    this.infoText.style.display = 'none'
    this.canvas.style.display = 'none'
    this._stopTimer()
  }

  setFocusKanjiData(data) {
    this.focusKanjiData = data || null
  }

  destroy() {
    this._stopTimer()
    if (this._resizeObserver) {
      this._resizeObserver.disconnect()
      this._resizeObserver = null
    } else if (this._updateScale) {
      window.removeEventListener('resize', this._updateScale)
    }
    if (this.domWrapper && this.domWrapper.parentNode) {
      this.domWrapper.parentNode.removeChild(this.domWrapper)
    }
    this._unbindEvents()
  }

  _updateScale() {
    if (!this.gameWrapper || !this.domWrapper) return
    const scaleX = (this.gameWrapper.clientWidth || GAME_CONFIG.width) / GAME_CONFIG.width
    const scaleY = (this.gameWrapper.clientHeight || GAME_CONFIG.height) / GAME_CONFIG.height
    this.domWrapper.style.transform = `scale(${scaleX}, ${scaleY})`
    this.domWrapper.style.transformOrigin = 'top left'
  }

  // ---------- Timer ----------

  _startTimer() {
    this.timeRemaining = this.timeLimit
    this._stopTimer()
    this.timer = setInterval(() => {
      this.timeRemaining -= 100
      if (this.timeRemaining <= 0) {
        this._stopTimer()
        this._onTimeout()
      }
      this._drawTimerBar()
    }, 100)
  }

  _stopTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  _onTimeout() {
    this.hide()
    if (this.callbacks.onComplete) {
      this.callbacks.onComplete({ completed: false, wrongStrokes: this.state.wrongStrokes, timedOut: true })
    }
  }

  // ---------- Stroke Data Loading ----------

  _loadStrokeData(strokeData) {
    const strokes = (strokeData.strokes || []).map((s, i) => ({
      path: s.path,
      index: i,
    })).filter(s => s.path)

    this.state.expectedStrokes = strokes
    this.state.analyzedExpected = strokes.map(s => {
      const points = this._parsePath(s.path)
      const analyzed = this._analyzeStroke(points)
      if (!analyzed) return null
      return { ...analyzed, index: s.index, originalPath: s.path, originalPoints: points }
    })

    const validCount = this.state.analyzedExpected.filter(s => s !== null).length
    const rawCount = strokes.length
    this.state.validExpectedCount = validCount > 0 ? validCount : (rawCount > 0 ? rawCount : 0)

    // Detect viewBox and compute scale
    const viewBoxSize = (strokes[0] && strokes[0].path && strokes[0].path.includes('109')) ? 109 : 100
    this.state.scale = this.size / viewBoxSize
    this.state.offsetX = this.size * this.options.offsetXPercent
    this.state.offsetY = this.size * this.options.offsetYPercent + this.options.offsetYAdjust
  }

  _resetState() {
    this.state.isDrawing = false
    this.state.currentStroke = 0
    this.state.points = []
    this.state.drawnStrokes = []
    this.state.wrongStrokes = 0
    this.state.showingHint = false
  }

  // ---------- Event Binding ----------

  _bindEvents() {
    this._onPointerDown = this._onPointerDown.bind(this)
    this._onPointerMove = this._onPointerMove.bind(this)
    this._onPointerUp = this._onPointerUp.bind(this)

    this.canvas.addEventListener('pointerdown', this._onPointerDown)
    this.canvas.addEventListener('pointermove', this._onPointerMove)
    this.canvas.addEventListener('pointerup', this._onPointerUp)
    this.canvas.addEventListener('pointerleave', this._onPointerUp)
    // Touch fallback for mobile browsers
    this.canvas.addEventListener('touchstart', (e) => { e.preventDefault(); }, { passive: false })
    this.canvas.addEventListener('touchmove', (e) => { e.preventDefault(); }, { passive: false })
  }

  _unbindEvents() {
    this.canvas.removeEventListener('pointerdown', this._onPointerDown)
    this.canvas.removeEventListener('pointermove', this._onPointerMove)
    this.canvas.removeEventListener('pointerup', this._onPointerUp)
    this.canvas.removeEventListener('pointerleave', this._onPointerUp)
  }

  _getPoint(e) {
    const rect = this.canvas.getBoundingClientRect()
    // The canvas may be CSS-scaled by the wrapper; normalize to internal pixels.
    const scaleX = rect.width > 0 ? this.canvas.width / rect.width : 1
    const scaleY = rect.height > 0 ? this.canvas.height / rect.height : 1
    return {
      x: (e.clientX - rect.left) * scaleX,
      y: (e.clientY - rect.top) * scaleY,
    }
  }

  _toKanjiVGCoords(canvasX, canvasY) {
    return {
      x: (canvasX - this.state.offsetX) / this.state.scale,
      y: (canvasY - this.state.offsetY) / this.state.scale,
    }
  }

  // ---------- Drawing Handlers ----------

  _onPointerDown(e) {
    e.preventDefault()
    this.state.isDrawing = true
    this.state.points = [this._getPoint(e)]
    this.ctx.strokeStyle = '#1f2937'
    this.ctx.lineWidth = 4
    this.ctx.lineCap = 'round'
    this.ctx.lineJoin = 'round'
    this.ctx.beginPath()
    this.ctx.moveTo(this.state.points[0].x, this.state.points[0].y)
  }

  _onPointerMove(e) {
    if (!this.state.isDrawing) return
    e.preventDefault()
    const p = this._getPoint(e)
    this.state.points.push(p)
    this.ctx.lineTo(p.x, p.y)
    this.ctx.stroke()
  }

  _onPointerUp() {
    if (!this.state.isDrawing) return
    this.state.isDrawing = false

    if (this.state.points.length < 2) {
      this.state.points = []
      return
    }

    const validation = this._validateStroke(this.state.points, this.state.currentStroke)

    if (validation.valid) {
      // CORRECT STROKE
      this.state.showingHint = false
      const expected = this.state.analyzedExpected[this.state.currentStroke]
      this.state.drawnStrokes.push({
        type: 'curved',
        path: expected.originalPath,
      })
      this.state.currentStroke++
      this._redrawStrokes()

      // Restart timer after each correct stroke (unless last stroke)
      if (this.state.currentStroke < this.state.validExpectedCount) {
        this._startTimer()
      }

      if (this.state.currentStroke >= this.state.validExpectedCount) {
        this._stopTimer()
        setTimeout(() => {
          this.hide()
          if (this.callbacks.onComplete) {
            this.callbacks.onComplete({
              completed: true,
              wrongStrokes: this.state.wrongStrokes,
            })
          }
        }, 300)
      }
    } else {
      // WRONG STROKE
      this.state.wrongStrokes++
      if (this.callbacks.onWrongStroke) {
        this.callbacks.onWrongStroke({ count: this.state.wrongStrokes })
      }
      this.state.showingHint = true

      // Show wrong stroke in red temporarily
      this.ctx.strokeStyle = '#ef4444'
      this.ctx.beginPath()
      this.ctx.moveTo(this.state.points[0].x, this.state.points[0].y)
      for (let i = 1; i < this.state.points.length; i++) {
        this.ctx.lineTo(this.state.points[i].x, this.state.points[i].y)
      }
      this.ctx.stroke()

      setTimeout(() => this._redrawStrokes(), 300)
    }

    this.state.points = []
  }

  // ---------- Rendering ----------

  _drawBackground() {
    const ctx = this.ctx
    const s = this.size

    // Clear
    ctx.clearRect(0, 0, s, s)

    // Background fill (already handled by CSS, but draw a subtle grid)
    ctx.strokeStyle = '#e5e7eb'
    ctx.lineWidth = 1
    ctx.globalAlpha = 0.3
    ctx.beginPath()
    // Center cross
    ctx.moveTo(0, s / 2)
    ctx.lineTo(s, s / 2)
    ctx.moveTo(s / 2, 0)
    ctx.lineTo(s / 2, s)
    // Diagonals
    ctx.moveTo(0, 0)
    ctx.lineTo(s, s)
    ctx.moveTo(s, 0)
    ctx.lineTo(0, s)
    ctx.stroke()
    ctx.globalAlpha = 1

    this._drawTimerBar()
  }

  _drawTimerBar() {
    const ctx = this.ctx
    const s = this.size
    const pct = Math.max(0, this.timeRemaining / this.timeLimit)

    const bottomOffset = 10

    // Timer bar background
    ctx.fillStyle = '#2c3e50'
    ctx.fillRect(5, s - bottomOffset, s - bottomOffset, 5)

    // Timer bar fill
    ctx.fillStyle = pct > 0.5 ? '#2ecc71' : pct > 0.25 ? '#f39c12' : '#e74c3c'
    ctx.fillRect(5, s - bottomOffset, (s - bottomOffset) * pct, 5)

  }

  _drawHintStroke() {
    if (!this.state.showingHint) return
    if (this.state.currentStroke >= this.state.analyzedExpected.length) return

    const expected = this.state.analyzedExpected[this.state.currentStroke]
    if (!expected || !expected.originalPath) return

    const ctx = this.ctx
    ctx.save()
    ctx.strokeStyle = '#fbbf24'
    ctx.lineWidth = 5
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.globalAlpha = 0.7
    ctx.translate(this.state.offsetX, this.state.offsetY)
    ctx.scale(this.state.scale, this.state.scale)
    const path = new Path2D(expected.originalPath)
    ctx.stroke(path)
    ctx.restore()
  }

  _redrawStrokes() {
    this._drawBackground()
    this._drawHintStroke()

    const ctx = this.ctx
    ctx.strokeStyle = '#22c55e'
    ctx.lineWidth = 4
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.globalAlpha = 1

    for (const stroke of this.state.drawnStrokes) {
      if (stroke.type === 'curved' && stroke.path) {
        ctx.save()
        ctx.translate(this.state.offsetX, this.state.offsetY)
        ctx.scale(this.state.scale, this.state.scale)
        const path = new Path2D(stroke.path)
        ctx.stroke(path)
        ctx.restore()
      } else if (Array.isArray(stroke) && stroke.length >= 2) {
        ctx.beginPath()
        ctx.moveTo(stroke[0].x, stroke[0].y)
        for (let i = 1; i < stroke.length; i++) {
          ctx.lineTo(stroke[i].x, stroke[i].y)
        }
        ctx.stroke()
      }
    }
  }

  // ---------- SVG Path Parsing (exact same as kanji_writing.js) ----------

  _parsePath(pathStr) {
    const points = []
    let currentX = 0, currentY = 0

    let normalized = pathStr
      .replace(/([MmLlHhVvCcSsQqTtAaZz])/g, ' $1 ')
      .replace(/,/g, ' ')

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
            points.push({ x: currentX, y: currentY })
          }
          break
        case 'L':
          if (i + 2 < tokens.length) {
            const x = parseFloat(tokens[++i])
            const y = parseFloat(tokens[++i])
            currentX = isRelative ? currentX + x : x
            currentY = isRelative ? currentY + y : y
            points.push({ x: currentX, y: currentY })
          }
          break
        case 'H':
          if (i + 1 < tokens.length) {
            const x = parseFloat(tokens[++i])
            currentX = isRelative ? currentX + x : x
            points.push({ x: currentX, y: currentY })
          }
          break
        case 'V':
          if (i + 1 < tokens.length) {
            const y = parseFloat(tokens[++i])
            currentY = isRelative ? currentY + y : y
            points.push({ x: currentX, y: currentY })
          }
          break
        case 'C':
          if (i + 6 < tokens.length) {
            i += 5
            const x = parseFloat(tokens[i])
            const y = parseFloat(tokens[++i])
            currentX = isRelative ? currentX + x : x
            currentY = isRelative ? currentY + y : y
            points.push({ x: currentX, y: currentY })
          }
          break
        case 'S':
          if (i + 4 < tokens.length) {
            i += 3
            const x = parseFloat(tokens[i])
            const y = parseFloat(tokens[++i])
            currentX = isRelative ? currentX + x : x
            currentY = isRelative ? currentY + y : y
            points.push({ x: currentX, y: currentY })
          }
          break
        case 'Q':
          if (i + 4 < tokens.length) {
            i += 3
            const x = parseFloat(tokens[i])
            const y = parseFloat(tokens[++i])
            currentX = isRelative ? currentX + x : x
            currentY = isRelative ? currentY + y : y
            points.push({ x: currentX, y: currentY })
          }
          break
        case 'T':
          if (i + 2 < tokens.length) {
            i += 1
            const x = parseFloat(tokens[i])
            const y = parseFloat(tokens[++i])
            currentX = isRelative ? currentX + x : x
            currentY = isRelative ? currentY + y : y
            points.push({ x: currentX, y: currentY })
          }
          break
        case 'A':
          if (i + 7 < tokens.length) {
            i += 6
            const x = parseFloat(tokens[i])
            const y = parseFloat(tokens[++i])
            currentX = isRelative ? currentX + x : x
            currentY = isRelative ? currentY + y : y
            points.push({ x: currentX, y: currentY })
          }
          break
      }
    }

    return points
  }

  // ---------- Stroke Analysis (exact same as kanji_writing.js) ----------

  _analyzeStroke(points) {
    if (points.length < 2) return null

    const start = points[0]
    const end = points[points.length - 1]
    const dx = end.x - start.x
    const dy = end.y - start.y
    const length = Math.sqrt(dx * dx + dy * dy)

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
      start, end,
    }
  }

  // ---------- Stroke Validation (exact same as kanji_writing.js) ----------

  _validateStroke(drawnPoints, expectedIndex) {
    if (drawnPoints.length < 2) return { valid: false, reason: 'too_short' }

    const vgPoints = drawnPoints.map(p => this._toKanjiVGCoords(p.x, p.y))
    const drawn = this._analyzeStroke(vgPoints)

    if (!drawn || drawn.length < 3) return { valid: false, reason: 'too_short' }

    const validExpected = this.state.analyzedExpected.filter(s => s !== null)
    if (validExpected.length === 0) {
      return { valid: false, reason: 'no_reference_data' }
    }

    const expected = this.state.analyzedExpected[expectedIndex]
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
      if (drawn.direction === 'horizontal') {
        const isExpectedHorizontal = expected.directionality.includes('left-to-right') ||
          expected.directionality.includes('right-to-left')
        if (!isExpectedHorizontal) {
          return { valid: false, reason: 'wrong_direction' }
        }
      } else if (drawn.direction === 'vertical') {
        const isExpectedVertical = expected.directionality.includes('top-to-bottom') ||
          expected.directionality.includes('bottom-to-top')
        if (!isExpectedVertical) {
          return { valid: false, reason: 'wrong_direction' }
        }
      } else if (drawn.direction.startsWith('diagonal')) {
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
}
