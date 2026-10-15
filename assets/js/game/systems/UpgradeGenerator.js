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
const QUALITY_REROLL_ATTEMPTS = 2

// Rarity band floors for the reserved slot (uncommon+ / rare+ / epic-only).
function bandForTier(tier) {
  switch (tier) {
    case 'uncommon': return ['uncommon', 'rare', 'epic']
    case 'rare': return ['rare', 'epic']
    case 'epic': return ['epic']
    default: return RARITY_ORDER
  }
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
  return 1 + matches * TAG_MATCH_WEIGHT
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
  const band = bandForTier(tier)
  const choices = []
  const excludeIds = new Set()

  // Slot 1: reserved for the roll's rarity floor (normal table for common).
  // When the band is exhausted the floor cannot be honored — return nothing
  // rather than a sub-floor screen (Phase 3 gates on emptiness).
  const first = pickCard(player, band, excludeIds)
  if (!first) return []
  choices.push(first)
  excludeIds.add(first.card.id)

  // Slots 2–3: normal table.
  for (let i = choices.length; i < 3; i++) {
    const pick = pickCard(player, RARITY_ORDER, excludeIds)
    if (!pick) break
    choices.push(pick)
    excludeIds.add(pick.card.id)
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
    // Never violate the reserved slot's rarity floor when rerolling it.
    const rerollBand = lowestIndex === 0 ? band : RARITY_ORDER
    const replacement = pickCard(player, rerollBand, excludeIds)
    excludeIds.add(lowest.card.id)
    if (!replacement) break
    choices[lowestIndex] = replacement
    excludeIds.add(replacement.card.id)
  }

  return choices.map(c => c.card)
}
