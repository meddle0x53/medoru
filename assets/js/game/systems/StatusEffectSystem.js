import { getEffect, rollChance, rollDuration } from './EffectRegistry.js'

/**
 * Apply the status effects declared on an ability.
 *
 * @param {object} ability - ability JSON with optional `effects` array
 * @param {Character} performer - the character using the ability
 * @param {Character} target - the primary target of the ability
 * @param {object} ctx - context such as `initialDamage` for snapshot DoTs
 * @param {function} log - combat log callback
 * @returns {object[]} list of applied effect events
 */
export function applyAbilityEffects(ability, performer, target, ctx = {}, log = () => {}, consecutiveHits = 1, chanceMultiplier = 1) {
  const effects = ability?.effects
  if (!effects || effects.length === 0) return []

  const applied = []
  const chanceOverrides = ctx?.chanceOverrides || {}

  for (const effectConfig of effects) {
    const effect = getEffect(effectConfig.effectId)
    if (!effect) continue

    let chance
    if (chanceOverrides[effectConfig.effectId] != null) {
      chance = chanceOverrides[effectConfig.effectId]
    } else {
      const chanceConfig = effectConfig.chance
      const rawChance = chanceConfig ? rollChance(chanceConfig, consecutiveHits) : 1
      chance = Math.min(1, rawChance * (chanceMultiplier || 1))
    }
    if (Math.random() >= chance) continue

    const recipient = effectConfig.target === 'self' ? performer : target
    if (!recipient) continue

    const duration = effectConfig.duration ? rollDuration({ duration: effectConfig.duration }) : null
    const options = { duration }

    if (effect.tick && effect.tick.damage && effect.tick.damage.source === 'snapshot') {
      options.snapshot = ctx.initialDamage || 0
    }

    const entry = recipient.applyEffect(effectConfig.effectId, options)
    if (entry) {
      applied.push({ effectId: effectConfig.effectId, recipient })
      log(`${recipient.name || 'The enemy'} is ${effect.name} (${entry.remainingTurns} turns).`)
    }
  }

  return applied
}
