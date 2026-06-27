import { getSocketCharmById } from '../data/socketCharms.js'
import { getEffect } from './EffectRegistry.js'

/**
 * Resolves passive procs from equipped weapon/shield socket charms.
 *
 * Supported triggers:
 *   - on_hit          player lands an attack
 *   - on_defend       player is hit by an enemy
 *   - on_turn_start   player turn begins
 *   - on_battle_start battle begins
 *
 * Supported effect types:
 *   - heal            restore HP to the player
 *   - damage          deal flat damage to a target
 *   - thorns          deal flat damage to the attacker (source)
 *   - inflict_status  apply a status effect to a target
 *   - regen_stamina   restore player stamina
 */
export default class SocketProcSystem {
  constructor(player) {
    this.player = player
  }

  getProcs(trigger) {
    const procs = []
    for (const equipment of [this.player.weapon, this.player.shield]) {
      if (!equipment) continue
      const sockets = equipment.socketCharmIds || []
      for (const charmId of sockets) {
        if (!charmId) continue
        const charm = getSocketCharmById(charmId)
        if (!charm?.passiveProcs) continue
        for (const proc of charm.passiveProcs) {
          if (proc.trigger === trigger) procs.push({ charm, proc })
        }
      }
    }
    return procs
  }

  trigger(trigger, context = {}) {
    const procs = this.getProcs(trigger)
    for (const { charm, proc } of procs) {
      const chance = this.resolveChance(proc.chance)
      if (Math.random() >= chance) continue

      for (const effect of proc.effects || []) {
        this.applyEffect(effect, context, charm)
      }
    }
  }

  resolveChance(chance) {
    if (typeof chance === 'number') return Math.min(1, Math.max(0, chance))
    const base = chance?.base ?? 0
    const luckScaling = chance?.luckScaling ?? 0
    const cap = chance?.cap ?? 1
    const luck = this.player.luck || 0
    return Math.min(cap, Math.max(0, base + luck * luckScaling))
  }

  applyEffect(effect, context, charm) {
    const { scene, target, source } = context
    const log = (msg) => {
      if (scene?.addCombatLog) scene.addCombatLog(msg)
    }

    switch (effect.type) {
      case 'heal': {
        const amount = effect.value || 1
        const actual = this.player.heal(amount)
        if (actual > 0) log(`${charm.name} heals ${actual} HP.`)
        break
      }
      case 'damage': {
        if (!target?.takeDamage) break
        const amount = effect.value || 1
        const actual = target.takeDamage(amount)
        if (actual > 0) log(`${charm.name} deals ${actual} damage.`)
        break
      }
      case 'thorns': {
        if (!source?.takeDamage) break
        const amount = effect.value || 1
        const actual = source.takeDamage(amount)
        if (actual > 0) log(`${charm.name} thorns deal ${actual} damage.`)
        break
      }
      case 'inflict_status': {
        if (!target?.applyEffect) break
        const options = {}
        if (effect.snapshot !== undefined) options.snapshot = effect.snapshot
        const entry = target.applyEffect(effect.effectId, options)
        const name = entry ? (getEffect(entry.effectId)?.name || entry.effectId) : null
        if (name) log(`${charm.name} inflicts ${name}.`)
        break
      }
      case 'regen_stamina': {
        const amount = effect.value || 1
        this.player.stamina = Math.min(this.player.maxStamina, this.player.stamina + amount)
        log(`${charm.name} restores ${amount} stamina.`)
        break
      }
      default: {
        log(`${charm.name} procs (unhandled effect: ${effect.type}).`)
      }
    }
  }
}
