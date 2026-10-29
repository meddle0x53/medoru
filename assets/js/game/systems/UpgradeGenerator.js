/**
 * Roguelike upgrade generator (Phase 2).
 *
 * `generateChoices(player, tier = 'common')` returns up to 3 valid, weighted,
 * unique upgrade cards honoring the active roll's rarity floor:
 *
 * - tier !== 'common' → slot 1 is rolled inside the tier's rarity band
 *   (uncommon+ / rare+ / epic), weighted by the normal relative weights;
 *   slots 2–3 roll on the normal table (D8/D9 plumbing lives in Phase 3).
 * - Filtering: owned uniques/max-stacked cards, mutual exclusions and
 *   missing prerequisites are all rejected up front.
 * - Weighting: `1 + tagMatches * 0.5`, where matches come from owned upgrade
 *   tags, the weapon profile family, and the player's dominant (top-2) stats.
 * - Quality rule: if all 3 cards share one family and none is an
 *   ability_modifier, the lowest-weighted card is rerolled (max 2 attempts).
 *
 * A nearly-exhausted pool yields fewer than 3 cards (possibly none); the
 * caller (Phase 3 reward screen) gates on emptiness.
 */

import { UPGRADES } from './UpgradeEngine.js'
import { ALL_ACTIONS } from '../data/actions.js'
import { getSocketCharmById } from '../data/socketCharms.js'

// Normal rarity table (percent-scale relative weights).
export const RARITY_WEIGHTS = { common: 55, uncommon: 30, rare: 12, epic: 3 }
export const RARITY_ORDER = ['common', 'uncommon', 'rare', 'epic']

const TAG_MATCH_WEIGHT = 0.5
const RECALL_TAG_MATCH_WEIGHT = 1.0
const QUALITY_REROLL_ATTEMPTS = 2

// Knowledge cards (Phase 5) are read-side consumers of loadout.runUpgrades:
//   curiosity       — +1 reroll per upgrade screen (UpgradeScene)
//   memory          — screens offer one extra card (generator)
//   recall          — tag-match weight doubles (generator)
//   perfect_recall  — battle screens roll +2 columns deeper (WinScene)
//   enlightenment   — every opened screen bumps one rarity tier (UpgradeScene)
export function getKnowledgeEffects(player) {
  const owned = player.loadout?.runUpgrades || []
  const count = id => owned.filter(u => (u.upgradeId || u.id) === id).length
  return {
    curiosity: count('curiosity'),
    extraCards: count('memory') > 0 ? 1 : 0,
    tagWeight: count('recall') > 0 ? RECALL_TAG_MATCH_WEIGHT : TAG_MATCH_WEIGHT,
    columnBonus: count('perfect_recall') > 0 ? 2 : 0,
    tierBump: count('enlightenment') > 0 ? 1 : 0,
  }
}

const TIER_BUMP = { common: 'uncommon', uncommon: 'rare', rare: 'epic', epic: 'epic' }
export function bumpTier(tier) {
  return TIER_BUMP[tier] || 'common'
}

// Rarity band floors for the reserved slot (uncommon+ / rare+ / epic-only).
// Fallback chains: when a band has no applicable cards (e.g. every epic is
// still locked behind its prerequisite chain), drop one band instead of
// returning an empty screen.
const BAND_FALLBACKS = {
  common: [RARITY_ORDER],
  uncommon: [['uncommon', 'rare', 'epic'], RARITY_ORDER],
  rare: [['rare', 'epic'], ['uncommon', 'rare', 'epic'], RARITY_ORDER],
  epic: [['epic'], ['rare', 'epic'], RARITY_ORDER],
}

function bandsForTier(tier) {
  return BAND_FALLBACKS[tier] || BAND_FALLBACKS.common
}

// ---------- Validity ----------

function ownedCounts(player) {
  const counts = {}
  for (const u of player.loadout?.runUpgrades || []) {
    const id = u.upgradeId || u.id
    counts[id] = (counts[id] || 0) + 1
  }
  return counts
}

/**
 * Would this card be applicable right now? Mirrors UpgradeEngine's
 * stack/exclusion/prerequisite checks without mutating anything.
 */
export function isValidFor(player, card) {
  const counts = ownedCounts(player)
  if ((counts[card.id] || 0) >= (card.maxStacks || 1)) return false
  for (const excludedId of card.excludes || []) {
    if ((counts[excludedId] || 0) > 0) return false
  }
  for (const prereqId of card.prerequisites || []) {
    if ((counts[prereqId] || 0) <= 0) return false
  }
  // Mirror the engine's silver-cap rejection for kanji tier cards: when the
  // ability's whole pool is silver, the card can no longer apply.
  if (card.type === 'kanji_tier_up') {
    const ability = ALL_ACTIONS.find(a => a.id === card.effect?.abilityId)
    const tiers = player.loadout?.kanjiTiers?.[card.effect?.abilityId] || {}
    if (!(ability?.kanjiPool || []).some(char => (tiers[char] || 'green') !== 'silver')) return false
  }
  return true
}

// ---------- Weighting ----------

// Dominant stats: the player's top-2 base stats, as tag strings.
function dominantStatTags(player) {
  return Object.entries(player.baseStats || {})
    .sort((a, b) => b[1] - a[1])
    .slice(0, 2)
    .map(([stat]) => stat)
}

// All tag sources that boost a card's weight.
function playerTagSources(player) {
  const tags = new Set(dominantStatTags(player))
  for (const u of player.loadout?.runUpgrades || []) {
    for (const tag of u.tags || []) tags.add(tag)
  }
  const overrideCharm = getSocketCharmById(player.loadout?.weaponProfileOverride)
  if (overrideCharm?.abilityFamily) tags.add(overrideCharm.abilityFamily)
  return tags
}

/**
 * Generator weight for a card: 1 + 0.5 per tag match against the player's
 * owned upgrade tags, weapon profile family, and dominant stats.
 */
export function computeWeight(player, card) {
  const sources = playerTagSources(player)
  const matches = (card.tags || []).filter(tag => sources.has(tag)).length
  const tagWeight = getKnowledgeEffects(player).tagWeight
  return 1 + matches * tagWeight
}

// ---------- Picking ----------

function rollRarity(availableRarities, weights) {
  let total = 0
  for (const rarity of availableRarities) total += weights[rarity] || 0
  let roll = Math.random() * total
  for (const rarity of availableRarities) {
    roll -= weights[rarity] || 0
    if (roll < 0) return rarity
  }
  return availableRarities[availableRarities.length - 1]
}

// Weighted pick among valid cards of the rolled rarity. Returns
// { card, weight } or null when nothing valid remains.
function pickCard(player, band, excludeIds) {
  const candidates = UPGRADES.filter(
    card => band.includes(card.rarity) &&
      !excludeIds.has(card.id) &&
      isValidFor(player, card)
  )
  if (candidates.length === 0) return null

  const availableRarities = RARITY_ORDER.filter(r => candidates.some(c => c.rarity === r))
  const rarity = rollRarity(availableRarities, RARITY_WEIGHTS)
  const pool = candidates.filter(c => c.rarity === rarity)

  let total = 0
  const weighted = pool.map(card => {
    const weight = computeWeight(player, card)
    total += weight
    return { card, weight }
  })
  let roll = Math.random() * total
  for (const entry of weighted) {
    roll -= entry.weight
    if (roll < 0) return entry
  }
  return weighted[weighted.length - 1]
}

// ---------- Public API ----------

/**
 * Generate up to 3 upgrade card choices for a reward screen.
 * `tier` is the consumed roll tier ('common' default).
 */
export function generateChoices(player, tier = 'common') {
  const choices = []
  const excludeIds = new Set()

  // Register a chosen card's id and exclusions so mutually exclusive cards
  // (the weapon/shield conversion routes) never appear on the same screen.
  const registerExclusions = pick => {
    excludeIds.add(pick.card.id)
    for (const ex of pick.card.excludes || []) excludeIds.add(ex)
  }
  const addChoice = pick => {
    choices.push(pick)
    registerExclusions(pick)
  }

  // Slot 1: reserved for the roll's rarity floor (normal table for common).
  // When a band has no applicable cards (all owned, or every card still
  // locked behind a prerequisite chain), fall back one band rather than
  // returning an empty screen; empty only when nothing valid remains at all.
  let band = RARITY_ORDER
  let first = null
  for (const candidateBand of bandsForTier(tier)) {
    first = pickCard(player, candidateBand, excludeIds)
    if (first) { band = candidateBand; break }
  }
  if (!first) return []
  addChoice(first)

  // Slots 2–3 (or 2–4 with Memory): normal table.
  const targetCount = 3 + getKnowledgeEffects(player).extraCards
  for (let i = choices.length; i < targetCount; i++) {
    const pick = pickCard(player, RARITY_ORDER, excludeIds)
    if (!pick) break
    addChoice(pick)
  }

  // Card quality rule: a screen of one family with no ability modifier gets
  // its lowest-weighted card rerolled (max 2 attempts).
  for (let attempt = 0; attempt < QUALITY_REROLL_ATTEMPTS; attempt++) {
    if (choices.length < 3) break
    const families = new Set(choices.map(c => c.card.family))
    if (families.size !== 1) break
    if (choices.some(c => c.card.type === 'ability_modifier')) break

    const lowestIndex = choices.reduce((best, c, i) => (c.weight < choices[best].weight ? i : best), 0)
    const lowest = choices[lowestIndex]
    excludeIds.delete(lowest.card.id)
    for (const ex of lowest.card.excludes || []) excludeIds.delete(ex)
    // Never violate the reserved slot's rarity floor when rerolling it.
    const rerollBand = lowestIndex === 0 ? band : RARITY_ORDER
    const replacement = pickCard(player, rerollBand, excludeIds)
    excludeIds.add(lowest.card.id)
    if (!replacement) break
    choices[lowestIndex] = replacement
    registerExclusions(replacement)
  }

  return choices.map(c => c.card)
}
