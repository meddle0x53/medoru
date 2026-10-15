/**
 * Roguelike upgrade engine (Phase 1).
 *
 * Loads the upgrade card pool from ../data/upgrades.json and applies cards
 * to the player's run-scoped loadout state. Cards are plain data so the pool
 * can grow (target ~45 cards) without touching this resolver.
 *
 * Card schema (see data/upgrades.json):
 *   id          unique card id
 *   name/...    display fields
 *   rarity      common | uncommon | rare | epic
 *   family      stat | flat | conversion | unlock | ability
 *   tags        generator weighting hooks
 *   type        stat | flat_stamina | flat_active_slot | weapon_profile
 *               | unlock_ability | ability_modifier | kanji_tier_up
 *   maxStacks   defaults to 1 (unique card)
 *   excludes    card ids that cannot coexist with this card
 *   prerequisites card ids that must be owned first
 *   effect      type-specific payload
 *
 * `apply(player, upgradeId)` enforces stack limits, exclusions and
 * prerequisites, mutates run state, records the card in
 * `loadout.runUpgrades`, and returns `{ ok, reason? }`.
 */

import upgradesData from '../data/upgrades.json'
import { ALL_ACTIONS } from '../data/actions.js'

export const UPGRADES = upgradesData.upgrades || []

export const UPGRADES_BY_ID = Object.fromEntries(UPGRADES.map(u => [u.id, u]))

// Kanji tier ladder (D11): absent char = green; silver is the cap.
export const KANJI_TIERS = ['green', 'blue', 'purple', 'silver']

export function countUpgrade(player, upgradeId) {
  const owned = player.loadout?.runUpgrades || []
  return owned.filter(u => (u.upgradeId || u.id) === upgradeId).length
}

export function apply(player, upgradeId) {
  const card = UPGRADES_BY_ID[upgradeId]
  if (!card) return { ok: false, reason: 'Unknown upgrade.' }

  const maxStacks = card.maxStacks || 1
  if (countUpgrade(player, upgradeId) >= maxStacks) {
    return { ok: false, reason: `${card.name} is already at max stacks.` }
  }
  for (const excludedId of card.excludes || []) {
    if (countUpgrade(player, excludedId) > 0) {
      const excluded = UPGRADES_BY_ID[excludedId]
      return { ok: false, reason: `Conflicts with ${excluded?.name || excludedId}.` }
    }
  }
  for (const prereqId of card.prerequisites || []) {
    if (countUpgrade(player, prereqId) === 0) {
      const prereq = UPGRADES_BY_ID[prereqId]
      return { ok: false, reason: `Requires ${prereq?.name || prereqId} first.` }
    }
  }

  const loadout = player.loadout
  if (!Array.isArray(loadout.runUpgrades)) loadout.runUpgrades = []
  const effect = card.effect || {}

  switch (card.type) {
    case 'stat': {
      const stat = effect.stat
      if (!stat || player.baseStats?.[stat] === undefined) {
        return { ok: false, reason: 'Unknown stat.' }
      }
      player.baseStats[stat] += 1
      player[stat] = player.baseStats[stat]
      if (stat === 'vitality') player.recalcMaxHp()
      if (stat === 'stamina') player.recalcMaxStamina()
      break
    }
    case 'flat_stamina': {
      loadout.staminaFlatBonus = (loadout.staminaFlatBonus || 0) + 1
      player.recalcMaxStamina()
      break
    }
    case 'flat_active_slot': {
      loadout.activeSlotBonus = (loadout.activeSlotBonus || 0) + 1
      player.refreshActions()
      break
    }
    case 'weapon_profile': {
      loadout.weaponProfileOverride = effect.charmId || null
      break
    }
    case 'unlock_ability': {
      const learned = player.learnAbility(effect.abilityId)
      if (!learned.ok) return learned
      break
    }
    case 'ability_modifier': {
      // Nothing to precompute: getEffectiveAbility() reads the modifier
      // from loadout.runUpgrades at use time.
      break
    }
    case 'kanji_tier_up': {
      const ability = ALL_ACTIONS.find(a => a.id === effect.abilityId)
      const pool = ability?.kanjiPool || []
      if (!loadout.kanjiTiers) loadout.kanjiTiers = {}
      const abilityTiers = loadout.kanjiTiers[effect.abilityId] || {}
      // Only pool chars below the silver cap can be raised.
      const candidates = pool.filter(char => (abilityTiers[char] || 'green') !== 'silver')
      if (candidates.length === 0) {
        return { ok: false, reason: 'All pool kanji are already at silver tier.' }
      }
      const char = candidates[Math.floor(Math.random() * candidates.length)]
      const current = abilityTiers[char] || 'green'
      const next = KANJI_TIERS[KANJI_TIERS.indexOf(current) + 1]
      if (!next) return { ok: false, reason: 'Kanji tier is already at the cap.' }
      abilityTiers[char] = next
      loadout.kanjiTiers[effect.abilityId] = abilityTiers
      break
    }
    default:
      return { ok: false, reason: `Unsupported upgrade type: ${card.type}` }
  }

  loadout.runUpgrades.push({ upgradeId: card.id, ...card })
  player.saveLoadout?.()
  return { ok: true, card }
}
