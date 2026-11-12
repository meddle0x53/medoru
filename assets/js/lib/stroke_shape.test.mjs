// Tests for assets/js/lib/stroke_shape.js (shared stroke-shape classifier
// and adaptive tolerances). Run: node --test assets/js/lib/
import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  STROKE_SHAPES,
  parseStrokePoints,
  classifyStroke,
  classifyStrokePath,
  tolerancesForShape
} from './stroke_shape.js'

// The 11 strokes of 掛 (U+639B) from raw/kanjivg/kanji/0639b.svg (same list
// as svg_path.test.mjs).
const KAKE_PATHS = [
  'M14.5,39.67c2.11,0.25,3.73,0.23,5.89-0.09c4.2-0.64,9.03-1.47,15.38-2.42c0.93-0.14,1.89-0.27,2.9-0.4',
  'M28.27,16.25c0.93,0.93,1.51,2.88,1.51,5.02c0,15.23-0.01,52.21-0.01,63.65c0,14.25-6.07,3.53-7.52,2.02',
  'm13.5,67.39c1.62,0.99,2.5,0.99,4.12,-0.51,4.43,-4.09,7.63,-7,18.45,-17.66',
  'M43.96,34.22c1.01,0.5,2.66,0.28,3.67,0.16c7.24-0.88,11.99-1.63,16.38-2.22c1.28-0.17,2.54-0.24,3.78,0.13',
  'M53.32,38.37c0.84,0.84,1.46,2.27,1.46,4.04c0,10.88-0.01,38.41-0.01,49.46c0,2.96-0.17,4.95-0.42,6.71',
  'M41.4,58.44c1.11,0.33,2.57,0.24,3.71,0.1c6.53-0.8,14.23-1.94,21.79-2.72c1.55-0.16,3.28-0.44,4.82-0.2',
  'M85.79,18.36c0.23,0.77,0.31,1.81,0.17,2.75c-1.02,6.96-2.23,13.53-4.71,19.61',
  'M71.15,43.75c1.38,0.08,2.58,0.05,4-0.09c6.55-0.64,14.55-1.91,20.96-2.56c1.31-0.13,2.95-0.34,4.26-0.1',
  'M88.66,44.83c0.84,0.84,1.31,2.27,1.31,4.04c0,11.45-0.01,29.97-0.01,36.98c0,8.62-5.71,2.11-7.42,0.63',
  'M72.88,58.62c2.88,3.02,7.23,10.13,7.98,14.06',
  'M92.75,55.25c2.96,3.14,7.42,10.55,8.18,14.64',
]

const KAKE_SHAPES = KAKE_PATHS.map((p) => classifyStrokePath(p))

test('掛 stroke 1 classifies horizontal', () => {
  assert.equal(KAKE_SHAPES[0].shape, STROKE_SHAPES.horizontal)
})

test('掛 stroke 2 classifies as a vertical hook (V detail)', () => {
  assert.equal(KAKE_SHAPES[1].shape, STROKE_SHAPES.hook)
  assert.equal(KAKE_SHAPES[1].shapeDetail, 'V')
})

test('掛 stroke 3 classifies as a rising diagonal up-right', () => {
  assert.equal(KAKE_SHAPES[2].shape, STROKE_SHAPES.rise)
  assert.equal(KAKE_SHAPES[2].shapeDetail, 'UR')
})

test('hook-classified strokes exist among 掛 strokes 2-11', () => {
  const hooks = KAKE_SHAPES.slice(1).filter((s) => s.shape === STROKE_SHAPES.hook)
  assert.ok(hooks.length >= 2, `expected >= 2 hooks, got ${hooks.length}`)
})

test('掛 stroke 3 dense sampling reaches the true end point (regression)', () => {
  // The endpoint-only parser drops the two implicit cubic segments after the
  // relative moveto and ends the stroke at its start. Dense sampling must
  // carry it all the way to (36.07, 49.22).
  const pts = parseStrokePoints(KAKE_PATHS[2])
  assert.ok(pts.length > 10, `expected dense sampling, got ${pts.length} points`)
  assert.deepEqual(pts[0], { x: 13.5, y: 67.39 })
  const last = pts[pts.length - 1]
  assert.ok(Math.abs(last.x - 36.07) < 0.01, `x: ${last.x}`)
  assert.ok(Math.abs(last.y - 49.22) < 0.01, `y: ${last.y}`)
})

test('classifyStroke handles degenerate input as a dot', () => {
  assert.deepEqual(classifyStroke([{ x: 1, y: 1 }]), { shape: STROKE_SHAPES.dot })
  assert.deepEqual(classifyStroke([]), { shape: STROKE_SHAPES.dot })
})

test('tolerancesForShape: adaptive table', () => {
  assert.deepEqual(tolerancesForShape('hook', 'V'), { end: 27, center: 30 })
  assert.deepEqual(tolerancesForShape('curveHook', 'DR'), { end: 27, center: 30 })
  assert.deepEqual(tolerancesForShape('corner', 'H_DL'), { end: 27, center: 30 })
  assert.deepEqual(tolerancesForShape('corner', 'r:H_DL'), { end: 27, center: 30 })
  assert.deepEqual(tolerancesForShape('diagDownLeft', undefined), { end: 24, center: 28 })
  assert.deepEqual(tolerancesForShape('rise', 'UR'), { end: 24, center: 28 })
  assert.deepEqual(tolerancesForShape('corner', 'DL_DR'), { end: 24, center: 28 })
  assert.deepEqual(tolerancesForShape('corner', 'r:DR_UL'), { end: 24, center: 28 })
  assert.deepEqual(tolerancesForShape('horizontal', undefined), { end: 18, center: 25 })
  assert.deepEqual(tolerancesForShape('vertical', undefined), { end: 18, center: 25 })
  assert.deepEqual(tolerancesForShape('corner', 'H_V'), { end: 18, center: 25 })
})
