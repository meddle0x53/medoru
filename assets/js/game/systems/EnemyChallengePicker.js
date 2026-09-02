// Word challenges should only use concrete vocabulary: nouns, verbs and
// adjectives. Set phrases/expressions, particles, counters, pronouns, etc.
// are excluded everywhere a word challenge can appear.
const CHALLENGE_WORD_TYPES = new Set(['noun', 'verb', 'adjective'])

export function isChallengeWord(word) {
  if (word == null) return false
  // Learned words come through with `type`, while vocabulary/being-learned
  // words use `word_type` — accept both keys.
  const wordType = word.word_type ?? word.type
  return CHALLENGE_WORD_TYPES.has(wordType)
}

export function filterChallengeWords(words) {
  return (words || []).filter(isChallengeWord)
}

function shuffle(array) {
  const arr = array.slice()
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[arr[i], arr[j]] = [arr[j], arr[i]]
  }
  return arr
}

function matchesWordFilters(word, filters = {}) {
  if (!word || !word.meaning) return false

  // Words do not have a JLPT level field; only apply this filter if present.
  if (filters.jlptLevels && filters.jlptLevels.length > 0 && word.jlpt_level != null) {
    if (!filters.jlptLevels.includes(word.jlpt_level)) return false
  }

  // Frequency can come from either a direct frequency field or the word's core rank.
  if (filters.maxFrequency != null) {
    const freq = word.frequency ?? word.core_rank
    if (freq != null && freq > filters.maxFrequency) return false
  }

  return true
}

const MIN_FILTERED_WORD_POOL = 20

export function pickWordForChallenge(player, filters = {}) {
  // Words currently being learned have a 50% chance to override the normal pool.
  const beingLearned = player?.getBeingLearnedWords?.() || []
  if (beingLearned.length > 0 && Math.random() < 0.5) {
    const overridePool = filterChallengeWords(beingLearned).filter(w => matchesWordFilters(w, filters))
    if (overridePool.length > 0) {
      const shuffled = shuffle(overridePool)
      return shuffled[0]
    }
  }

  // Filter to nouns/verbs/adjectives first.
  const allowedPool = filterChallengeWords(player?.getChallengeWordList?.() || player?.wordList)
  const candidates = allowedPool.filter(w => matchesWordFilters(w, filters))

  // If the filtered pool is too small, fall back to the full allowed pool so challenges stay varied.
  const source = candidates.length >= MIN_FILTERED_WORD_POOL ? candidates : allowedPool
  if (source.length === 0) return null

  const shuffled = shuffle(source)
  return shuffled[0]
}

export function buildEnemyChallenge(player, challengeConfig) {
  if (!challengeConfig) return null

  // Enemy ability challenges are always word/meaning prompts (no kanji typing).
  const word = pickWordForChallenge(player, challengeConfig.filters)
  if (!word) return null
  return {
    type: 'word',
    word,
    promptType: 'meaning',
    prompt: 'Type the meaning of this word:',
    hint: word.reading || '',
    timeLimit: challengeConfig.timeLimit || 13000,
    onSuccess: challengeConfig.onSuccess || 'weaken',
    onFail: challengeConfig.onFail || 'full',
    weakenMultiplier: challengeConfig.weakenMultiplier || 0.5,
  }
}
