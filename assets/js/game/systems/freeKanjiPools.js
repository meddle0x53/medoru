import { getWindowGameData, fetchKanjiChallengeData } from '../api.js'
import { ALL_ACTIONS } from '../data/actions.js'

/**
 * Free kanji mode.
 *
 * Default mode: abilities challenge the kanji from their static `kanjiPool`
 * declared in the ability JSON.
 *
 * Free mode: when a run starts, every ability that has a static kanjiPool gets
 * its own pool of 5 kanji rolled at random from the JLPT levels selected in
 * the settings. The rolled pools are fixed for the whole run and replace the
 * static pools entirely. Kanji may overlap between different abilities' pools.
 *
 * Stroke data for the rolled kanji is preloaded at run start so challenge
 * resolution stays synchronous. Focus-kanji override behavior is unchanged —
 * it uses the same per-ability chance as the default static pools.
 *
 * Settings (`kanjiChallengeMode`, `freeKanjiLevels`) live in the loadout and
 * persist across runs; changing them mid-run only affects the next run
 * because pools are rolled once when a run begins.
 */

// In-memory stroke cache for rolled kanji, keyed by character. Entries have
// the same shape as all_kanji entries ({ character, stroke_data, meanings }).
const strokeCache = new Map()

const FALLBACK_LEVELS = [5]
const POOL_SIZE = 5
const MAX_REFILL_ROUNDS = 3

export function isFreeKanjiMode(player) {
  return player?.loadout?.kanjiChallengeMode === 'free'
}

export function getFreeKanjiLevels(player) {
  const levels = player?.loadout?.freeKanjiLevels
  return Array.isArray(levels) && levels.length > 0 ? levels : FALLBACK_LEVELS
}

// Kanji entries (from window.gameData) filtered to the selected JLPT levels.
function getLevelSource(player) {
  const levels = new Set(getFreeKanjiLevels(player))
  return (getWindowGameData()?.all_kanji || []).filter(k => k.character && levels.has(k.jlpt_level))
}

function sampleChars(source, n, exclude = []) {
  const excluded = new Set(exclude)
  const candidates = source.filter(k => !excluded.has(k.character))
  const picked = []
  while (picked.length < n && candidates.length > 0) {
    const idx = Math.floor(Math.random() * candidates.length)
    picked.push(candidates.splice(idx, 1)[0].character)
  }
  return picked
}

// The pool a challenge should draw from: the run's rolled pool in free mode,
// otherwise the ability's static JSON pool. Abilities without a static pool
// never get one.
export function getEffectiveKanjiPool(player, skill) {
  if (!skill) return []
  if (isFreeKanjiMode(player)) {
    const freePool = player.loadout?.freeKanjiRunPools?.[skill.id]
    if (Array.isArray(freePool) && freePool.length > 0) return freePool
  }
  return skill.kanjiPool || []
}

// Resolve a kanji character to a data entry with usable stroke data:
// learned kanji first, then server-embedded kanji, then the fetched cache.
export function resolveKanjiData(player, char) {
  if (!char) return null
  const fromList = player?.kanjiList?.find(k => k.character === char)
  if (fromList?.stroke_data?.strokes?.length > 0) return fromList
  const fromAll = getWindowGameData()?.all_kanji?.find(k => k.character === char)
  if (fromAll?.stroke_data?.strokes?.length > 0) return fromAll
  const cached = strokeCache.get(char)
  if (cached?.stroke_data?.strokes?.length > 0) return cached
  return null
}

// Roll run pools for every ability that has a static kanjiPool. Idempotent
// per run: existing pools are kept so a settings change mid-run only applies
// to the next run.
export function generateFreeKanjiRunPools(player) {
  const loadout = player.loadout
  if (!isFreeKanjiMode(player)) return null
  if (loadout.freeKanjiRunPools) return loadout.freeKanjiRunPools

  const source = getLevelSource(player)
  const pools = {}
  for (const action of ALL_ACTIONS) {
    if (!Array.isArray(action.kanjiPool) || action.kanjiPool.length === 0) continue
    pools[action.id] = sampleChars(source, POOL_SIZE)
  }
  loadout.freeKanjiRunPools = pools
  player.saveLoadout()
  return pools
}

async function preloadPoolStrokes(player) {
  const pools = player.loadout?.freeKanjiRunPools
  if (!pools) return
  const chars = [...new Set(Object.values(pools).flat())].filter(c => !resolveKanjiData(player, c))
  await Promise.all(chars.map(async (char) => {
    const data = await fetchKanjiChallengeData(char)
    if (data?.stroke_data?.strokes?.length > 0) {
      const meta = getWindowGameData()?.all_kanji?.find(k => k.character === char)
      strokeCache.set(char, {
        character: char,
        stroke_data: data.stroke_data,
        meanings: meta?.meanings || [],
        on_readings: data.on_readings || [],
        kun_readings: data.kun_readings || [],
        challenge_word: data.challenge_word || null,
      })
    }
  }))
}

/**
 * Picks the example word shown next to a kanji drawing challenge: the most
 * frequent word the user has learned that contains the kanji, falling back
 * to the kanji's own most frequent word (from the server-provided data).
 */
export function getChallengeWordForKanji(player, char, kanjiData = null) {
  if (!char) return null
  const known = (player?.wordList || [])
    .filter(w => typeof w.word === 'string' && w.word.includes(char))
    .sort((a, b) => (a.usage_frequency ?? 999_999) - (b.usage_frequency ?? 999_999))[0]
  if (known) {
    return { word: known.word, reading: known.reading, meaning: known.meaning }
  }
  return kanjiData?.challenge_word || null
}

/**
 * Roll pools (first call of a run) and preload stroke data. Rolled kanji with
 * no stroke data in the database are re-rolled so pools stay effective.
 * Idempotent per run — safe to call on every map/loadout entry; after the
 * first run-scene visit the stroke cache is warm and this resolves quickly.
 */
export async function prepareFreeKanjiPools(player) {
  if (!isFreeKanjiMode(player)) {
    // Clear stale pools from a previous free-mode run.
    if (player.loadout?.freeKanjiRunPools) {
      player.loadout.freeKanjiRunPools = null
      player.saveLoadout()
    }
    return
  }
  const pools = generateFreeKanjiRunPools(player)
  if (!pools) return

  const source = getLevelSource(player)
  for (let round = 0; round < MAX_REFILL_ROUNDS; round++) {
    await preloadPoolStrokes(player)
    let changed = false
    for (const pool of Object.values(pools)) {
      for (let i = 0; i < pool.length; i++) {
        if (!resolveKanjiData(player, pool[i])) {
          const [replacement] = sampleChars(source, 1, pool)
          if (replacement) {
            pool[i] = replacement
            changed = true
          }
        }
      }
    }
    if (!changed) break
    player.saveLoadout()
  }
}
