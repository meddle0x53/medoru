import { getWindowGameData } from '../api.js'
import { GAME_CONFIG, COLORS } from '../config.js'

/**
 * Data-driven kanji challenge resolver for weapon attacks.
 *
 * Each ability can declare a `kanjiChallenge` block in its JSON definition:
 *
 *   "kanjiChallenge": {
 *     "skipChance": 0.2,
 *     "focusOverrideChance": 0.2,
 *     "failThreshold": "halfUp",
 *     "powerBonusTiers": [
 *       { "minStrokes": 0, "bonus": 1 },
 *       { "minStrokes": 4, "bonus": 2 },
 *       { "minStrokes": 8, "bonus": 3 }
 *     ],
 *     "outcomes": {
 *       "skipped": { "challengeResult": "success", "applyPowerBonus": false },
 *       "fallback": { "challengeResult": "success", "applyPowerBonus": false },
 *       "pass": { "challengeResult": "success", "applyPowerBonus": true },
 *       "fail": { "challengeResult": "fail", "applyPowerBonus": false }
 *     }
 *   }
 *
 * Outcomes may also declare `effectChanceOverrides` to temporarily change the
 * chance of an ability's status effects for that single use.
 */
export default class WeaponKanjiChallengeSystem {
  constructor(scene) {
    this.scene = scene
  }

  /**
   * Run the kanji challenge for a weapon attack ability.
   * Calls `onComplete({ challengeResult })` when finished.
   */
  resolve(skill, onComplete) {
    const cfg = skill?.kanjiChallenge
    if (!cfg) {
      onComplete({ challengeResult: 'success' })
      return
    }

    // Skip path: strike immediately with no drawing challenge.
    const skipChance = cfg.skipChance ?? 0
    if (skipChance > 0 && Math.random() < skipChance) {
      this._finish(skill, 'skipped', cfg, onComplete)
      return
    }

    const selectedKanjiData = this._selectKanji(skill, cfg)

    // Fallback path: no usable stroke data available.
    if (!selectedKanjiData || !selectedKanjiData.stroke_data?.strokes?.length) {
      this._finish(skill, 'fallback', cfg, onComplete)
      return
    }

    const strokeData = selectedKanjiData.stroke_data
    const totalStrokes = strokeData.strokes.length
    const failThreshold = this._resolveFailThreshold(totalStrokes, cfg.failThreshold)
    const powerBonus = this._resolvePowerBonus(totalStrokes, cfg.powerBonusTiers)
    const hint = this._buildHint(skill)

    this.scene.startKanjiDrawingChallenge(strokeData, hint, {
      onComplete: (result) => {
        const passed = result.completed && result.wrongStrokes < failThreshold
        const kanjiChar = selectedKanjiData.character

        if (passed) {
          this.scene.player.setBasePowerBonus(powerBonus)
          this.scene.addCombatLog(`${kanjiChar} drawn! (+${powerBonus} power)`)
          this._finish(skill, 'pass', cfg, onComplete)
        } else {
          this.scene.player.setBasePowerBonus(0)
          this.scene.addCombatLog(`${kanjiChar} failed! No power bonus.`)
          this._finish(skill, 'fail', cfg, onComplete)
        }
      },
      onWrongStroke: ({ count }) => {
        this.scene.spawnFloatingText(
          GAME_CONFIG.width / 2,
          GAME_CONFIG.height / 2 - 180,
          `Wrong stroke! (${count})`,
          COLORS.danger
        )
      },
    }, selectedKanjiData, { allowFocusOverride: false })
  }

  _selectKanji(skill, cfg) {
    const pool = skill.kanjiPool || []
    const focusOverrideChance = cfg.focusOverrideChance ?? 0
    const focusKanjiData = this.scene.player.loadout.focusKanjiData

    // Focus override: draw the current focus kanji instead of the pool.
    if (focusKanjiData && focusOverrideChance > 0 && Math.random() < focusOverrideChance && focusKanjiData.stroke_data?.strokes?.length > 0) {
      return focusKanjiData
    }

    if (pool.length === 0) return null

    const allKanji = getWindowGameData()?.all_kanji || []
    const candidates = pool
      .map(char => {
        const fromList = this.scene.player.kanjiList.find(k => k.character === char)
        if (fromList?.stroke_data?.strokes?.length > 0) return fromList
        const fromAll = allKanji.find(k => k.character === char)
        if (fromAll?.stroke_data?.strokes?.length > 0) return fromAll
        return null
      })
      .filter(Boolean)

    if (candidates.length === 0) return null
    return candidates[Math.floor(Math.random() * candidates.length)]
  }

  _finish(skill, outcomeKey, cfg, onComplete) {
    this.scene.challengeActive = false
    this.scene.setSkillButtonsEnabled(true)
    this.scene.endTurnBtn.setVisible(true)

    const outcome = cfg.outcomes?.[outcomeKey]

    if (outcome?.log) {
      this.scene.addCombatLog(outcome.log)
    } else if (outcomeKey === 'skipped') {
      this.scene.addCombatLog(`${skill.name} strikes cleanly! No kanji challenge.`)
    }

    if (outcome?.effectChanceOverrides) {
      this.scene.player.pendingEffectChanceOverrides = outcome.effectChanceOverrides
    }

    onComplete({ challengeResult: outcome?.challengeResult || 'success' })
  }

  _resolveFailThreshold(totalStrokes, failThreshold) {
    if (failThreshold === 'halfUp') return Math.ceil(totalStrokes / 2)
    if (typeof failThreshold === 'number') return failThreshold
    return Math.ceil(totalStrokes / 2)
  }

  _resolvePowerBonus(totalStrokes, tiers) {
    if (!Array.isArray(tiers) || tiers.length === 0) return 0
    let bonus = 0
    for (const tier of tiers) {
      if (totalStrokes >= tier.minStrokes) bonus = tier.bonus
    }
    return bonus
  }

  _buildHint(skill) {
    const gameData = getWindowGameData()
    const userLevel = gameData?.level || 1
    const weaponHints = this.scene.player.weapon?.moveHints

    if (userLevel >= 10) {
      return weaponHints?.[skill.id]?.ja || skill.moveHint?.ja || skill.moveHint?.en || 'Strike!'
    }
    return weaponHints?.[skill.id]?.en || skill.moveHint?.en || 'Strike!'
  }
}
