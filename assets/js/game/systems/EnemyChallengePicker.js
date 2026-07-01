import { DEFAULT_KANJI_POOL } from '../data/defaultKanjiPool.js'

const JLPT_ORDER = { N5: 1, N4: 2, N3: 3, N2: 4, N1: 5 }

// Word challenges should only use concrete parts of speech, not set phrases/expressions.
const ALLOWED_CHALLENGE_WORD_TYPES = new Set(['noun', 'verb', 'adjective', 'adverb'])

export function isChallengeWord(word) {
  return word != null && ALLOWED_CHALLENGE_WORD_TYPES.has(word.word_type)
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

function matchesKanjiFilters(kanji, filters = {}) {
  if (!kanji || !kanji.character) return false

  if (filters.jlptLevels && filters.jlptLevels.length > 0) {
    if (!filters.jlptLevels.includes(kanji.jlpt_level)) return false
  }

  if (filters.maxKnownScore != null && kanji.known_score != null) {
    if (kanji.known_score > filters.maxKnownScore) return false
  }

  return true
}

const MIN_FILTERED_WORD_POOL = 20

export function pickWordForChallenge(player, filters = {}) {
  // Exclude expressions and other non-challenge word types first.
  const allowedPool = filterChallengeWords(player?.wordList)
  const candidates = allowedPool.filter(w => matchesWordFilters(w, filters))

  // If the filtered pool is too small, fall back to the full allowed pool so challenges stay varied.
  const source = candidates.length >= MIN_FILTERED_WORD_POOL ? candidates : allowedPool
  if (source.length === 0) return null

  const shuffled = shuffle(source)
  return shuffled[0]
}

export function pickKanjiForChallenge(player, filters = {}, specificKanji = null) {
  if (specificKanji) {
    const fromPool = player?.kanjiList?.find(k => k.character === specificKanji)
    const fallback = DEFAULT_KANJI_POOL.find(k => k.character === specificKanji)
    const kanji = fromPool || fallback
    if (!kanji) return null
    return {
      kanji: kanji.character,
      readings: [
        ...(kanji.on_readings || []),
        ...(kanji.kun_readings || []),
        ...(kanji.readings || []),
      ],
      prompt: `Type the reading of ${kanji.character}`,
    }
  }

  const pool = player?.kanjiList?.length > 0 ? player.kanjiList : DEFAULT_KANJI_POOL
  const candidates = pool.filter(k => matchesKanjiFilters(k, filters))
  const source = candidates.length > 0 ? candidates : pool
  if (source.length === 0) return null

  const kanji = shuffle(source)[0]
  const meanings = Array.isArray(kanji.meanings) ? kanji.meanings.join(', ') : ''
  return {
    kanji: kanji.character,
    readings: [
      ...(kanji.on_readings || []),
      ...(kanji.kun_readings || []),
      ...(kanji.readings || []),
    ],
    prompt: `Type the reading of ${kanji.character}`,
    hint: meanings,
  }
}

export function buildEnemyChallenge(player, challengeConfig) {
  if (!challengeConfig) return null

  switch (challengeConfig.type) {
    case 'word': {
      const word = pickWordForChallenge(player, challengeConfig.filters)
      if (!word) return null
      const isReading = challengeConfig.promptType === 'reading'
      const prompt = isReading
        ? 'Type the reading of this word (latin or kana):'
        : 'Type the meaning of this word:'
      return {
        type: 'word',
        word,
        promptType: challengeConfig.promptType || 'meaning',
        prompt,
        hint: isReading ? '' : (word.reading || ''),
        timeLimit: challengeConfig.timeLimit || 6000,
        onSuccess: challengeConfig.onSuccess || 'weaken',
        onFail: challengeConfig.onFail || 'full',
        weakenMultiplier: challengeConfig.weakenMultiplier || 0.5,
      }
    }
    case 'kanji': {
      const specific = challengeConfig.source === 'specific'
        ? challengeConfig.specificKanji
        : null
      const kanjiChallenge = pickKanjiForChallenge(player, challengeConfig.filters, specific)
      if (!kanjiChallenge) return null
      return {
        type: 'kanji',
        ...kanjiChallenge,
        timeLimit: challengeConfig.timeLimit || 5000,
        onSuccess: challengeConfig.onSuccess || 'weaken',
        onFail: challengeConfig.onFail || 'full',
        weakenMultiplier: challengeConfig.weakenMultiplier || 0.5,
      }
    }
    default:
      return null
  }
}
