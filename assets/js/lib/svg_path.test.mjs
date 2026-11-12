// Cross-checks for assets/js/lib/svg_path.js against an independently
// written reference parser. Run: node --test assets/js/lib/
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { pathSegments, pathEndpoints } from './svg_path.js'

// Independent reference implementation (deliberately written differently:
// regex token pairs instead of chunking).
function referenceEndpoints(pathStr) {
  const tokens = pathStr.match(/[a-zA-Z]|-?\d*\.?\d+(?:e[-+]?\d+)?/g) || []
  const pts = []
  let x = 0, y = 0, i = 0
  const num = () => parseFloat(tokens[i++])
  while (i < tokens.length) {
    let cmd = tokens[i++]
    if (!/[a-zA-Z]/.test(cmd)) continue
    const rel = cmd === cmd.toLowerCase()
    const t = cmd.toUpperCase()
    const read = (arity, apply) => {
      while (i + arity <= tokens.length && !/[a-zA-Z]/.test(tokens[i])) {
        apply()
        if (t === 'Z') break
        if (t === 'M') cmd = rel ? 'l' : 'L' // implicit lineto after moveto
      }
    }
    switch (t) {
      case 'M': case 'L': read(2, () => { const a = num(), b = num(); x = rel ? x + a : a; y = rel ? y + b : b; pts.push([x, y]) }); break
      case 'H': read(1, () => { const a = num(); x = rel ? x + a : a; pts.push([x, y]) }); break
      case 'V': read(1, () => { const a = num(); y = rel ? y + a : a; pts.push([x, y]) }); break
      case 'C': read(6, () => { num(); num(); num(); num(); const a = num(), b = num(); x = rel ? x + a : a; y = rel ? y + b : b; pts.push([x, y]) }); break
      case 'S': case 'Q': read(4, () => { num(); num(); const a = num(), b = num(); x = rel ? x + a : a; y = rel ? y + b : b; pts.push([x, y]) }); break
      case 'T': read(2, () => { const a = num(), b = num(); x = rel ? x + a : a; y = rel ? y + b : b; pts.push([x, y]) }); break
      case 'A': read(7, () => { num(); num(); num(); num(); num(); const a = num(), b = num(); x = rel ? x + a : a; y = rel ? y + b : b; pts.push([x, y]) }); break
      case 'Z': break
      default: i++
    }
  }
  return pts
}

// The 11 strokes of 掛 (U+639B) from raw/kanjivg/kanji/0639b.svg.
// Stroke 3 starts with a relative "m" followed by TWO implicit cubic
// segments — the case that was dropped by the old parser.
const KAKE_PATHS = [
  "M14.5,39.67c2.11,0.25,3.73,0.23,5.89-0.09c4.2-0.64,9.03-1.47,15.38-2.42c0.93-0.14,1.89-0.27,2.9-0.4",
  "M28.27,16.25c0.93,0.93,1.51,2.88,1.51,5.02c0,15.23-0.01,52.21-0.01,63.65c0,14.25-6.07,3.53-7.52,2.02",
  "m13.5,67.39c1.62,0.99,2.5,0.99,4.12,-0.51,4.43,-4.09,7.63,-7,18.45,-17.66",
  "M43.96,34.22c1.01,0.5,2.66,0.28,3.67,0.16c7.24-0.88,11.99-1.63,16.38-2.22c1.28-0.17,2.54-0.24,3.78,0.13",
  "M53.32,38.37c0.84,0.84,1.46,2.27,1.46,4.04c0,10.88-0.01,38.41-0.01,49.46c0,2.96-0.17,4.95-0.42,6.71",
  "M41.4,58.44c1.11,0.33,2.57,0.24,3.71,0.1c6.53-0.8,14.23-1.94,21.79-2.72c1.55-0.16,3.28-0.44,4.82-0.2",
  "M85.79,18.36c0.23,0.77,0.31,1.81,0.17,2.75c-1.02,6.96-2.23,13.53-4.71,19.61",
  "M71.15,43.75c1.38,0.08,2.58,0.05,4-0.09c6.55-0.64,14.55-1.91,20.96-2.56c1.31-0.13,2.95-0.34,4.26-0.1",
  "M88.66,44.83c0.84,0.84,1.31,2.27,1.31,4.04c0,11.45-0.01,29.97-0.01,36.98c0,8.62-5.71,2.11-7.42,0.63",
  "M72.88,58.62c2.88,3.02,7.23,10.13,7.98,14.06",
  "M92.75,55.25c2.96,3.14,7.42,10.55,8.18,14.64",
]

test('掛 stroke 3 parses to its true end point (regression)', () => {
  const pts = pathEndpoints(KAKE_PATHS[2])
  assert.deepEqual(pts[0], { x: 13.5, y: 67.39 })
  const last = pts[pts.length - 1]
  assert.ok(Math.abs(last.x - 36.07) < 0.01, `x: ${last.x}`)
  assert.ok(Math.abs(last.y - 49.22) < 0.01, `y: ${last.y}`)
  assert.equal(pts.length, 3) // m + two implicit c segments
})

test('all 掛 strokes match the independent reference parser', () => {
  for (const path of KAKE_PATHS) {
    const got = pathEndpoints(path).map(p => [p.x, p.y])
    const want = referenceEndpoints(path)
    assert.deepEqual(got, want, `path: ${path.slice(0, 40)}`)
  }
})

test('implicit lineto groups after moveto', () => {
  const pts = pathEndpoints('M10,10 20,20 30,10')
  assert.deepEqual(pts, [{ x: 10, y: 10 }, { x: 20, y: 20 }, { x: 30, y: 10 }])
})

test('relative moveto then implicit relative lineto', () => {
  const pts = pathEndpoints('m10,10 5,5')
  assert.deepEqual(pts, [{ x: 10, y: 10 }, { x: 15, y: 15 }])
})

test('relative m mid-path offsets from current pen position', () => {
  const pts = pathEndpoints('M50,50 m10,10')
  assert.deepEqual(pts, [{ x: 50, y: 50 }, { x: 60, y: 60 }])
})

test('repeated H/V commands', () => {
  const pts = pathEndpoints('M0,0 H10 V20 h5 v5')
  assert.deepEqual(pts, [
    { x: 0, y: 0 },
    { x: 10, y: 0 },
    { x: 10, y: 20 },
    { x: 15, y: 20 },
    { x: 15, y: 25 },
  ])
})

test('segment count and shapes are normalized', () => {
  const segs = pathSegments('m13.5,67.39c1,1,2,2,3,3,4,4,5,5,6,6')
  assert.deepEqual(segs.map(s => s.type), ['M', 'C', 'C'])
  assert.deepEqual(segs.map(s => s.rel), [true, true, true])
  assert.equal(segs[1].nums.length, 6)
})
