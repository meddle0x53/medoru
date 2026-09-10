// Input-latency probe for touch keyboards in The Hollow Ouroboros.
// Per tap logs:
//   - lag: native pointer event timeStamp -> Phaser handler (was ~100ms+)
//   - raw: raw DOM pointerdown on canvas -> Phaser handler (isolates
//          Phaser/main-thread delay from Chrome input-timestamp quirks)
//   - frame: current per-frame time (EMA) — if ~lag, the game loop itself
//            is running slow in that scene
// Raw taps accumulate on window.__rawTapT; stats on window.__keyLag.

let frameEma = 16.7

export function trackFrame(delta) {
  if (typeof delta === 'number' && delta > 0 && delta < 5000) {
    frameEma = frameEma * 0.9 + delta * 0.1
  }
}

function ensureRawTapTracker() {
  if (window.__rawTapTracker) return
  window.__rawTapTracker = true
  document.addEventListener('pointerdown', (e) => {
    window.__rawTapT = performance.now()
  }, { capture: true, passive: true })
}

export function probeKeyLag(pointer) {
  ensureRawTapTracker()

  const nativeTs = pointer && pointer.event && typeof pointer.event.timeStamp === 'number'
    ? pointer.event.timeStamp
    : null
  const now = performance.now()
  const rawDelta = typeof window.__rawTapT === 'number' ? now - window.__rawTapT : null

  const lag = nativeTs != null ? now - nativeTs : null
  const stats = (window.__keyLag = window.__keyLag || { n: 0, sum: 0, max: 0, rawSum: 0, rawMax: 0 })
  stats.n += 1
  if (lag != null) {
    stats.sum += lag
    stats.max = Math.max(stats.max, lag)
  }
  if (rawDelta != null) {
    stats.rawSum += rawDelta
    stats.rawMax = Math.max(stats.rawMax, rawDelta)
  }

  console.log('[GamePerf] key lag ms:', lag != null ? Math.round(lag) : 'n/a',
    '| raw->handler:', rawDelta != null ? Math.round(rawDelta) : 'n/a',
    '| frame ema:', Math.round(frameEma),
    '| avg lag:', stats.n ? Math.round(stats.sum / stats.n) : 'n/a',
    '| max lag:', Math.round(stats.max),
    '| avg raw:', stats.n ? Math.round(stats.rawSum / stats.n) : 'n/a')
}
