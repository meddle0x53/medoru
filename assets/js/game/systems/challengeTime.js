/**
 * Returns the time limit to use for word challenges.
 *
 * On touch devices typing is slower, so every word challenge gets a generous
 * 20 second limit. On non-touch devices the requested/base limit is preserved.
 */
export function getWordChallengeTimeLimit(scene, requestedLimit = null) {
  if (scene?.sys?.game?.device?.input?.touch) {
    return 20000
  }
  return requestedLimit ?? 13000
}
