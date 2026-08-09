import { ITEMS } from '../data/items.js'
import { ALL_ACTIONS } from '../data/actions.js'
import { CHARMS, CHARM_TYPES } from '../data/charms.js'

const RARITY_WEIGHTS = {
  common: 0.70,
  uncommon: 0.15,
  rare: 0.10,
  epic: 0.05,
}

const ABILITY_CHARM_CHANCE = 0.90
const UPGRADE_CHANCE = 0.10
const STAT_POINT_CHANCE = 0.05

export function openChest(player) {
  const mult = player.getNgPlusMultiplier()
  const scaleValue = (v) => (mult === 1 ? v : Math.ceil(v * mult))
  const scaleChance = (c) => Math.min(1, c * mult)

  const rewards = []

  // 1. Gold: 20-80, divisible by 10.
  const gold = scaleValue(rollGold())
  player.addGold(gold)
  rewards.push({ type: 'gold', value: gold })

  // 2. Items: 1-3 random items with weighted rarity.
  const itemCount = Math.min(5, scaleValue(rollItemCount()))
  for (let i = 0; i < itemCount; i++) {
    const rarity = rollRarity(mult)
    const item = pickRandom(ITEMS.filter(it => it.rarity === rarity))
    if (item) {
      player.addItem(item.id, 1)
      rewards.push({ type: 'item', item })
    }
  }

  // 3. Ability or weapon charm.
  if (Math.random() < scaleChance(ABILITY_CHARM_CHANCE)) {
    grantAbilityOrCharmReward(player, rewards, mult)
  }

  // 4. Stat point.
  if (Math.random() < scaleChance(STAT_POINT_CHANCE)) {
    const points = scaleValue(1)
    player.loadout.statPoints = (player.loadout.statPoints || 0) + points
    player.saveLoadout()
    rewards.push({ type: 'statPoint', value: points })
  }

  return rewards
}

export function getUpgradeOptions(player) {
  const mult = player.getNgPlusMultiplier()
  const scaleChance = (c) => Math.min(1, c * mult)
  if (Math.random() >= scaleChance(UPGRADE_CHANCE)) return []

  const options = []
  if (player.weapon && player.weapon.level < (player.weapon.maxLevel || 10)) {
    options.push({
      id: 'weapon',
      type: 'weapon',
      name: 'Upgrade Weapon',
      icon: '⚔️',
      nextLevel: (player.weapon.level || 0) + 1,
    })
  }
  if (player.shield && player.shield.level < (player.shield.maxLevel || 10)) {
    options.push({
      id: 'shield',
      type: 'shield',
      name: 'Upgrade Shield',
      icon: '🛡️',
      nextLevel: (player.shield.level || 0) + 1,
    })
  }
  return options
}

export function applyUpgrade(player, option) {
  if (option.type === 'weapon' && player.weapon) {
    player.weapon.level = (player.weapon.level || 0) + 1
    player.weapon.baseDamage = (player.weapon.baseDamage || 0) + 2
  } else if (option.type === 'shield' && player.shield) {
    player.shield.level = (player.shield.level || 0) + 1
    player.shield.baseDefense = (player.shield.baseDefense || 0) + 1
  }
  player.saveLoadout()
}

function grantAbilityOrCharmReward(player, rewards, mult = 1) {
  const rarity = rollRarity(mult)
  const giveAbility = Math.random() < (mult === 1 ? 0.5 : Math.min(1, 0.5 * mult))

  if (giveAbility) {
    const ability = pickUnknownAbility(player, rarity)
    if (ability) {
      const result = player.learnAbility(ability.id)
      if (result.added) {
        rewards.push({ type: 'ability', ability })
        return
      }
    }
    // Fallback to a weapon charm if no new ability was available.
    const charm = pickRandomWeaponCharm(rarity)
    if (charm) {
      player.addCharm(charm.id)
      rewards.push({ type: 'charm', charm })
    }
  } else {
    const charm = pickRandomWeaponCharm(rarity)
    if (charm) {
      const beforeOwned = player.loadout.ownedCharmIds?.includes(charm.id)
      player.addCharm(charm.id)
      const afterOwned = player.loadout.ownedCharmIds?.includes(charm.id)
      rewards.push({ type: 'charm', charm, isNew: !beforeOwned && afterOwned })
      return
    }
    // Fallback to an ability if no weapon charm was available.
    const ability = pickUnknownAbility(player, rarity)
    if (ability) {
      const result = player.learnAbility(ability.id)
      if (result.added) {
        rewards.push({ type: 'ability', ability })
      }
    }
  }
}

function pickUnknownAbility(player, rarity) {
  const knownIds = new Set(player.loadout?.knownActionIds || [])
  const pool = ALL_ACTIONS.filter(
    a => a.id !== 'use_item' && mapAbilityRarity(a.rarity) === rarity && !knownIds.has(a.id),
  )
  if (pool.length > 0) return pickRandom(pool)

  // Fallback to any unknown ability if none of the target rarity are available.
  const anyUnknown = ALL_ACTIONS.filter(a => a.id !== 'use_item' && !knownIds.has(a.id))
  return anyUnknown.length > 0 ? pickRandom(anyUnknown) : null
}

function pickRandomWeaponCharm(rarity) {
  const pool = CHARMS.filter(
    c => c.type === CHARM_TYPES.WEAPON && mapAbilityRarity(c.rarity) === rarity,
  )
  if (pool.length > 0) return pickRandom(pool)

  // Fallback to any weapon charm.
  const any = CHARMS.filter(c => c.type === CHARM_TYPES.WEAPON)
  return any.length > 0 ? pickRandom(any) : null
}

function rollGold() {
  // 20-80 in steps of 10 => 2-8 * 10
  return (Math.floor(Math.random() * 7) + 2) * 10
}

function rollItemCount() {
  return Math.floor(Math.random() * 3) + 1
}

function rollRarity(mult = 1) {
  let weights = { ...RARITY_WEIGHTS }
  if (mult > 1) {
    // Shift weights toward higher rarities on higher NG+ levels.
    weights.uncommon = Math.min(0.60, weights.uncommon * mult)
    weights.rare = Math.min(0.50, weights.rare * mult)
    weights.epic = Math.min(0.40, weights.epic * mult)
    const total = Object.values(weights).reduce((sum, w) => sum + w, 0)
    if (total > 0) {
      for (const key of Object.keys(weights)) {
        weights[key] /= total
      }
    }
  }
  const roll = Math.random()
  let cumulative = 0
  for (const [rarity, weight] of Object.entries(weights)) {
    cumulative += weight
    if (roll < cumulative) return rarity
  }
  return 'common'
}

function pickRandom(array) {
  if (!array || array.length === 0) return null
  return array[Math.floor(Math.random() * array.length)]
}

function mapAbilityRarity(rarity) {
  // Legacy/normal abilities are treated as common for chest loot.
  if (rarity === 'normal') return 'common'
  return rarity || 'common'
}
