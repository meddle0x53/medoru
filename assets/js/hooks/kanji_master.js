/**
 * Kanji Master — endless kanji-writing survival game hook.
 *
 * Adapted from the KanjiWriting hook's SVG path parsing and geometric
 * stroke validation, but fully self-contained: game state (lives, coins,
 * ladder, shop, upgrades) lives here and only the final score is pushed
 * to the server. The original kanji_writing.js is intentionally untouched
 * so daily/lesson challenges keep their behavior.
 */

const SVG_NS = 'http://www.w3.org/2000/svg'

// ---------------------------------------------------------------------------
// SVG path parsing + stroke analysis (adapted from kanji_writing.js)
// ---------------------------------------------------------------------------

function parsePath(pathStr) {
  const points = []
  let currentX = 0
  let currentY = 0

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

function analyzeStroke(points) {
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

  let minX = start.x
  let maxX = start.x
  let minY = start.y
  let maxY = start.y
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
    minX,
    maxX,
    minY,
    maxY,
    start,
    end
  }
}

// ---------------------------------------------------------------------------
// Upgrade definitions
// ---------------------------------------------------------------------------

const UPGRADE_COLORS = {
  blue: '#3b82f6',
  purple: '#a855f7',
  orange: '#f97316',
  silver: '#c0c0c0',
  cyan: '#06b6d4'
}

const MAX_UPGRADE_INDEX = 12

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

const KanjiMaster = {
  mounted() {
    this.pool = JSON.parse(this.el.dataset.pool || '[]')
    if (this.pool.length === 0) return

    this.questionTemplate = this.el.dataset.questionTemplate || 'Draw the kanji for %{word}（%{reading}）— %{meaning}'
    this.questionFallback = this.el.dataset.questionFallback || 'Draw the kanji with these readings'
    this.kunLabel = this.el.dataset.kunLabel || 'KUN'
    this.onLabel = this.el.dataset.onLabel || 'ON'

    this.state = {
      lives: parseInt(this.el.dataset.startLives || '15', 10),
      coins: parseInt(this.el.dataset.startCoins || '0', 10),
      hints: parseInt(this.el.dataset.startHints || '5', 10),
      score: 0,
      completedKanji: 0,
      cycle: 1,
      rung: 0, // index into this.rungs
      usedCharacters: new Set(),
      skippedCharacters: new Set(),
      upgrades: {}, // 1-based stroke index -> color name
      current: null, // { kanji, analyzed, validCount, strokeIndex }
      showingHint: false,
      drawing: false,
      points: [],
      over: false
    }

    // Stroke-count ladder: rung 0 = 1-3 strokes, then 4, 5, ... up to the
    // max stroke count available in the pool.
    const maxStrokes = Math.max(...this.pool.map((k) => k.stroke_count || 0))
    const rungs = []
    if (maxStrokes >= 1) rungs.push([1, Math.min(3, maxStrokes)])
    for (let n = 4; n <= maxStrokes; n++) rungs.push([n, n])
    this.rungs = rungs.filter(([lo, hi]) => this.pool.some((k) => {
      const c = k.stroke_count || 0
      return c >= lo && c <= hi
    }))

    this.canvasWrap = this.el.querySelector('#km-canvas-wrap')
    this.buildCanvas()
    this.bindHelp()
    if (!this.restoreRun()) {
      this.nextKanji()
    } else {
      this.redraw()
      this.updateProgress()
    }
    this.updateHud()
  },

  // -- kanji selection ------------------------------------------------------

  pickKanji() {
    const { usedCharacters, skippedCharacters } = this.state
    const [lo, hi] = this.rungs[this.state.rung]
    const candidates = this.pool.filter((k) => {
      const c = k.stroke_count || 0
      return (
        c >= lo &&
        c <= hi &&
        !skippedCharacters.has(k.character) &&
        (this.state.cycle === 1 || !usedCharacters.has(k.character))
      )
    })

    if (candidates.length === 0) {
      // Rungs with no unused kanji left are dropped from the ladder; if
      // none remain at all, the pool is exhausted.
      this.rungs = this.rungs.filter((_, i) => {
        if (i === this.state.rung) return false
        const [l, h] = this.rungs[i]
        return this.pool.some((k) => {
          const c = k.stroke_count || 0
          return (
            c >= l &&
            c <= h &&
            !skippedCharacters.has(k.character) &&
            (this.state.cycle === 1 || !usedCharacters.has(k.character))
          )
        })
      })

      if (this.rungs.length === 0) {
        this.gameOver('exhausted')
        return null
      }
      this.state.rung = this.state.rung % this.rungs.length
      return this.pickKanji()
    }

    return candidates[Math.floor(Math.random() * candidates.length)]
  },

  nextKanji() {
    const kanji = this.pickKanji()
    if (!kanji) return

    const strokes = (kanji.stroke_data.strokes || []).filter((s) => s.path)
    const analyzed = strokes.map((s, i) => {
      const points = parsePath(s.path)
      const a = analyzeStroke(points)
      return a ? { ...a, index: i, originalPath: s.path } : null
    })
    const validCount = analyzed.filter((a) => a !== null).length

    this.state.current = { kanji, analyzed, validCount, strokeIndex: 0 }
    this.state.showingHint = false
    this.state.usedCharacters.add(kanji.character)
    this.showKanjiCharacter(kanji.character)
    this.redraw()
    this.updateProgress()
    // Persist the fresh kanji so a refresh mid-run resumes here, not on
    // the previous (already completed) kanji.
    this.saveRun()
  },

  // -- canvas ---------------------------------------------------------------

  buildCanvas() {
    const size = Math.min(window.innerWidth - 32, window.innerHeight - 180, 380)
    const dpr = window.devicePixelRatio || 1
    const canvas = document.createElement('canvas')
    canvas.width = size * dpr
    canvas.height = size * dpr
    canvas.style.width = `${size}px`
    canvas.style.height = `${size}px`
    canvas.style.cursor = 'crosshair'
    canvas.style.touchAction = 'none'
    this.canvasWrap.appendChild(canvas)
    this.canvas = canvas
    this.ctx = canvas.getContext('2d')
    // All drawing code works in CSS pixels; scale the backing store by dpr
    // so strokes stay crisp on high-density (mobile) screens.
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    this.size = size
    // KanjiVG is a 109 (or 100) unit box; keep the -15 offset convention.
    this.viewBoxSize = 109
    this.scale = size / this.viewBoxSize
    this.offsetX = 0
    this.offsetY = -15 * (size / 300)

    this.onPointerDown = (e) => {
      if (this.state.over || !this.state.current) return
      if (this.state.current.strokeIndex >= this.state.current.validCount) return
      e.preventDefault()
      canvas.setPointerCapture(e.pointerId)
      this.state.drawing = true
      this.state.points = [this.eventPoint(e)]
      this.strokeStyle('#1f2937')
      this.beginStroke(this.state.points[0])
    }
    this.onPointerMove = (e) => {
      if (!this.state.drawing) return
      e.preventDefault()
      const p = this.eventPoint(e)
      this.state.points.push(p)
      this.lineTo(p)
    }
    this.onPointerUp = () => {
      if (!this.state.drawing) return
      this.state.drawing = false
      if (this.state.points.length < 2) {
        this.state.points = []
        return
      }
      this.handleStroke(this.state.points)
      this.state.points = []
    }

    canvas.addEventListener('pointerdown', this.onPointerDown)
    canvas.addEventListener('pointermove', this.onPointerMove)
    canvas.addEventListener('pointerup', this.onPointerUp)
  },

  eventPoint(e) {
    const rect = this.canvas.getBoundingClientRect()
    return { x: e.clientX - rect.left, y: e.clientY - rect.top }
  },

  toVg(p) {
    return {
      x: (p.x - this.offsetX) / this.scale,
      y: (p.y - this.offsetY) / this.scale
    }
  },

  strokeStyle(color) {
    this.ctx.strokeStyle = color
    this.ctx.lineWidth = 4
    this.ctx.lineCap = 'round'
    this.ctx.lineJoin = 'round'
  },

  beginStroke(p) {
    this.ctx.beginPath()
    this.ctx.moveTo(p.x, p.y)
  },

  lineTo(p) {
    this.ctx.lineTo(p.x, p.y)
    this.ctx.stroke()
  },

  drawGrid() {
    const s = this.size
    const c = this.ctx
    c.strokeStyle = '#e5e7eb'
    c.lineWidth = 1
    c.beginPath()
    c.moveTo(0, s / 2)
    c.lineTo(s, s / 2)
    c.moveTo(s / 2, 0)
    c.lineTo(s / 2, s)
    c.moveTo(0, 0)
    c.lineTo(s, s)
    c.moveTo(s, 0)
    c.lineTo(0, s)
    c.stroke()
  },

  drawCurvedStroke(path, color, width = 5, alpha = 1) {
    const c = this.ctx
    c.save()
    c.strokeStyle = color
    c.lineWidth = width
    c.lineCap = 'round'
    c.lineJoin = 'round'
    c.globalAlpha = alpha
    c.translate(this.offsetX, this.offsetY)
    c.scale(this.scale, this.scale)
    c.stroke(new Path2D(path))
    c.restore()
  },

  showKanjiCharacter(character) {
    // Next-stroke guide: draw the target kanji lightly as a reference.
    this.currentCharacter = character
  },

  redraw() {
    const c = this.ctx
    c.clearRect(0, 0, this.canvas.width, this.canvas.height)
    this.drawGrid()

    const { current } = this.state
    if (!current) return

    // Yellow hint for the stroke the player must (re)draw — shown after a
    // wrong stroke, exactly like the original writing component.
    if (this.state.showingHint) {
      const hint = current.analyzed[current.strokeIndex]
      if (hint) this.drawCurvedStroke(hint.originalPath, '#fbbf24', 5, 0.7)
    }

    // Completed strokes
    for (let i = 0; i < current.strokeIndex; i++) {
      const a = current.analyzed[i]
      if (!a) continue
      const colorName = this.state.upgrades[i + 1]
      const color = colorName ? UPGRADE_COLORS[colorName] : '#22c55e'
      this.drawCurvedStroke(a.originalPath, color, 5, 1)
    }
  },

  // -- stroke validation ----------------------------------------------------

  validateStroke(drawnPoints, expectedIndex) {
    if (drawnPoints.length < 2) return { valid: false }
    const vgPoints = drawnPoints.map((p) => this.toVg(p))
    const drawn = analyzeStroke(vgPoints)
    if (!drawn || drawn.length < 3) return { valid: false }

    const expected = this.state.current.analyzed[expectedIndex]
    if (!expected) return { valid: false }

    const lengthRatio = drawn.length / expected.length
    if (lengthRatio < 0.3 || lengthRatio > 3.0) return { valid: false }

    const dist = (a, b) => Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2)
    if (dist(drawn.start, expected.start) > 12) return { valid: false }
    if (dist(drawn.end, expected.end) > 18) return { valid: false }
    if (dist({ x: drawn.centerX, y: drawn.centerY }, { x: expected.centerX, y: expected.centerY }) > 25)
      return { valid: false }

    if (drawn.direction !== expected.direction) {
      const bothDiagonal =
        drawn.direction.startsWith('diagonal') && expected.direction.startsWith('diagonal')
      if (!bothDiagonal) return { valid: false }
    }

    return { valid: true }
  },

  // -- core game logic ------------------------------------------------------

  handleStroke(points) {
    const { current } = this.state
    const i = current.strokeIndex
    const validation = this.validateStroke(points, i)

    if (validation.valid) {
      this.onCorrectStroke(i)
    } else {
      this.onWrongStroke(i, points)
    }
  },

  onCorrectStroke(i) {
    const { current } = this.state
    this.state.showingHint = false
    const upgrade = this.state.upgrades[i + 1]
    let gained = 1

    if (upgrade === 'blue') gained = 2
    if (upgrade === 'purple') gained = Math.random() < 0.5 ? 3 : 1
    if (upgrade === 'orange') gained = 5
    if (upgrade === 'cyan') gained = 5
    if (upgrade === 'silver' && Math.random() < 0.1) {
      this.state.lives += 1
    }

    this.state.score += gained
    current.strokeIndex += 1
    this.updateHud()
    this.animate('km-score', 'km-anim-bump')
    this.floatScore(`+${gained}`, upgrade ? '#f97316' : '#22c55e')
    if (upgrade === 'silver') this.animate('km-lives', 'km-anim-bump')
    this.redraw()

    if (current.strokeIndex >= current.validCount) {
      this.completeKanji()
    } else {
      this.saveRun()
    }
  },

  // Shared kanji-completion logic for both the normal and the
  // yellow-charge (hint) path: ladder advance, +1 coin and the shop
  // exactly every 5 completed kanji.
  completeKanji() {
    this.state.completedKanji += 1
    this.state.hints += 1
    this.advanceLadder()
    if (this.state.completedKanji % 5 === 0) {
      this.state.coins += 1
      this.updateHud()
      this.openShop()
    } else {
      this.updateHud()
      setTimeout(() => this.nextKanji(), 400)
    }
    this.saveRun()
  },

  onWrongStroke(i, points) {
    const upgrade = this.state.upgrades[i + 1]

    // Life loss always happens: cycle 1 = 1 life, cycle 2 = 2, ... Orange
    // adds +1. Yellow strokes are hint charges only — they never prevent
    // the loss.
    let loss = this.state.cycle
    if (upgrade === 'orange') loss = this.state.cycle + 1
    if (upgrade === 'cyan') this.state.coins = Math.max(0, this.state.coins - 5)

    this.state.lives -= loss

    // Hint charge: consumed once per stroke — the first error on a stroke
    // shows the yellow guide; further errors on the SAME stroke don't
    // consume another charge (the guide stays visible). With no charges
    // left, errors show no guide at all until more charges are gained.
    if (!this.state.showingHint && this.state.hints > 0) {
      this.state.hints -= 1
      this.state.showingHint = true
      this.animate('km-hints', 'km-anim-hit')
    }

    // Show the wrong stroke raw in red (no snap); the player must draw
    // THIS stroke again until it is correct.
    this.strokeStyle('#ef4444')
    this.beginStroke(points[0])
    points.forEach((p) => this.lineTo(p))

    this.updateHud()
    this.animate('km-lives', 'km-anim-hit')
    if (upgrade === 'cyan') this.animate('km-coins', 'km-anim-hit')

    if (this.state.lives <= 0) {
      this.gameOver('lives')
    } else {
      this.saveRun()
      setTimeout(() => this.redraw(), 300)
    }
  },

  advanceLadder() {
    this.state.rung += 1
    if (this.state.rung >= this.rungs.length) {
      this.state.rung = 0
      this.state.cycle += 1
    }
  },

  // -- HUD ------------------------------------------------------------------

  setCount(id, n) {
    const el = document.getElementById(id)
    if (el) el.textContent = String(n)
  },

  // Adds a temporary animation class to a HUD counter.
  animate(id, cls) {
    const el = document.getElementById(id)
    if (!el) return
    el.classList.remove(cls)
    // force reflow so repeated triggers restart the animation
    void el.offsetWidth
    el.classList.add(cls)
    setTimeout(() => el.classList.remove(cls), 450)
  },

  // Floating "+N" badge above the score counter.
  floatScore(text, color) {
    const score = document.getElementById('km-score')
    if (!score) return
    const badge = document.createElement('span')
    badge.className = 'km-float-score'
    badge.style.color = color
    badge.textContent = text
    score.parentElement.style.position = 'relative'
    score.parentElement.appendChild(badge)
    setTimeout(() => badge.remove(), 850)
  },

  updateHud() {
    this.setCount('km-lives-count', this.state.lives)
    this.setCount('km-coins-count', this.state.coins)
    this.setCount('km-hints-count', this.state.hints)
    const scoreEl = document.getElementById('km-score')
    if (scoreEl) scoreEl.textContent = String(this.state.score)
  },

  updateProgress() {
    const { current } = this.state
    const q = document.getElementById('km-question')
    const r = document.getElementById('km-readings')
    const p = document.getElementById('km-progress')
    if (!current) return

    const { kanji, strokeIndex, validCount } = this.state.current
    const word = kanji.word
    if (q) {
      if (word) {
        if (word.text === kanji.character) {
          // The kanji IS the whole word — show the reading only.
          q.textContent = word.reading
        } else {
          // Never reveal the target kanji: mask every occurrence in the word.
          const masked = word.text.split(kanji.character).join('◯')
          q.textContent = this.questionTemplate
            .replace('%{word}', masked)
            .replace('%{reading}', word.reading)
            .replace('%{meaning}', word.meaning)
        }
      } else {
        q.textContent = this.questionFallback
      }
    }
    if (r) {
      const kun = (kanji.kun || []).join('、')
      const on = (kanji.on || []).join('、')
      const parts = []
      if (kun) parts.push(`${this.kunLabel}: ${kun}`)
      if (on) parts.push(`${this.onLabel}: ${on}`)
      r.textContent = parts.join('　·　')
    }
    const m = document.getElementById('km-meanings')
    if (m) m.textContent = (kanji.meanings || []).join(', ')
    if (p) p.textContent = `${strokeIndex}/${validCount}`
  },

  bindHelp() {
    const btn = document.getElementById('km-help-btn')
    const overlay = document.getElementById('km-help-overlay')
    const close = document.getElementById('km-help-close')
    if (btn && overlay) btn.addEventListener('click', () => overlay.classList.remove('hidden'))
    if (close && overlay) close.addEventListener('click', () => overlay.classList.add('hidden'))
  },

  // -- run persistence (localStorage) ----------------------------------------

  saveRun() {
    if (this.state.over) return
    const { current } = this.state
    const snapshot = {
      lives: this.state.lives,
      coins: this.state.coins,
      hints: this.state.hints,
      score: this.state.score,
      completedKanji: this.state.completedKanji,
      cycle: this.state.cycle,
      rung: this.state.rung,
      usedCharacters: [...this.state.usedCharacters],
      skippedCharacters: [...this.state.skippedCharacters],
      upgrades: this.state.upgrades,
      currentCharacter: current ? current.kanji.character : null,
      strokeIndex: current ? current.strokeIndex : 0
    }
    try {
      localStorage.setItem('kanjiMasterRun', JSON.stringify(snapshot))
    } catch (_e) {}
  },

  clearRun() {
    try {
      localStorage.removeItem('kanjiMasterRun')
    } catch (_e) {}
  },

  restoreRun() {
    try {
      const raw = localStorage.getItem('kanjiMasterRun')
      if (!raw) return false
      const s = JSON.parse(raw)
      const kanji = this.pool.find((k) => k.character === s.currentCharacter)
      if (!kanji || typeof s.lives !== 'number') {
        this.clearRun()
        return false
      }

      this.state.lives = s.lives
      this.state.coins = s.coins
      this.state.hints = s.hints
      this.state.score = s.score
      this.state.completedKanji = s.completedKanji
      this.state.cycle = s.cycle
      this.state.rung = s.rung
      this.state.usedCharacters = new Set(s.usedCharacters || [])
      this.state.skippedCharacters = new Set(s.skippedCharacters || [])
      this.state.upgrades = s.upgrades || {}

      const strokes = (kanji.stroke_data.strokes || []).filter((st) => st.path)
      const analyzed = strokes.map((st, i) => {
        const pts = parsePath(st.path)
        const a = analyzeStroke(pts)
        return a ? { ...a, index: i, originalPath: st.path } : null
      })
      this.state.current = {
        kanji,
        analyzed,
        validCount: analyzed.filter((a) => a !== null).length,
        strokeIndex: Math.min(s.strokeIndex || 0, analyzed.length)
      }

      // If the snapshot was taken while the shop was open (or during the
      // short transition), the saved kanji is already complete — advance
      // to the next one instead of restoring a stuck state.
      if (this.state.current.strokeIndex >= this.state.current.validCount) {
        this.nextKanji()
      }
      return true
    } catch (_e) {
      this.clearRun()
      return false
    }
  },

  // -- shop -----------------------------------------------------------------

  shopPrices() {
    return {
      life: 5,
      hint: 1,
      pack: 4 + Math.floor(Math.random() * 3), // 4-6
      skip: 5
    }
  },

  openShop() {
    const overlay = document.getElementById('km-shop-overlay')
    if (!overlay) return this.nextKanji()
    this.shopBound = this.shopBound || this.bindShop()
    this.refreshShop()
    overlay.classList.remove('hidden')
  },

  closeShop() {
    const overlay = document.getElementById('km-shop-overlay')
    if (overlay) overlay.classList.add('hidden')
    if (this.state.over) return
    this.nextKanji()
    this.saveRun()
  },

  bindShop() {
    const bind = (id, fn) => {
      const el = document.getElementById(id)
      if (el) el.addEventListener('click', fn)
    }
    bind('km-shop-close', () => this.closeShop())
    bind('km-buy-life', () => this.buyItem('life', 'km-buy-life'))
    bind('km-buy-hint', () => this.buyItem('hint', 'km-buy-hint'))
    bind('km-buy-pack', () => this.buyItem('pack', 'km-buy-pack'))
    bind('km-buy-skip', () => this.buyItem('skip', 'km-buy-skip'))
    return true
  },

  refreshShop() {
    const prices = this.shopPrices_cached || (this.shopPrices_cached = this.shopPrices())
    this.currentPrices = prices
    document.getElementById('km-shop-coins').textContent = String(this.state.coins)

    const configure = (id, price) => {
      const btn = document.getElementById(id)
      if (!btn) return
      btn.querySelector('.km-price').textContent = `${price} 🪙`
      if (this.state.coins < price) {
        btn.setAttribute('disabled', '')
        btn.classList.add('btn-disabled')
        btn.classList.remove('btn-primary')
      } else {
        btn.removeAttribute('disabled')
        btn.classList.remove('btn-disabled')
        btn.classList.add('btn-primary')
      }
    }

    configure('km-buy-life', prices.life)
    configure('km-buy-hint', prices.hint)
    configure('km-buy-pack', prices.pack)
    configure('km-buy-skip', prices.skip)
  },

  buyItem(kind, btnId) {
    const price = this.currentPrices[kind]
    if (this.state.coins < price) return
    this.state.coins -= price
    this.updateHud()

    if (kind === 'life') {
      this.state.lives += 1
      this.updateHud()
    }
    if (kind === 'hint') {
      this.state.hints += 1
      this.updateHud()
    }
    if (kind === 'pack') this.showPackOffers()
    if (kind === 'skip') this.showSkipPicker()

    this.refreshShop()
    this.saveRun()
  },

  showPackOffers() {
    const offers = []
    const owned = this.state.upgrades
    const maxIndex = Math.min(
      MAX_UPGRADE_INDEX,
      Math.max(...this.pool.map((k) => k.stroke_count || 1))
    )

    // Already-upgraded stroke indices are offered at 40% weight compared
    // to the others, so re-rolls are possible but rarer.
    const pickIndex = () => {
      const indices = Array.from({ length: maxIndex }, (_, i) => i + 1)
      const weights = indices.map((idx) => (owned[idx] ? 0.4 : 1))
      const total = weights.reduce((a, b) => a + b, 0)
      let roll = Math.random() * total
      for (let k = 0; k < indices.length; k++) {
        roll -= weights[k]
        if (roll <= 0) return indices[k]
      }
      return indices[indices.length - 1]
    }

    while (offers.length < 3) {
      const index = pickIndex()
      const color = Object.keys(UPGRADE_COLORS)[Math.floor(Math.random() * 5)]
      if (offers.some((o) => o.index === index && o.color === color)) continue
      offers.push({ index, color })
    }

    const box = document.getElementById('km-pack-offers')
    if (!box) return
    box.classList.remove('hidden')
    box.innerHTML = offers
      .map(
        (o, i) => `
        <button data-pick="${i}" class="btn btn-sm w-full btn-outline"
          style="border-color: ${UPGRADE_COLORS[o.color]}; color: ${UPGRADE_COLORS[o.color]}">
          ${o.index} → ${o.color}
        </button>`
      )
      .join('')

    box.querySelectorAll('[data-pick]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const offer = offers[parseInt(btn.dataset.pick, 10)]
        this.state.upgrades[offer.index] = offer.color // same index overrides
        box.innerHTML = ''
        box.classList.add('hidden')
        this.saveRun()
      })
    })
  },

  showSkipPicker() {
    const box = document.getElementById('km-skip-picker')
    if (!box) return
    box.classList.remove('hidden')
    const available = this.pool.filter((k) => !this.state.skippedCharacters.has(k.character))
    box.innerHTML = available
      .map(
        (k) =>
          `<button data-skip-kanji="${k.character}" class="btn btn-xs btn-ghost font-japanese text-lg">${k.character}</button>`
      )
      .join('')

    box.querySelectorAll('[data-skip-kanji]').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.state.skippedCharacters.add(btn.dataset.skipKanji)
        box.innerHTML = ''
        box.classList.add('hidden')
        this.saveRun()
      })
    })
  },

  // -- game over (panel wired in Task 6) ------------------------------------

  gameOver(reason) {
    this.state.over = true
    this.clearRun()
    this.pushEvent('game_over', { score: this.state.score, reason })
  },

  destroyed() {
    if (this.canvas) {
      this.canvas.removeEventListener('pointerdown', this.onPointerDown)
      this.canvas.removeEventListener('pointermove', this.onPointerMove)
      this.canvas.removeEventListener('pointerup', this.onPointerUp)
      this.canvas.remove()
    }
    this.state = null
  }
}

export default KanjiMaster
