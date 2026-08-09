/**
 * Shared meaning-answer evaluation used by word challenges.
 *
 * Handles:
 *   - multiple alternative meanings separated by / , ;
 *   - parenthetical usage examples (e.g. "to eat (food)")
 *   - optional leading "to " for verb meanings
 *   - extra whitespace and case differences
 */

function normalizeMeaning(s) {
  return s
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .replace(/\(.*?\)/g, '')
    .trim()
}

function stripLeadingTo(s) {
  let t = s.trim()
  while (t.startsWith('to ')) {
    t = t.slice(3).trim()
  }
  return t
}

export function evaluateMeaningAnswer(word, input) {
  const meaningStr = String(word?.meaning || '')
  const rawInput = String(input || '')
  if (!meaningStr || !rawInput.trim()) return false

  const accepted = meaningStr
    .split(/[\/;,]/)
    .map((part) => stripLeadingTo(normalizeMeaning(part)))
    .filter(Boolean)

  const normalized = stripLeadingTo(normalizeMeaning(rawInput))
  if (!normalized) return false

  return accepted.includes(normalized)
}
