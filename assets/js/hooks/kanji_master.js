/**
 * Kanji Master — endless kanji-writing survival game hook.
 *
 * Adapted from the KanjiWriting hook's SVG path parsing and geometric
 * stroke validation, but fully self-contained: game state (lives, coins,
 * ladder, shop, upgrades) lives here and only the final score is pushed
 * to the server. The original kanji_writing.js is intentionally untouched
 * so daily/lesson challenges keep their behavior.
 */

import { pathEndpoints } from "../lib/svg_path"
import {
  classifyStrokePath,
  tolerancesForShape
} from "../lib/stroke_shape"

const SVG_NS = 'http://www.w3.org/2000/svg'

// ---------------------------------------------------------------------------
// SVG path parsing + stroke analysis (adapted from kanji_writing.js)
// ---------------------------------------------------------------------------

const parsePath = pathEndpoints

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
  cyan: '#06b6d4',
  momo: '#f9a8d4',
  kaki: '#f35336',
  toki: '#f5a27d',
  fuji: '#8b81c3'
}

const MAX_UPGRADE_INDEX = 12

// Level structure: each level draws up to 4 unused learned kanji from its
// stroke range. After level 5 (and the boss, if one triggers) a new pass
// starts at level 1 with the base error cost — the cycle increments, the
// way the old ladder wrap did.
const LEVELS = [
  { min: 1, max: 6 },
  { min: 7, max: 10 },
  { min: 11, max: 14 },
  { min: 15, max: 18 },
  { min: 19, max: Infinity }
]

// Perfect-kanji bonus per level: at most `max` wrong attempts on the kanji
// earns `hints` yellow strokes and `coins` coins on completion.
const PERFECT_BONUS = [
  { max: 0, hints: 1, coins: 1 },
  { max: 1, hints: 2, coins: 2 },
  { max: 2, hints: 3, coins: 4 },
  { max: 3, hints: 5, coins: 7 },
  { max: 4, hints: 10, coins: 15 }
]

// Boss debuffs, keyed by effect. `hidden` has no color — it only blocks
// yellow hints on its stroke.
const DEBUFF_COLORS = {
  suppressed: '#15803d',
  black: '#000000',
  brightred: '#ff1f1f',
  trap: '#be185d',
  fluor: '#ccff00'
}

// Page/label accent color per level — matches the km-level-* border colors.
const LEVEL_COLORS = {
  1: '#3b82f6',
  2: '#a855f7',
  3: '#c0c0c0',
  4: '#06b6d4',
  5: '#f9a8d4',
  boss: '#f97316'
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

const KanjiMaster = {
  mounted() {
    this.pool = JSON.parse(this.el.dataset.pool || '[]')
    if (this.pool.length === 0) return
    this.bossPool = JSON.parse(this.el.dataset.bossPool || '[]')

    this.questionTemplate = this.el.dataset.questionTemplate || 'Draw the kanji for %{word}（%{reading}）— %{meaning}'
    this.questionFallback = this.el.dataset.questionFallback || 'Draw the kanji with these readings'
    this.kunLabel = this.el.dataset.kunLabel || 'KUN'
    this.onLabel = this.el.dataset.onLabel || 'ON'
    this.statusStrokeLabel = this.el.dataset.statusStrokeLabel || 'Stroke %{n}'
    this.statusNoneLabel = this.el.dataset.statusNoneLabel || 'No upgrade'
    this.perfectLabel = this.el.dataset.perfectLabel || 'Perfect!'
    this.bossLabel = this.el.dataset.bossLabel || 'Boss'
    try {
      this.upgradeNames = JSON.parse(this.el.dataset.upgradeNames || '{}')
    } catch (_e) {
      this.upgradeNames = {}
    }

    this.state = {
      lives: parseInt(this.el.dataset.startLives || '15', 10),
      coins: parseInt(this.el.dataset.startCoins || '0', 10),
      hints: parseInt(this.el.dataset.startHints || '5', 10),
      score: 0,
      completedKanji: 0,
      cycle: 1,
      levelIndex: 0, // index into LEVELS
      levelQueue: [], // remaining entries of the current level: {kanji, boss}
      levelsBuilt: new Set(), // level indices already built in this pass
      bossActive: false,
      mistakes: 0, // wrong attempts on the current kanji
      usedCharacters: new Set(),
      skippedCharacters: new Set(),
      upgrades: {}, // 1-based stroke index -> color name
      pack: null, // current store pack: [{index, color}] or null
      packCost: 5, // random 4-6 coins, rolled per pack
      packBought: false, // whether the current pack was paid for (offers revealed)
      rerollCost: 1, // coins for the next re-roll within this store visit
      shopOpen: false,
      // Per-shop-visit purchase limits (reset every time the shop opens).
      shopBuys: { pack: 0, life: 0, hint: 0, skip: 0 },
      shopLimits: { pack: 2, life: 4, hint: 7, skip: 2 },
      current: null, // { kanji, analyzed, validCount, strokeIndex }
      showingHint: false,
      drawing: false,
      points: [],
      over: false
    }

    // Levels are built lazily from the pool in pickEntry(); nothing to
    // precompute here.

    this.canvasWrap = this.el.querySelector('#km-canvas-wrap')
    this.buildCanvas()
    this.bindHelp()
    this.bindStatus()
    this.bindGiveUp()
    if (!this.restoreRun()) {
      // Fresh run: show the shop once before the first kanji.
      this.nextKanji()
      this.openShop()
    } else {
      this.redraw()
      this.updateProgress()
    }
    this.updateHud()
  },

  // -- kanji selection ------------------------------------------------------

  // Picks the next {kanji, boss} entry: a final-boss kanji while bossActive,
  // otherwise the next queued level kanji (whose LAST entry is the level
  // boss), building/skipping levels as needed.
  pickEntry() {
    if (this.state.bossActive) {
      if (this.bossPool.length === 0) {
        this.state.bossActive = false
      } else {
        return { kanji: this.bossPool[Math.floor(Math.random() * this.bossPool.length)], boss: true }
      }
    }

    for (;;) {
      if (this.state.levelIndex >= LEVELS.length) {
        // Pass complete. 10% chance to face a boss kanji first; otherwise
        // (or when no boss kanji exist) a new pass starts at level 1 with
        // the base error cost — the old ladder-wrap behavior.
        if (this.bossPool.length > 0 && Math.random() < 0.1) {
          this.state.bossActive = true
          return this.pickEntry()
        }
        if (this.state.cycle > 1 && !this.unusedKanjiRemain()) {
          this.gameOver('exhausted')
          return null
        }
        this.state.cycle += 1
        this.state.levelIndex = 0
        this.state.levelsBuilt = new Set()
        continue
      }

      if (this.state.levelQueue.length > 0) {
        return this.state.levelQueue.shift()
      }

      // Each level is built exactly once per pass. When its queue drains we
      // advance to the next level even if this one still has unused kanji —
      // leftovers wait for the next pass (New Game+). Levels with nothing
      // the player can draw are skipped silently.
      if (!this.state.levelsBuilt.has(this.state.levelIndex)) {
        this.state.levelsBuilt.add(this.state.levelIndex)
        if (this.buildLevelQueue()) continue
      }
      this.state.levelIndex += 1
    }
  },

  unusedKanjiRemain() {
    const { usedCharacters, skippedCharacters } = this.state
    return this.pool.some(
      (k) => !skippedCharacters.has(k.character) && !usedCharacters.has(k.character)
    )
  },

  // Fills the current level's queue: one kanji per stroke-count step, in
  // order — level 1 is a 1-3 stroke kanji, then a 4, then a 5, then a 6;
  // level 2 is 7, 8, 9, 10; ... level 5 is four 19+ kanji. Steps the player
  // has no unused kanji for are skipped, so a level can have fewer than 4.
  // The level advances when its queue drains, even if lower stroke counts
  // still have unused kanji — those wait for the next pass. The LAST kanji
  // is the boss (the highest-stroke one). Returns false when the level has
  // nothing unused left.
  buildLevelQueue() {
    const { usedCharacters, skippedCharacters } = this.state
    const { min, max } = LEVELS[this.state.levelIndex]
    const pickable = (k) =>
      !skippedCharacters.has(k.character) && !usedCharacters.has(k.character)

    let ordered
    if (min === 19) {
      // Level 5: four 19+ kanji, ascending, highest last (the boss).
      const candidates = this.pool
        .filter((k) => (k.stroke_count || 0) >= 19 && pickable(k))
        .sort((a, b) => (a.stroke_count || 0) - (b.stroke_count || 0))
      ordered = candidates.slice(0, 4)
    } else {
      // One kanji per step: the 1-3 band first (level 1 only), then each
      // single stroke count climbing to the level's max. Steps with no
      // unused kanji are simply skipped.
      ordered = []
      const takeOfStrokes = (list) => {
        if (!list.length || ordered.length >= 4) return
        ordered.push(list[Math.floor(Math.random() * list.length)])
      }
      if (min === 1) {
        takeOfStrokes(this.pool.filter((k) => {
          const c = k.stroke_count || 0
          return c >= 1 && c <= 3 && pickable(k)
        }))
      }
      for (let c = min === 1 ? 4 : min; c <= max; c++) {
        takeOfStrokes(this.pool.filter((k) => (k.stroke_count || 0) === c && pickable(k)))
      }
    }

    if (ordered.length === 0) return false
    this.state.levelQueue = ordered.map((kanji, i, arr) => ({
      kanji,
      boss: i === arr.length - 1
    }))
    return true
  },

  // Colored border per level (the component background itself is untouched).
  applyLevelBackground() {
    const cls = this.state.bossActive
      ? 'km-level-boss'
      : `km-level-${Math.min(this.state.levelIndex + 1, LEVELS.length)}`
    LEVELS.forEach((_, i) => this.el.classList.remove(`km-level-${i + 1}`))
    this.el.classList.remove('km-level-boss')
    this.el.classList.add(cls)
    this.updateBossLabel()
  },

  // "Boss" label under the drawing area: visible only while a boss kanji is
  // active, tinted with the current level's accent color.
  updateBossLabel() {
    const el = document.getElementById('km-boss-label')
    if (!el) return
    const { current } = this.state
    const isBoss = !!(current && current.boss)
    el.classList.toggle('hidden', !isBoss)
    if (isBoss) {
      el.textContent = this.bossLabel
      const key =
        current.level === 'boss' ? 'boss' : Math.min(current.level + 1, LEVELS.length)
      el.style.color = LEVEL_COLORS[key]
    }
  },

  // Rolls `count` distinct debuffed stroke indices (1-based) for a boss
  // kanji. Each index gets one random effect; `suppressed` only rolls on
  // strokes that carry a purchased upgrade (otherwise it would be a no-op).
  generateDebuffs(kanji, validCount, count) {
    const strokeCount = kanji.stroke_count || validCount
    const indices = []
    for (let n = 1; n <= strokeCount; n++) indices.push(n)
    for (let i = indices.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[indices[i], indices[j]] = [indices[j], indices[i]]
    }

    const debuffs = {}
    for (const idx of indices.slice(0, Math.min(count, indices.length))) {
      const effects = ['black', 'brightred', 'hidden', 'trap']
      if (this.state.upgrades[idx]) effects.push('suppressed', 'fluor')
      debuffs[idx] = effects[Math.floor(Math.random() * effects.length)]
    }
    return debuffs
  },

  nextKanji() {
    const entry = this.pickEntry()
    if (!entry) return
    const kanji = entry.kanji

    const strokes = (kanji.stroke_data.strokes || []).filter((s) => s.path)
    const analyzed = strokes.map((s, i) => {
      const points = parsePath(s.path)
      const a = analyzeStroke(points)
      return a ? { ...a, index: i, originalPath: s.path, ...classifyStrokePath(s.path) } : null
    })
    const validCount = analyzed.filter((a) => a !== null).length

    // Remember which level this kanji belongs to — the perfect-kanji bonus
    // is graded by it on completion.
    const level = this.state.bossActive
      ? 'boss'
      : Math.min(this.state.levelIndex, LEVELS.length - 1)
    const isBoss = entry.boss || this.state.bossActive

    // Boss kanji carry debuffed strokes: a level boss gets levelIndex+1, the
    // final boss a random 1-10.
    const debuffCount = !isBoss
      ? 0
      : level === 'boss'
        ? 1 + Math.floor(Math.random() * 10)
        : level + 1
    const debuffs = debuffCount > 0 ? this.generateDebuffs(kanji, validCount, debuffCount) : null

    this.state.current = { kanji, analyzed, validCount, strokeIndex: 0, level, boss: isBoss, debuffs }
    this.state.showingHint = false
    this.state.mistakes = 0
    this.state.usedCharacters.add(kanji.character)
    this.showKanjiCharacter(kanji.character)
    this.logExpectedStroke()
    this.applyLevelBackground()
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

  // Console log of the shape of the stroke the player is EXPECTED to draw
  // right now (fired when a stroke becomes current, not when it is drawn).
  logExpectedStroke() {
    const { current } = this.state
    if (!current) return
    const stroke = current.analyzed[current.strokeIndex]
    if (!stroke) return
    console.log(
      `[kanji-master] expected stroke #${current.strokeIndex + 1}: ${stroke.shape}${stroke.shapeDetail ? ` (${stroke.shapeDetail})` : ''}`
    )
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
      const debuff = current.debuffs ? current.debuffs[i + 1] : null
      const colorName = this.state.upgrades[i + 1]
      const color =
        (debuff && DEBUFF_COLORS[debuff]) ||
        (colorName ? UPGRADE_COLORS[colorName] : '#22c55e')
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

    // Hooks (钩, 卧钩/弯钩) and 横撇 corners get a looser end/center gate;
    // plain 撇 sweeps a little forgiving; straight strokes keep strict gates.
    // See tolerancesForShape in lib/stroke_shape.js.
    const { end: endTolerance, center: centerTolerance } = tolerancesForShape(
      expected.shape,
      expected.shapeDetail
    )

    const lengthRatio = drawn.length / expected.length
    if (lengthRatio < 0.3 || lengthRatio > 3.0) return { valid: false }

    const dist = (a, b) => Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2)
    if (dist(drawn.start, expected.start) > 12) return { valid: false }
    if (dist(drawn.end, expected.end) > endTolerance) return { valid: false }
    if (dist({ x: drawn.centerX, y: drawn.centerY }, { x: expected.centerX, y: expected.centerY }) > centerTolerance)
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
    const debuff = current.debuffs ? current.debuffs[i + 1] : null
    // Black strokes score 0; suppressed strokes keep their upgrade's LOSE
    // effects but lose its WIN effects. Both skip the upgrade win logic.
    const winSuppressed = debuff === 'black' || debuff === 'suppressed'
    // Fluorescent boss debuff: on an upgraded stroke, 20% chance the
    // upgrade's WIN effect is doubled (+10 toki, +2 lives silver, ...).
    const fluorWinDouble =
      !winSuppressed && debuff === 'fluor' && upgrade && Math.random() < 0.2
    let gained = debuff === 'black' ? 0 : 1

    if (!winSuppressed) {
      if (upgrade === 'blue') gained = 2
      if (upgrade === 'purple') gained = Math.random() < 0.5 ? 3 : 1
      if (upgrade === 'orange') gained = 5
      if (upgrade === 'cyan') gained = 5
      if (upgrade === 'kaki') gained = 2
      if (upgrade === 'toki') gained = 5
      if (upgrade === 'fuji' && Math.random() < 0.6) gained = 3
      if (upgrade === 'silver' && Math.random() < 0.2) {
        this.state.lives += fluorWinDouble ? 2 : 1
      }
      if (upgrade === 'momo' && Math.random() < 0.2) {
        // Jackpot: bonus currencies on top of the normal 1 point.
        this.state.lives += fluorWinDouble ? 2 : 1
        this.state.coins += fluorWinDouble ? 10 : 5
        this.state.hints += fluorWinDouble ? 10 : 5
        this.animate('km-lives', 'km-anim-bump')
        this.animate('km-coins', 'km-anim-bump')
        this.animate('km-hints', 'km-anim-bump')
        this.floatScore(
          fluorWinDouble ? '+2♥ +10🪙 +10' : '+1♥ +5🪙 +5',
          '#f9a8d4'
        )
      }
    }
    if (debuff === 'trap' && Math.random() < 0.5) {
      // Trap: coin flip for an extra life on a right draw.
      this.state.lives += 1
      this.animate('km-lives', 'km-anim-bump')
      this.floatScore('+1♥', DEBUFF_COLORS.trap)
    }

    this.state.score += gained * (fluorWinDouble ? 2 : 1)
    current.strokeIndex += 1
    this.logExpectedStroke()
    this.updateHud()
    this.animate('km-score', 'km-anim-bump')
    this.floatScore(
      `+${gained * (fluorWinDouble ? 2 : 1)}`,
      fluorWinDouble
        ? DEBUFF_COLORS.fluor
        : upgrade && !winSuppressed
          ? '#f97316'
          : '#22c55e'
    )
    if (upgrade === 'silver' && !winSuppressed) this.animate('km-lives', 'km-anim-bump')
    this.redraw()

    if (current.strokeIndex >= current.validCount) {
      this.completeKanji()
    } else {
      this.saveRun()
    }
  },

  // Kanji-completion logic: flat rewards (+1 yellow stroke and +2 coins
  // every completed kanji; every 4th also grants +1 life and opens the
  // shop), plus the perfect-kanji bonus graded by the kanji's level.
  completeKanji() {
    this.state.completedKanji += 1
    this.state.hints += 1
    this.state.coins += 2

    const { level, mistakes } = { level: this.state.current?.level, mistakes: this.state.mistakes }
    if (level === 'boss') {
      // Boss reward applies on every completion, mistakes or not.
      this.state.hints += 50
      this.state.coins += 70
      this.floatScore('+50💛 +70🪙', '#f97316')
      this.animate('km-hints', 'km-anim-bump')
      this.animate('km-coins', 'km-anim-bump')
      this.state.bossActive = false
    } else if (typeof level === 'number') {
      const bonus = PERFECT_BONUS[level]
      if (bonus && mistakes <= bonus.max) {
        this.state.hints += bonus.hints
        this.state.coins += bonus.coins
        const gain = `+${bonus.hints}💛 +${bonus.coins}🪙`
        // The zero-mistake level-1 award gets the "Perfect!" callout.
        this.floatScore(level === 0 && mistakes === 0 ? `${this.perfectLabel} ${gain}` : gain, '#fbbf24')
        this.animate('km-hints', 'km-anim-bump')
        this.animate('km-coins', 'km-anim-bump')
      }
    }

    if (this.state.completedKanji % 4 === 0) {
      this.state.lives += 1
      this.updateHud()
      this.openShop()
    } else {
      this.updateHud()
      setTimeout(() => this.nextKanji(), 400)
    }
    this.saveRun()
  },

  onWrongStroke(i, points) {
    const { current } = this.state
    const upgrade = this.state.upgrades[i + 1]
    const debuff = current.debuffs ? current.debuffs[i + 1] : null
    this.state.mistakes += 1

    // Fluorescent boss debuff: on an upgraded stroke, 80% chance the
    // upgrade's WRONG effects hit twice as hard.
    const fluorWrongDouble = debuff === 'fluor' && upgrade && Math.random() < 0.8
    const fluorTimes = fluorWrongDouble ? 2 : 1

    // Life loss always happens: cycle 1 = 1 life, cycle 2 = 2, ... Orange
    // and momo add +1. Yellow strokes are hint charges only — they never
    // prevent the loss. The bright-red boss debuff costs +1 extra on top of
    // all that.
    let loss = this.state.cycle
    if (upgrade === 'orange') loss = this.state.cycle + fluorTimes
    if (upgrade === 'momo') loss = this.state.cycle + fluorTimes
    if (debuff === 'brightred') loss += 1
    // Cyan: a mistake costs 5 coins; with no coins it costs 1 extra life
    // plus 1 hint charge, and with no hint charges either, 2 extra lives.
    if (upgrade === 'cyan') {
      for (let n = 0; n < fluorTimes; n++) {
        if (this.state.coins >= 5) {
          this.state.coins -= 5
        } else if (this.state.hints > 0) {
          this.state.hints -= 1
          loss += 1
          this.cyanHintPenalty = true
        } else {
          loss += 2
        }
      }
    }
    if (upgrade === 'momo')
      this.state.coins = Math.max(0, this.state.coins - 5 * fluorTimes)
    // Kaki: a mistake also costs 1 point (floored at 0).
    if (upgrade === 'kaki' && this.state.score > 0) {
      const penalty = Math.min(fluorTimes, this.state.score)
      this.state.score -= penalty
      this.floatScore(`-${penalty}`, UPGRADE_COLORS.kaki)
      this.animate('km-score', 'km-anim-hit')
    }
    // Toki: a mistake costs 4 points (floored at 0).
    if (upgrade === 'toki' && this.state.score > 0) {
      const penalty = Math.min(4 * fluorTimes, this.state.score)
      this.state.score -= penalty
      this.floatScore(`-${penalty}`, UPGRADE_COLORS.toki)
      this.animate('km-score', 'km-anim-hit')
    }
    // Fuji: 30% chance a mistake costs 3 points (floored at 0).
    for (let n = 0; n < fluorTimes; n++) {
      if (upgrade === 'fuji' && this.state.score > 0 && Math.random() < 0.3) {
        const penalty = Math.min(3, this.state.score)
        this.state.score -= penalty
        this.floatScore(`-${penalty}`, UPGRADE_COLORS.fuji)
        this.animate('km-score', 'km-anim-hit')
      }
    }

    this.state.lives -= loss

    // Trap: coin flip for 3 extra lives lost on a wrong draw.
    if (debuff === 'trap' && Math.random() < 0.5) {
      this.state.lives -= 3
      this.floatScore('-3♥', DEBUFF_COLORS.trap)
    }

    // Hint charge: consumed once per stroke — the first error on a stroke
    // shows the yellow guide; further errors on the SAME stroke don't
    // consume another charge (the guide stays visible). With no charges
    // left, errors show no guide at all until more charges are gained.
    // Momo strokes are the exception: their hint costs 2 charges, and with
    // exactly 1 charge that charge is consumed but no guide appears.
    // Hidden boss strokes block hints entirely: no guide, no charge.
    if (debuff !== 'hidden') {
      if (upgrade === 'momo') {
        if (!this.state.showingHint) {
          if (this.state.hints >= 2) {
            this.state.hints -= 2
            this.state.showingHint = true
            this.animate('km-hints', 'km-anim-hit')
          } else if (this.state.hints === 1) {
            this.state.hints -= 1
            this.animate('km-hints', 'km-anim-hit')
          }
        }
      } else if (!this.state.showingHint && this.state.hints > 0) {
        this.state.hints -= 1
        this.state.showingHint = true
        this.animate('km-hints', 'km-anim-hit')
      }
    }

    // Show the wrong stroke raw in red (no snap); the player must draw
    // THIS stroke again until it is correct.
    this.strokeStyle('#ef4444')
    this.beginStroke(points[0])
    points.forEach((p) => this.lineTo(p))

    this.updateHud()
    this.animate('km-lives', 'km-anim-hit')
    if (upgrade === 'cyan') {
      this.animate('km-coins', 'km-anim-hit')
      if (this.cyanHintPenalty) {
        this.cyanHintPenalty = false
        this.animate('km-hints', 'km-anim-hit')
      }
    }
    if (upgrade === 'momo') this.animate('km-coins', 'km-anim-hit')

    if (this.state.lives <= 0) {
      this.gameOver('lives')
    } else {
      this.saveRun()
      setTimeout(() => this.redraw(), 300)
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
    const overlay = document.getElementById('km-help-overlay')
    const close = document.getElementById('km-help-close')
    // Both the HUD button and the shop header button open the same overlay.
    ;['km-help-btn', 'km-help-btn-shop'].forEach((id) => {
      const btn = document.getElementById(id)
      if (btn && overlay) btn.addEventListener('click', () => overlay.classList.remove('hidden'))
    })
    if (close && overlay) close.addEventListener('click', () => overlay.classList.add('hidden'))
  },

  // -- upgrade status panel ---------------------------------------------------

  bindStatus() {
    const overlay = document.getElementById('km-status-overlay')
    const close = document.getElementById('km-status-close')
    const open = () => {
      this.renderStatus()
      overlay.classList.remove('hidden')
    }
    // Both the HUD button and the shop header button open the same overlay.
    ;['km-status-btn', 'km-status-btn-shop'].forEach((id) => {
      const btn = document.getElementById(id)
      if (btn && overlay) btn.addEventListener('click', open)
    })
    if (close && overlay) close.addEventListener('click', () => overlay.classList.add('hidden'))
  },

  renderStatus() {
    const list = document.getElementById('km-status-strokes')
    const currencies = document.getElementById('km-status-currencies')
    const { current } = this.state
    if (!list) return

    // Show at least the current kanji's strokes, and never hide strokes that
    // already carry an upgrade — during the shop the "current" kanji is the
    // completed one, which may have fewer strokes than an upgraded index.
    const upgradedMax = Object.keys(this.state.upgrades).reduce(
      (m, k) => Math.max(m, parseInt(k, 10) || 0),
      0
    )
    const strokeCount = current
      ? Math.max(current.kanji.stroke_count || current.validCount, upgradedMax)
      : upgradedMax
    const rows = []
    for (let n = 1; n <= strokeCount; n++) {
      const colorName = this.state.upgrades[n]
      const color = colorName ? UPGRADE_COLORS[colorName] : '#9ca3af'
      const label = colorName ? this.upgradeNames[colorName] || colorName : this.statusNoneLabel
      rows.push(`
        <li class="flex items-center gap-2">
          <span class="inline-block w-4 h-4 rounded-full shrink-0" style="background: ${color}"></span>
          <span class="text-base-content/70">${this.statusStrokeLabel.replace('%{n}', String(n))}</span>
          <span class="ml-auto font-medium" style="color: ${colorName ? color : 'inherit'}">${label}</span>
        </li>`)
    }
    list.innerHTML = rows.join('')

    if (currencies) {
      this.setCount('km-status-lives', this.state.lives)
      this.setCount('km-status-coins', this.state.coins)
      this.setCount('km-status-hints', this.state.hints)
    }
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
      levelIndex: this.state.levelIndex,
      levelQueue: this.state.levelQueue,
      levelsBuilt: [...this.state.levelsBuilt],
      bossActive: this.state.bossActive,
      mistakes: this.state.mistakes,
      usedCharacters: [...this.state.usedCharacters],
      skippedCharacters: [...this.state.skippedCharacters],
      upgrades: this.state.upgrades,
      pack: this.state.pack,
      packCost: this.state.packCost,
      packBought: this.state.packBought,
      rerollCost: this.state.rerollCost,
      shopOpen: this.state.shopOpen,
      shopBuys: this.state.shopBuys,
      currentCharacter: current ? current.kanji.character : null,
      strokeIndex: current ? current.strokeIndex : 0,
      currentBoss: current ? !!current.boss : false,
      debuffs: current ? current.debuffs || null : null
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
      // The current kanji is normally from the learned pool, but a boss
      // kanji comes from the whole-dictionary boss pool instead.
      const kanji =
        this.pool.find((k) => k.character === s.currentCharacter) ||
        (s.bossActive ? this.bossPool.find((k) => k.character === s.currentCharacter) : undefined)
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
      this.state.levelIndex = typeof s.levelIndex === 'number' ? s.levelIndex : 0
      // Queue entries are {kanji, boss}; snapshots from before level bosses
      // hold plain kanji objects — normalize them.
      this.state.levelQueue = Array.isArray(s.levelQueue)
        ? s.levelQueue.map((e) => (e && e.kanji ? e : { kanji: e, boss: false }))
        : []
      // Levels at or before the current one are done for this pass. Older
      // snapshots without the field get the same conservative reconstruction.
      this.state.levelsBuilt = new Set(
        Array.isArray(s.levelsBuilt)
          ? s.levelsBuilt
          : Array.from({ length: this.state.levelIndex + 1 }, (_unused, i) => i)
      )
      this.state.bossActive = !!s.bossActive
      this.state.mistakes = typeof s.mistakes === 'number' ? s.mistakes : 0
      this.state.usedCharacters = new Set(s.usedCharacters || [])
      this.state.skippedCharacters = new Set(s.skippedCharacters || [])
      this.state.upgrades = s.upgrades || {}
      this.state.pack = Array.isArray(s.pack) ? s.pack : null
      this.state.packCost = typeof s.packCost === 'number' ? s.packCost : 4 + Math.floor(Math.random() * 3)
      this.state.packBought = !!s.packBought
      this.state.rerollCost = typeof s.rerollCost === 'number' ? s.rerollCost : 1
      this.state.shopOpen = !!s.shopOpen
      this.state.shopBuys = s.shopBuys || { pack: 0, life: 0, hint: 0, skip: 0 }

      const strokes = (kanji.stroke_data.strokes || []).filter((st) => st.path)
      const analyzed = strokes.map((st, i) => {
        const pts = parsePath(st.path)
        const a = analyzeStroke(pts)
        return a ? { ...a, index: i, originalPath: st.path, ...classifyStrokePath(st.path) } : null
      })
      this.state.current = {
        kanji,
        analyzed,
        validCount: analyzed.filter((a) => a !== null).length,
        strokeIndex: Math.min(s.strokeIndex || 0, analyzed.length),
        level: this.state.bossActive ? 'boss' : Math.min(this.state.levelIndex, LEVELS.length - 1),
        boss: !!s.currentBoss,
        debuffs: s.debuffs || null
      }
      this.applyLevelBackground()

      // If the snapshot was taken while the shop was open (or during the
      // short transition), the saved kanji is already complete — advance
      // to the next one instead of restoring a stuck state, then re-open
      // the shop with the saved pack / re-roll cost.
      if (this.state.current.strokeIndex >= this.state.current.validCount) {
        this.nextKanji()
        if (!this.state.over && this.state.shopOpen) this.openShop(false)
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
      skip: 5
    }
  },

  openShop(fresh = true) {
    if (this.state.over) return
    const overlay = document.getElementById('km-shop-overlay')
    if (!overlay) return this.nextKanji()
    this.state.shopOpen = true
    // A fresh store visit starts with no pack, a fresh random pack price,
    // a 1-coin re-roll and zeroed purchase counts; a restored visit keeps
    // its saved state.
    if (fresh) {
      this.state.shopBuys = { pack: 0, life: 0, hint: 0, skip: 0 }
      // Drop an unpaid leftover pack from an earlier shop so offers are
      // always generated for the level the player is in now.
      if (!this.state.packBought) this.state.pack = null
    }
    if (!this.state.pack && !this.state.packBought) {
      this.state.packCost = 4 + Math.floor(Math.random() * 3)
      this.state.rerollCost = 1
    }
    this.shopBound = this.shopBound || this.bindShop()
    this.refreshShop()
    this.renderPack()
    overlay.classList.remove('hidden')
    this.saveRun()
  },

  closeShop() {
    const overlay = document.getElementById('km-shop-overlay')
    if (overlay) overlay.classList.add('hidden')
    this.state.shopOpen = false
    if (this.state.over) return
    // The pre-first-kanji shop closes onto the already-loaded first kanji;
    // every later shop follows a completed kanji, so advance.
    if (this.state.completedKanji > 0) this.nextKanji()
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
    bind('km-sell-hints', () => this.sellHints())
    bind('km-buy-skip', () => this.buyItem('skip', 'km-buy-skip'))
    bind('km-buy-pack', () => this.buyPack())
    bind('km-pack-reroll', () => this.rerollPack())
    return true
  },

  refreshShop() {
    const prices = this.shopPrices_cached || (this.shopPrices_cached = this.shopPrices())
    this.currentPrices = prices
    document.getElementById('km-shop-coins').textContent = String(this.state.coins)

    const soldOutLabel = (document.getElementById('km-shop') || {}).dataset
      ? document.getElementById('km-shop').dataset.soldOutLabel || 'Sold out'
      : 'Sold out'

    const configure = (id, price, kind) => {
      const btn = document.getElementById(id)
      if (!btn) return
      const priceEl = btn.querySelector('.km-price')
      const limit = this.state.shopLimits[kind]
      const reached = limit != null && this.state.shopBuys[kind] >= limit
      if (reached) {
        priceEl.textContent = soldOutLabel
        priceEl.classList.add('text-error')
      } else {
        priceEl.textContent = `${price} 🪙`
        priceEl.classList.remove('text-error')
      }
      if (reached || this.state.coins < price) {
        btn.setAttribute('disabled', '')
        btn.classList.add('btn-disabled')
        btn.classList.remove('btn-primary')
      } else {
        btn.removeAttribute('disabled')
        btn.classList.remove('btn-disabled')
        btn.classList.add('btn-primary')
      }
    }

    configure('km-buy-life', prices.life, 'life')
    configure('km-buy-hint', prices.hint, 'hint')
    configure('km-buy-skip', prices.skip, 'skip')
    configure('km-buy-pack', this.state.packCost, 'pack')

    // Selling yellow strokes back: needs 4 charges in hand. The price label
    // is static ("+1 🪙") so only the disabled state is refreshed here.
    const sell = document.getElementById('km-sell-hints')
    if (sell) {
      if (this.state.hints < 4) {
        sell.setAttribute('disabled', '')
        sell.classList.add('btn-disabled')
        sell.classList.remove('btn-primary')
      } else {
        sell.removeAttribute('disabled')
        sell.classList.remove('btn-disabled')
        sell.classList.add('btn-primary')
      }
    }

    // Re-roll button state: cost shown in red when unaffordable. Only
    // available after the pack was bought (re-roll replaces the pack price).
    const reroll = document.getElementById('km-pack-reroll')
    if (reroll) {
      const cost = this.state.rerollCost
      const costEl = document.getElementById('km-reroll-cost')
      if (costEl) {
        costEl.textContent = `${cost} 🪙`
        costEl.classList.toggle('text-error', this.state.coins < cost)
        costEl.classList.toggle('text-warning', this.state.coins >= cost)
      }
      if (!this.state.packBought || this.state.coins < cost) {
        reroll.setAttribute('disabled', '')
        reroll.classList.add('btn-disabled')
        reroll.classList.remove('btn-primary')
      } else {
        reroll.removeAttribute('disabled')
        reroll.classList.remove('btn-disabled')
        reroll.classList.add('btn-primary')
      }
    }
  },

  buyItem(kind, btnId) {
    if (this.state.shopBuys[kind] >= this.state.shopLimits[kind]) return
    const price = this.currentPrices[kind]
    if (this.state.coins < price) return
    this.state.coins -= price
    this.state.shopBuys[kind] += 1
    this.updateHud()

    if (kind === 'life') {
      this.state.lives += 1
      this.updateHud()
    }
    if (kind === 'hint') {
      this.state.hints += 1
      this.updateHud()
    }
    if (kind === 'skip') this.showSkipPicker()

    this.refreshShop()
    this.saveRun()
  },

  sellHints() {
    if (this.state.hints < 4) return
    this.state.hints -= 4
    this.state.coins += 1
    this.updateHud()
    this.animate('km-coins', 'km-anim-bump')
    this.refreshShop()
    this.saveRun()
  },

  // -- upgrade packs ----------------------------------------------------------

  // Builds a fresh pack of 3 offers. Offers only target strokes of the
  // current level and the levels below it (the shop after a level boss uses
  // the NEXT level's cap). Already-upgraded strokes are excluded — but when
  // fewer than 3 unowned strokes remain, packs offer re-colors of already
  // upgraded strokes instead so there are always 3 choices (when possible).
  generatePack() {
    const owned = this.state.upgrades
    const levelCap = this.effectiveLevelCap()
    const maxIndex = Math.min(
      MAX_UPGRADE_INDEX,
      levelCap,
      Math.max(...this.pool.map((k) => k.stroke_count || 1))
    )
    const available = []
    for (let idx = 1; idx <= maxIndex; idx++) {
      if (!owned[idx]) available.push(idx)
    }

    const colors = Object.keys(UPGRADE_COLORS)

    // Every unowned stroke gets exactly one offer first (shuffled), so all
    // of them are always available before any re-color of an upgraded one.
    const shuffled = [...available]
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]]
    }
    const offers = shuffled
      .slice(0, 3)
      .map((index) => ({
        index,
        color: colors[Math.floor(Math.random() * colors.length)]
      }))

    // Fallback: re-color offers for already-upgraded strokes fill the
    // remaining slots (each offer a different stroke, and never the color it
    // already has).
    const ownedIndices = Object.keys(owned)
      .map(Number)
      .filter((i) => i >= 1 && i <= maxIndex)
    let guard = 0
    while (offers.length < 3 && ownedIndices.length > 0 && guard++ < 400) {
      const index = ownedIndices[Math.floor(Math.random() * ownedIndices.length)]
      const color = colors[Math.floor(Math.random() * colors.length)]
      if (owned[index] === color) continue
      if (offers.some((o) => o.index === index)) continue
      offers.push({ index, color })
    }
    return offers
  },

  // The stroke-count cap for packs. While drawing a level it is that level's
  // max; when the shop opens right after a level boss (queue drained), packs
  // target the level the player enters next. A finished pass restarts at
  // level 1.
  effectiveLevelCap() {
    if (this.state.levelQueue.length > 0 || this.state.bossActive) {
      return LEVELS[Math.min(this.state.levelIndex, LEVELS.length - 1)].max
    }
    if (this.state.levelIndex >= LEVELS.length - 1) return LEVELS[0].max

    const { usedCharacters, skippedCharacters } = this.state
    for (let idx = this.state.levelIndex + 1; idx < LEVELS.length; idx++) {
      const { min, max } = LEVELS[idx]
      const has = this.pool.some((k) => {
        const c = k.stroke_count || 0
        return (
          c >= min &&
          c <= max &&
          !skippedCharacters.has(k.character) &&
          !usedCharacters.has(k.character)
        )
      })
      if (has) return LEVELS[idx].max
    }
    return LEVELS[0].max
  },

  // Pay the pack price (random 4-6 per pack) to reveal the offers.
  buyPack() {
    if (this.state.packBought) return
    if (this.state.shopBuys.pack >= this.state.shopLimits.pack) return
    const cost = this.state.packCost
    if (this.state.coins < cost) return
    this.state.coins -= cost
    this.state.shopBuys.pack += 1
    this.state.pack = this.generatePack()
    this.state.packBought = true
    this.updateHud()
    this.renderPack()
    this.refreshShop()
    this.saveRun()
  },

  // After the pack is bought, a re-roll replaces the pack price: it costs
  // 1 coin, then 2, then 3... within the same store visit.
  rerollPack() {
    if (!this.state.packBought) return
    const cost = this.state.rerollCost
    if (this.state.coins < cost) return
    this.state.coins -= cost
    this.state.rerollCost += 1
    this.state.pack = this.generatePack()
    this.updateHud()
    this.renderPack()
    this.refreshShop()
    this.saveRun()
  },

  renderPack() {
    const box = document.getElementById('km-pack-offers')
    const area = document.getElementById('km-pack-area')
    if (!box) return
    const offers = this.state.packBought ? this.state.pack || [] : []
    if (area) area.classList.toggle('hidden', offers.length === 0)
    if (offers.length === 0) {
      box.innerHTML = ''
      return
    }
    box.innerHTML = offers
      .map(
        (o, i) => `
        <button data-pick="${i}" class="btn btn-sm w-full btn-outline"
          style="border-color: ${UPGRADE_COLORS[o.color]}; color: ${UPGRADE_COLORS[o.color]}">
          ${o.index} → ${this.upgradeNames[o.color] || o.color}
        </button>`
      )
      .join('')

    box.querySelectorAll('[data-pick]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const offer = offers[parseInt(btn.dataset.pick, 10)]
        if (!offer) return
        this.state.upgrades[offer.index] = offer.color
        this.state.pack = null
        this.state.packBought = false
        this.state.packCost = 4 + Math.floor(Math.random() * 3) // price for the next pack
        box.innerHTML = ''
        this.renderPack()
        this.refreshShop()
        // Keep the status panel in sync when it is open (it renders above the
        // shop, so a purchase can happen while it is visible).
        const statusOverlay = document.getElementById('km-status-overlay')
        if (statusOverlay && !statusOverlay.classList.contains('hidden')) this.renderStatus()
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

  // -- give up ----------------------------------------------------------------

  bindGiveUp() {
    const btn = document.getElementById('km-give-up-btn')
    if (!btn) return
    btn.addEventListener('click', () => {
      if (this.state.over) return
      const message =
        btn.dataset.giveUpConfirm || 'Are you sure you want to give up? Your run will end.'
      if (window.confirm(message)) this.gameOver('gave_up')
    })
  },

  // -- game over (panel wired in Task 6) ------------------------------------

  gameOver(reason) {
    this.state.over = true
    this.clearRun()
    // Send the kanji that ended the run so the game-over panel can link to
    // its page for practice.
    const failed = this.state.current ? this.state.current.kanji.character : null
    this.pushEvent('game_over', { score: this.state.score, reason, failed_kanji: failed })
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
