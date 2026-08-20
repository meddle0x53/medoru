/**
 * Returns the time limit to use for word challenges.
 *
 * On touch devices typing is slower, so every word challenge gets a generous
 * 25 second limit. On non-touch devices the requested/base limit is preserved.
 */
export function getWordChallengeTimeLimit(scene, requestedLimit = null) {
  if (window.matchMedia('(pointer: coarse)').matches) {
    return 25000
  }
  return requestedLimit ?? 13000
}
