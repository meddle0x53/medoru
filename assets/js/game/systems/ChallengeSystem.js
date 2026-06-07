import { DEFAULT_KANJI_POOL } from '../data/enemies.js'

/**
 * Handles kanji/word challenges before skill execution.
 */
export default class ChallengeSystem {
  constructor(kanjiPool = null) {
    // Use user's learned kanji if available, else default pool
    this.pool = kanjiPool && kanjiPool.length > 0 ? kanjiPool : DEFAULT_KANJI_POOL
  }

  getChallengeForSkill(skill) {
    if (!skill.challenge) {
      return null
    }
    return {
      ...skill.challenge,
      startTime: Date.now(),
    }
  }

  getRandomChallenge() {
    const item = this.pool[Math.floor(Math.random() * this.pool.length)]
    return {
      kanji: item.character,
      readings: item.readings,
      prompt: `Type the reading of ${item.character}`,
      timeLimit: 5000,
      startTime: Date.now(),
    }
  }

  evaluate(input, challenge) {
    const elapsed = Date.now() - challenge.startTime
    const normalized = input.trim().toLowerCase()
    const isCorrect = challenge.readings.some(r => r.toLowerCase() === normalized)

    if (!isCorrect) return { result: 'fail', elapsed }
    if (elapsed <= challenge.timeLimit * 0.4) return { result: 'perfect', elapsed }
    return { result: 'success', elapsed }
  }
}
