// SVG path tokenizer shared by the kanji writing hooks.
//
// KanjiVG paths occasionally use valid-but-less-common SVG syntax that the
// previous inline parsers mishandled:
//   - implicit command repetition: "c1,1,2,2,3,3 4,4,5,5,6,6" is TWO cubic
//     segments, not one cubic plus garbage (this broke e.g. 掛 stroke 3,
//     which starts with a relative "m" followed by two cubic segments)
//   - relative "m" coordinates (previously not offset, only correct when the
//     pen happened to be at the origin)
//
// pathSegments() expands a path into normalized segments: uppercase type,
// a `rel` flag, and a `nums` array of exactly ARITY[type] numbers, with
// implicit repetitions turned into separate segments (per SVG spec, extra
// coordinate groups after "m" become implicit lineto segments).

const COMMAND_RE = /[MmLlHhVvCcSsQqTtAaZz]/

const ARITY = { M: 2, L: 2, H: 1, V: 1, C: 6, S: 4, Q: 4, T: 2, A: 7 }

export function pathSegments(pathStr) {
  let normalized = String(pathStr)
    .replace(/([MmLlHhVvCcSsQqTtAaZz])/g, ' $1 ')
    .replace(/,/g, ' ')

  for (let i = 0; i < 5; i++) {
    normalized = normalized.replace(/(\d)(-)/g, '$1 $2')
  }

  const parts = normalized.split(/\s+/).filter(Boolean)

  // Group numbers under their command letter.
  const groups = []
  let current = null
  for (const part of parts) {
    if (COMMAND_RE.test(part)) {
      const type = part.toUpperCase()
      current = { type, rel: part !== part.toUpperCase(), nums: [] }
      groups.push(current)
    } else if (current) {
      const num = parseFloat(part)
      if (!isNaN(num)) current.nums.push(num)
    }
  }

  // Chunk each group's flat numbers into arity-sized segments, expanding
  // implicit repetitions. Trailing incomplete groups are dropped (matches
  // the previous parsers' bounds-checked behavior).
  const segments = []
  for (const group of groups) {
    if (group.type === 'Z') {
      segments.push({ type: 'Z', rel: group.rel, nums: [] })
      continue
    }
    const arity = ARITY[group.type]
    for (let i = 0; i + arity <= group.nums.length; i += arity) {
      // Per SVG spec, subsequent coordinate groups after a moveto are
      // implicit lineto segments.
      const type = group.type === 'M' && i > 0 ? 'L' : group.type
      segments.push({ type, rel: group.rel, nums: group.nums.slice(i, i + arity) })
    }
  }
  return segments
}

// Endpoint-only extraction, equivalent to what the writing hook needs:
// one point per segment (the segment's end position).
export function pathEndpoints(pathStr) {
  const points = []
  let currentX = 0
  let currentY = 0

  for (const seg of pathSegments(pathStr)) {
    const n = seg.nums
    switch (seg.type) {
      case 'M':
      case 'L':
        currentX = seg.rel ? currentX + n[0] : n[0]
        currentY = seg.rel ? currentY + n[1] : n[1]
        points.push({ x: currentX, y: currentY })
        break
      case 'H':
        currentX = seg.rel ? currentX + n[0] : n[0]
        points.push({ x: currentX, y: currentY })
        break
      case 'V':
        currentY = seg.rel ? currentY + n[0] : n[0]
        points.push({ x: currentX, y: currentY })
        break
      case 'C':
      case 'S':
      case 'Q':
      case 'T':
      case 'A':
        currentX = seg.rel ? currentX + n[n.length - 2] : n[n.length - 2]
        currentY = seg.rel ? currentY + n[n.length - 1] : n[n.length - 1]
        points.push({ x: currentX, y: currentY })
        break
      case 'Z':
        break
    }
  }
  return points
}
