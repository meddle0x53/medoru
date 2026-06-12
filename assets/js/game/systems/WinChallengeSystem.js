import KanjiDrawingSystem from './KanjiDrawingSystem.js'
import WordChallengeSystem from './WordChallengeSystem.js'

/**
 * Manages the optional post-battle kanji + word challenge.
 *
 * Flow:
 *   1. Pick the learned kanji with the lowest stroke count.
 *   2. Player draws it.
 *   3. If successful, pick a learned word and type its reading.
 *   4. Final callback receives { success, kanjiPassed, wordPassed, multiplier }.
 */
export default class WinChallengeSystem {
  constructor(scene, player) {
    this.scene = scene
    this.player = player
    this.kanjiDrawing = new KanjiDrawingSystem(
      scene,
      scene.scale.width / 2,
      scene.scale.height / 2,
      320,
      { offsetXPercent: -0.038 }
    )
    this.wordChallenge = new WordChallengeSystem(scene, {
      title: 'Word Challenge',
      promptForMeaning: 'Type the meaning of this word:',
      timeLimit: 8000,
      hangOnWrong: 5000,
    })
  }

  destroy() {
    this.kanjiDrawing.destroy()
    this.wordChallenge.destroy()
  }

  // ---------- Content selection ----------

  pickKanji() {
    const list = this.player.kanjiList || []
    if (list.length === 0) return null
    const sorted = [...list].sort((a, b) => (a.stroke_count || 999) - (b.stroke_count || 999))
    return sorted[0]
  }

  pickWord() {
    const list = this.player.wordList || []
    if (list.length === 0) return null
    return list[Math.floor(Math.random() * list.length)]
  }

  // ---------- Orchestration ----------

  run(onComplete) {
    const kanji = this.pickKanji()
    if (!kanji) {
      onComplete({ success: true, kanjiPassed: true, wordPassed: true, multiplier: this.getMultiplier(true) })
      return
    }

    this.startKanjiChallenge(kanji, (kanjiPassed) => {
      if (!kanjiPassed) {
        onComplete({ success: false, kanjiPassed: false, wordPassed: false, multiplier: this.getMultiplier(false) })
        return
      }

      const word = this.pickWord()
      if (!word) {
        onComplete({ success: true, kanjiPassed: true, wordPassed: true, multiplier: this.getMultiplier(true) })
        return
      }

      this.wordChallenge.start(word, {
        promptType: 'meaning',
        onComplete: (result) => {
          const success = result.success
          onComplete({
            success,
            kanjiPassed: true,
            wordPassed: success,
            multiplier: this.getMultiplier(success),
          })
        },
      })
    })
  }

  getMultiplier(success) {
    const luck = Math.max(0, Math.min(100, this.player.luck || 0))
    const luckFactor = luck / 100
    if (success) {
      return 1.5 + luckFactor
    }
    return 1.0 - luckFactor * 0.5
  }

  // ---------- Kanji drawing ----------

  startKanjiChallenge(kanji, onComplete) {
    const hint = `Draw: ${kanji.meanings?.[0] || kanji.character}`
    this.kanjiDrawing.start(kanji.stroke_data || { strokes: [] }, hint, {
      onComplete: (result) => {
        onComplete(result.completed)
      },
    })
  }
}
