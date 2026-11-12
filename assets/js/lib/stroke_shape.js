// Shared ideal-stroke shape analysis, extracted from kanji_master.js.
// All shape classes are derived from the KanjiVG geometry: every ideal stroke
// of a kanji is classified purely from its authored path, independent of the
// player's drawing.
//
// Classes in plain words:
//   dot        — very short stroke with low directionality (点)
//   horizontal — straight left-to-right stroke (横)
//   vertical   — straight top-to-bottom stroke (竖)
//   diagDownLeft  — straight left-falling stroke (撇)
//   diagDownRight — straight right-falling stroke
//   diagUpRight / diagUpLeft — straight rising diagonals
//   rise       — rising flick, chord clearly going up (提)
//   press      — right-falling stroke with a press bend (捺)
//   hook       — main run with the deviation concentrated at the very end (钩)
//   corner     — two roughly straight legs joined at a mid corner (折);
//                rounded corners (digitized without a sharp vertex) included
//   curveHook  — smooth curve finishing in an up-flick (卧钩 / 竖弯钩)
//   curve      — remaining smooth curves (弯)
// Sub-labels are kept in `shapeDetail` as compact direction codes:
//   H horizontal, V vertical, DR/DL down-right/down-left, UR/UL up-right/
//   up-left (SVG y axis points down). Hooks carry the incoming direction,
//   corners the two leg directions ("H_V"), prefixed "r:" when rounded.

import { pathSegments } from './svg_path.js'

export const STROKE_SHAPES = {
  dot: 'dot',
  horizontal: 'horizontal',
  vertical: 'vertical',
  diagDownLeft: 'diagDownLeft',
  diagDownRight: 'diagDownRight',
  diagUpRight: 'diagUpRight',
  diagUpLeft: 'diagUpLeft',
  rise: 'rise',
  press: 'press',
  hook: 'hook',
  corner: 'corner',
  curveHook: 'curveHook',
  curve: 'curve'
}

const SHAPE_DIR_CODES = { H: 'horizontal', V: 'vertical', DR: 'diagDownRight', DL: 'diagDownLeft', UR: 'diagUpRight', UL: 'diagUpLeft' }

const SAMPLE_STEP = 2.0

function sampleCubic(p0, c1, c2, p3, step) {
  const coarse = []
  const n = 24
  for (let i = 0; i <= n; i++) {
    const t = i / n
    const mt = 1 - t
    coarse.push({
      x: mt * mt * mt * p0.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * p3.x,
      y: mt * mt * mt * p0.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * p3.y
    })
  }
  return resampleByArcLength(coarse, step)
}

function sampleQuadratic(p0, c1, p2, step) {
  return sampleCubic(
    p0,
    { x: p0.x + (2 / 3) * (c1.x - p0.x), y: p0.y + (2 / 3) * (c1.y - p0.y) },
    { x: p2.x + (2 / 3) * (c1.x - p2.x), y: p2.y + (2 / 3) * (c1.y - p2.y) },
    p2,
    step
  )
}

function resampleByArcLength(coarse, step) {
  const cum = [0]
  for (let i = 1; i < coarse.length; i++) {
    const dx = coarse[i].x - coarse[i - 1].x
    const dy = coarse[i].y - coarse[i - 1].y
    cum.push(cum[i - 1] + Math.sqrt(dx * dx + dy * dy))
  }
  const total = cum[cum.length - 1]
  if (total < 1e-9) return [coarse[coarse.length - 1]]
  const nOut = Math.max(2, Math.floor(total / step) + 1)
  const pts = []
  let j = 0
  for (let k = 0; k < nOut; k++) {
    const target = (total * k) / (nOut - 1)
    while (j < cum.length - 2 && cum[j + 1] < target) j++
    const seg = cum[j + 1] - cum[j]
    const f = seg < 1e-12 ? 0 : (target - cum[j]) / seg
    pts.push({
      x: coarse[j].x + (coarse[j + 1].x - coarse[j].x) * f,
      y: coarse[j].y + (coarse[j + 1].y - coarse[j].y) * f
    })
  }
  return pts
}

// Dense polyline sampling over the shared tokenizer (~2-unit arc-length
// steps): the classifier thresholds were derived from sampled polylines
// (arc length, deviation, turning all depend on density).
export function parseStrokePoints(pathStr) {
  const points = []
  let currentX = 0
  let currentY = 0
  let pendingMove = null

  const push = (p) => {
    if (pendingMove) {
      points.push(pendingMove)
      pendingMove = null
    }
    points.push(p)
  }

  const extendCurve = (seg) => {
    if (pendingMove) {
      points.push(pendingMove)
      pendingMove = null
      points.push(...seg)
    } else {
      points.push(...seg.slice(1))
    }
  }

  const abs = (n, i) => (n.rel ? n.nums[i] + currentX : n.nums[i])
  const absY = (n, i) => (n.rel ? n.nums[i] + currentY : n.nums[i])

  for (const seg of pathSegments(pathStr)) {
    const n = seg.nums
    switch (seg.type) {
      case 'M':
        currentX = abs(seg, 0)
        currentY = absY(seg, 1)
        pendingMove = { x: currentX, y: currentY }
        break
      case 'L':
        currentX = abs(seg, 0)
        currentY = absY(seg, 1)
        push({ x: currentX, y: currentY })
        break
      case 'H':
        currentX = abs(seg, 0)
        push({ x: currentX, y: currentY })
        break
      case 'V':
        currentY = absY(seg, 0)
        push({ x: currentX, y: currentY })
        break
      case 'C': {
        const c1 = { x: abs(seg, 0), y: absY(seg, 1) }
        const c2 = { x: abs(seg, 2), y: absY(seg, 3) }
        const p = { x: abs(seg, 4), y: absY(seg, 5) }
        const from = { x: currentX, y: currentY }
        extendCurve(sampleCubic(from, c1, c2, p, SAMPLE_STEP))
        currentX = p.x
        currentY = p.y
        break
      }
      case 'S': {
        const c2 = { x: abs(seg, 0), y: absY(seg, 1) }
        const p = { x: abs(seg, 2), y: absY(seg, 3) }
        const from = { x: currentX, y: currentY }
        extendCurve(sampleCubic(from, from, c2, p, SAMPLE_STEP))
        currentX = p.x
        currentY = p.y
        break
      }
      case 'Q': {
        const c = { x: abs(seg, 0), y: absY(seg, 1) }
        const p = { x: abs(seg, 2), y: absY(seg, 3) }
        const from = { x: currentX, y: currentY }
        extendCurve(sampleQuadratic(from, c, p, SAMPLE_STEP))
        currentX = p.x
        currentY = p.y
        break
      }
      case 'T': {
        const p = { x: abs(seg, 0), y: absY(seg, 1) }
        const from = { x: currentX, y: currentY }
        extendCurve(sampleQuadratic(from, from, p, SAMPLE_STEP))
        currentX = p.x
        currentY = p.y
        break
      }
      case 'A': {
        currentX = abs(seg, n.length - 2)
        currentY = absY(seg, n.length - 1)
        push({ x: currentX, y: currentY })
        break
      }
      case 'Z':
        break
    }
  }

  return points
}

// Direction code from a vector. SVG y axis points down, so dy > 0 means the
// stroke is heading downward on screen.
export function shapeDirCode(dx, dy) {
  const absDx = Math.abs(dx)
  const absDy = Math.abs(dy)
  if (absDx < 1e-9) return 'V'
  const r = absDy / absDx
  if (r < 0.3) return 'H'
  if (r > 3) return 'V'
  return (dy > 0 ? 'D' : 'U') + (dx > 0 ? 'R' : 'L')
}

export function shapeDirFromDeg(deg) {
  const rad = (deg * Math.PI) / 180
  return shapeDirCode(Math.cos(rad), Math.sin(rad))
}

export function angleDiff(a, b) {
  const d = Math.abs(a - b) % 360
  return Math.min(d, 360 - d)
}

export function computeStrokeFeatures(points) {
  const pts = []
  for (const p of points) {
    const last = pts[pts.length - 1]
    if (!last || Math.hypot(p.x - last.x, p.y - last.y) > 1e-6) pts.push(p)
  }
  if (pts.length < 2) return null
  const n = pts.length
  const segLens = [0]
  for (let i = 1; i < n; i++) segLens.push(Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y))
  const cum = [0]
  for (let i = 1; i < n; i++) cum.push(cum[i - 1] + segLens[i])
  const L = cum[n - 1]
  const sx = pts[0].x
  const sy = pts[0].y
  const ex = pts[n - 1].x
  const ey = pts[n - 1].y
  const dx = ex - sx
  const dy = ey - sy
  const C = Math.hypot(dx, dy)
  const ratio = C > 1e-9 ? L / C : Infinity

  let maxDev = 0
  let tDev = 0
  if (C >= 1e-9) {
    const nx = dx / C
    const ny = dy / C
    for (const p of pts) {
      const px = p.x - sx
      const py = p.y - sy
      const perp = Math.abs(px * ny - py * nx)
      const t = (px * nx + py * ny) / C
      if (perp > maxDev) {
        maxDev = perp
        tDev = t
      }
    }
  }

  let turn = 0
  for (let i = 1; i < n - 1; i++) {
    const ax = pts[i].x - pts[i - 1].x
    const ay = pts[i].y - pts[i - 1].y
    const bx = pts[i + 1].x - pts[i].x
    const by = pts[i + 1].y - pts[i].y
    const la = Math.hypot(ax, ay)
    const lb = Math.hypot(bx, by)
    if (la < 1e-9 || lb < 1e-9) continue
    const cosv = Math.max(-1, Math.min(1, (ax * bx + ay * by) / (la * lb)))
    turn += Math.acos(cosv)
  }
  const turnDeg = (turn * 180) / Math.PI

  const corners = []
  for (let i = 1; i < n - 1; i++) {
    const ax = pts[i - 1].x - pts[i].x
    const ay = pts[i - 1].y - pts[i].y
    const bx = pts[i + 1].x - pts[i].x
    const by = pts[i + 1].y - pts[i].y
    const la = Math.hypot(ax, ay)
    const lb = Math.hypot(bx, by)
    if (la < 2.0 || lb < 2.0) continue
    const cosv = Math.max(-1, Math.min(1, (ax * bx + ay * by) / (la * lb)))
    const ang = (Math.acos(cosv) * 180) / Math.PI
    if (ang < 130) corners.push({ ang, t: L ? cum[i] / L : 0, i })
  }

  const ptAt = (frac) => {
    const target = L * frac
    for (let i = 0; i < n; i++) {
      if (cum[i] >= target) return pts[i]
    }
    return pts[n - 1]
  }
  const p25 = ptAt(0.25)
  const p75 = ptAt(0.75)
  const h0 = (Math.atan2(p25.y - sy, p25.x - sx) * 180) / Math.PI
  const h1 = (Math.atan2(ey - p75.y, ex - p75.x) * 180) / Math.PI
  const legRatio = (f0, f1) => {
    let i0 = 0
    while (i0 < n - 1 && cum[i0] < L * f0) i0++
    let i1 = i0
    while (i1 < n - 1 && cum[i1] < L * f1) i1++
    if (i1 <= i0) return 1
    const la = cum[i1] - cum[i0]
    const lc = Math.hypot(pts[i1].x - pts[i0].x, pts[i1].y - pts[i0].y)
    return lc > 1e-9 ? la / lc : 1
  }

  return {
    L, C, ratio, maxDev, tDev, turnDeg, corners, dx, dy,
    h0, h1, legRatio0: legRatio(0, 0.32), legRatio1: legRatio(0.68, 1), pts, cum
  }
}

// Decision tree ported verbatim from /tmp/analyze_strokes.py (thresholds and
// rule order unchanged). Returns { shape, shapeDetail? }.
export function classifyStroke(points) {
  const f = computeStrokeFeatures(points)
  if (!f) return { shape: STROKE_SHAPES.dot }
  const { L, C, ratio, maxDev, tDev, turnDeg, corners, dx, dy } = f
  const dirCode = shapeDirCode(dx, dy)

  // dot
  if (L < 12 || (L < 15 && C < 14 && maxDev < 5)) {
    return { shape: STROKE_SHAPES.dot }
  }

  // hook: deviation concentrated near the end
  if (tDev > 0.78 && maxDev > 3.5) {
    return { shape: STROKE_SHAPES.hook, shapeDetail: dirCode }
  }

  // corner: sharp corner around the middle
  const midCorners = corners.filter((c) => c.t > 0.12 && c.t < 0.88)
  if (midCorners.length > 0) {
    const c = midCorners.reduce((a, b) => (a.ang <= b.ang ? a : b))
    const cp = f.pts[c.i]
    const leg1 = shapeDirCode(cp.x - f.pts[0].x, cp.y - f.pts[0].y)
    const leg2 = shapeDirCode(dx - (cp.x - f.pts[0].x), dy - (cp.y - f.pts[0].y))
    return { shape: STROKE_SHAPES.corner, shapeDetail: `${leg1}_${leg2}` }
  }

  const legD = angleDiff(f.h0, f.h1)

  // corner (rounded): big leg-heading change, straight first leg, and the
  // max deviation happens before the corner region; second leg runs from
  // the 55%-arc point to the end (absorbs a trailing hook)
  if (corners.length === 0 && legD > 55 && f.legRatio0 < 1.12 && tDev < 0.55) {
    const mid = f.pts[f.cum.findIndex((c) => c >= 0.55 * f.L)]
    const end = f.pts[f.pts.length - 1]
    return {
      shape: STROKE_SHAPES.corner,
      shapeDetail: `r:${shapeDirFromDeg(f.h0)}_${shapeDirCode(end.x - mid.x, end.y - mid.y)}`
    }
  }

  // corner (rounded): both legs straight
  if (corners.length === 0 && legD > 55 && f.legRatio0 < 1.12 && f.legRatio1 < 1.12) {
    return {
      shape: STROKE_SHAPES.corner,
      shapeDetail: `r:${shapeDirFromDeg(f.h0)}_${shapeDirFromDeg(f.h1)}`
    }
  }

  // press (捺): right-falling chord with a clear press bend
  if (dirCode === 'DR' && ratio < 1.3 && turnDeg > 18 && maxDev > 2) {
    return { shape: STROKE_SHAPES.press }
  }

  // rise (提): clearly rising chord
  if (dy < -4 && (Math.abs(dx) < 0.3 * Math.abs(dy) || Math.abs(dy) > 0.15 * Math.abs(dx))) {
    return { shape: STROKE_SHAPES.rise, shapeDetail: dirCode }
  }

  // straight
  if (ratio < 1.15) {
    return { shape: STROKE_SHAPES[SHAPE_DIR_CODES[dirCode]] }
  }

  // smooth curve with an up-flick at the end (卧钩 / 竖弯钩)
  const chordDeg = C > 1e-9 ? (Math.atan2(dy, dx) * 180) / Math.PI : f.h0
  if (angleDiff(f.h1, chordDeg) > 60) {
    return { shape: STROKE_SHAPES.curveHook, shapeDetail: dirCode }
  }

  return { shape: STROKE_SHAPES.curve, shapeDetail: dirCode }
}

export function classifyStrokePath(pathStr) {
  return classifyStroke(parseStrokePoints(pathStr))
}

// Shape-adaptive end/center validation tolerances (extracted from
// kanji_master.js). Hooks (钩, 卧钩/弯钩) get a looser gate: the flick's tip
// is hard to place precisely, and the chord endpoint doesn't follow the
// hook's curve. Left-falling 撇 sweeps are a little forgiving too — the hand
// accelerates and drifts. Corners ending in a down-left sweep (横撇) get the
// same treatment as plain 撇 sweeps, and H_DL corners (a turn followed by a
// down-left sweep) get a tier above plain sweeps. Straight and other strokes
// keep the strict gates.
export function tolerancesForShape(shape, shapeDetail) {
  const isHook = shape === 'hook' || shape === 'curveHook'
  const isSweep =
    shape === 'diagDownLeft' ||
    shape === 'rise' ||
    (shape === 'corner' && (shapeDetail === 'DL_DR' || shapeDetail === 'r:DL_DR')) ||
    (shape === 'corner' && (shapeDetail === 'DR_UL' || shapeDetail === 'r:DR_UL'))
  const isHengPie = shape === 'corner' && (shapeDetail === 'H_DL' || shapeDetail === 'r:H_DL')
  return {
    end: isHook || isHengPie ? 27 : isSweep ? 24 : 18,
    center: isHook || isHengPie ? 30 : isSweep ? 28 : 25
  }
}
