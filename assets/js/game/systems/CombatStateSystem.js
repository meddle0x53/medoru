import stateData from '../data/combatStates.json'

const STATES = stateData.states || {}

export function getStateDefinition(stateId) {
  return STATES[stateId] || null
}

export function getAllStateDefinitions() {
  return Object.values(STATES)
}

// Ensure a character object has the combo-state container.
export function ensureComboStateContainer(entity) {
  if (!entity.comboStates) entity.comboStates = {}
  if (!entity.turnTagLedger && entity.isAlive && entity.resetForTurn) {
    // Only player-like entities track tags.
    entity.turnTagLedger = []
  }
}

export function hasComboState(entity, stateId) {
  if (!entity || !entity.comboStates) return false
  return !!entity.comboStates[stateId]
}

export function getComboState(entity, stateId) {
  if (!entity || !entity.comboStates) return null
  return entity.comboStates[stateId] || null
}

export function applyComboState(entity, stateId, source = null, customDuration = null) {
  if (!entity || !stateId) return false
  ensureComboStateContainer(entity)
  const def = getStateDefinition(stateId)
  if (!def) return false

  entity.comboStates[stateId] = {
    id: stateId,
    source,
    duration: customDuration || def.duration,
    appliedAt: Date.now(),
  }
  return true
}

export function removeComboState(entity, stateId) {
  if (!entity || !entity.comboStates) return null
  const state = entity.comboStates[stateId]
  if (!state) return null
  delete entity.comboStates[stateId]
  return state
}

export function consumeComboState(entity, stateId) {
  return removeComboState(entity, stateId)
}

export function getActiveComboStates(entity) {
  if (!entity || !entity.comboStates) return []
  return Object.values(entity.comboStates)
}

export function clearComboStates(entity) {
  if (!entity) return
  entity.comboStates = {}
}

/**
 * Expire states based on a lifecycle trigger.
 *
 * Triggers:
 *  - 'start_of_player_turn'
 *  - 'end_of_player_turn'
 *  - 'next_player_action'      (expires next_attack / per-action enemy states)
 *  - 'start_of_enemy_turn'
 *  - 'end_of_enemy_turn'
 *  - 'player_hit'              (expires until_hit states)
 *  - 'player_trigger'          (expires until_trigger states)
 *
 * Returns array of expired state IDs.
 */
export function expireStates(entity, trigger, logFn = null) {
  if (!entity || !entity.comboStates) return []
  const expired = []
  for (const stateId of Object.keys(entity.comboStates)) {
    const state = entity.comboStates[stateId]
    const def = getStateDefinition(stateId)
    const duration = state?.duration || def?.duration
    let shouldExpire = false

    switch (duration) {
      case 'end_of_turn':
        shouldExpire = trigger === 'end_of_player_turn' || trigger === 'end_of_enemy_turn'
        break
      case 'next_attack':
        shouldExpire = trigger === 'next_player_action' || trigger === 'end_of_player_turn' || trigger === 'end_of_enemy_turn'
        break
      case 'start_of_next_turn':
        shouldExpire = trigger === 'start_of_player_turn' || trigger === 'start_of_enemy_turn'
        break
      case 'until_hit':
        shouldExpire = trigger === 'player_hit'
        break
      case 'until_trigger':
        shouldExpire = trigger === 'player_trigger'
        break
      default:
        break
    }

    if (shouldExpire) {
      delete entity.comboStates[stateId]
      expired.push(stateId)
      if (logFn && def) logFn(`${def.name} faded.`)
    }
  }
  return expired
}

// ---------- Tag Ledger (player turn sequencing) ----------

export function recordTags(performer, tags = []) {
  if (!performer || !Array.isArray(tags)) return
  if (!performer.turnTagLedger) performer.turnTagLedger = []
  for (const tag of tags) {
    performer.turnTagLedger.push({ tag, at: Date.now() })
  }
}

export function clearTags(performer) {
  if (!performer) return
  performer.turnTagLedger = []
}

export function getTagsThisTurn(performer) {
  if (!performer || !performer.turnTagLedger) return []
  return performer.turnTagLedger.map((entry) => entry.tag)
}

export function hasTagThisTurn(performer, tag) {
  return getTagsThisTurn(performer).includes(tag)
}

export function getLastTag(performer) {
  if (!performer || !performer.turnTagLedger || performer.turnTagLedger.length === 0) return null
  return performer.turnTagLedger[performer.turnTagLedger.length - 1].tag
}

export function countDistinctTagsThisTurn(performer) {
  return new Set(getTagsThisTurn(performer)).size
}

// ---------- Combo Resolution Helpers ----------

export function resolveComboPrerequisites(skill, performer, target) {
  const combo = skill.combo
  if (!combo) return { ok: true }

  // Required previous tag in the same turn.
  if (combo.requiresPreviousTag) {
    const lastTag = getLastTag(performer)
    if (lastTag !== combo.requiresPreviousTag.tag) {
      return {
        ok: false,
        reason: `requires previous tag ${combo.requiresPreviousTag.tag}`,
      }
    }
  }

  // Required state to consume.
  if (combo.consumesState) {
    const subject = combo.consumesState.target === 'self' ? performer : target
    if (!hasComboState(subject, combo.consumesState.state)) {
      return {
        ok: false,
        reason: `requires ${combo.consumesState.state}`,
      }
    }
  }

  return { ok: true }
}

export function getComboDamageMultiplier(skill, performer, target) {
  let multiplier = 1
  const combo = skill.combo
  if (!combo) return multiplier

  if (combo.consumesState) {
    const subject = combo.consumesState.target === 'self' ? performer : target
    if (hasComboState(subject, combo.consumesState.state)) {
      multiplier *= combo.consumesState.damageMultiplier || 1
    }
  }

  if (combo.requiresPreviousTag) {
    const lastTag = getLastTag(performer)
    if (lastTag === combo.requiresPreviousTag.tag) {
      multiplier *= combo.requiresPreviousTag.damageMultiplier || 1
    }
  }

  return multiplier
}

export function shouldGuaranteeCritical(skill, performer, target) {
  const combo = skill.combo
  if (!combo) return false

  if (combo.consumesState && combo.consumesState.guaranteeCritical) {
    const subject = combo.consumesState.target === 'self' ? performer : target
    if (hasComboState(subject, combo.consumesState.state)) return true
  }

  if (combo.requiresPreviousTag && combo.requiresPreviousTag.guaranteeCritical) {
    const lastTag = getLastTag(performer)
    if (lastTag === combo.requiresPreviousTag.tag) return true
  }

  return false
}

export function getChainDamageMultiplier(performer, chainConfig) {
  if (!chainConfig || !performer) return 1
  const distinct = countDistinctTagsThisTurn(performer)
  const threshold = chainConfig.distinctTags || 3
  if (distinct >= threshold) {
    return 1 + (chainConfig.bonusPerStep || 0.1) * (distinct - threshold + 1)
  }
  return 1
}
