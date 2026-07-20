import { GAME_CONFIG } from '../config.js'
import KanjiDrawingSystem from '../systems/KanjiDrawingSystem.js'
import { setupHighDPIWorld } from '../highDpi.js'

/**
 * Pre-run Kanji Library scene.
 *
 * Shows the full site kanji list with filters, sorting, and learned indicators.
 * Learned kanji can be clicked to open the drawing practice dialog (30s timer).
 */
export default class KanjiLibraryScene extends Phaser.Scene {
  constructor() {
    super({ key: 'KanjiLibraryScene' })
  }

  init(data) {
    this.player = data.player
    this.returnScene = data.returnScene || 'LoadoutScene'
    const userData = window.gameData || {}
    this.allKanji = userData.all_kanji || []
    this.learnedChars = new Set(userData.learned_kanji_chars || [])
    this.selectedChar = null
    this.practiceOpen = false
  }

  create() {
    setupHighDPIWorld(this)
    this.createBackground()
    this.createDOMOverlay()
    this.createPracticeDialog()
    this.render()
  }

  shutdown() {
    this.closePracticeDialog()
    if (this.kanjiDrawing) {
      this.kanjiDrawing.destroy()
      this.kanjiDrawing = null
    }
    if (this.practiceHeader && this.practiceHeader.parentNode) {
      this.practiceHeader.parentNode.removeChild(this.practiceHeader)
    }
    this.practiceHeader = null

    if (this._overlayResizeObserver) {
      this._overlayResizeObserver.disconnect()
      this._overlayResizeObserver = null
    } else if (this._updateOverlayScale) {
      window.removeEventListener('resize', this._updateOverlayScale)
    }

    if (this.overlayElement && this.overlayElement.parentNode) {
      this.overlayElement.parentNode.removeChild(this.overlayElement)
    }
    this.overlayElement = null
  }

  createBackground() {
    this.add.rectangle(GAME_CONFIG.width / 2, GAME_CONFIG.height / 2, GAME_CONFIG.width, GAME_CONFIG.height, 0x0f1525)
  }

  createDOMOverlay() {
    const wrapper = document.createElement('div')
    wrapper.id = 'kanji-library-overlay'
    wrapper.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: ${GAME_CONFIG.width}px;
      height: ${GAME_CONFIG.height}px;
      display: flex;
      flex-direction: column;
      color: #ecf0f1;
      font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
      z-index: 200;
      overflow: hidden;
      touch-action: pan-y;
    `

    // Scale the overlay so the 960×540 design fills the displayed game area.
    this.gameContainer = document.getElementById('game-container') || document.body
    this._updateOverlayScale = () => {
      const scaleX = (this.gameContainer.clientWidth || GAME_CONFIG.width) / GAME_CONFIG.width
      const scaleY = (this.gameContainer.clientHeight || GAME_CONFIG.height) / GAME_CONFIG.height
      wrapper.style.transform = `scale(${scaleX}, ${scaleY})`
      wrapper.style.transformOrigin = 'top left'
    }
    this._updateOverlayScale()

    if (typeof ResizeObserver !== 'undefined') {
      this._overlayResizeObserver = new ResizeObserver(this._updateOverlayScale)
      this._overlayResizeObserver.observe(this.gameContainer)
    } else {
      window.addEventListener('resize', this._updateOverlayScale)
    }

    wrapper.innerHTML = `
      <style>
        #kanji-library-overlay * { box-sizing: border-box; }
        .kco-header {
          padding: 16px 20px 8px;
          text-align: center;
          flex-shrink: 0;
        }
        .kco-header h1 {
          margin: 0;
          font-size: 24px;
          color: #f1c40f;
        }
        .kco-header p {
          margin: 4px 0 0;
          font-size: 12px;
          color: #bdc3c7;
        }
        .kco-toolbar {
          padding: 8px 20px;
          display: flex;
          flex-wrap: wrap;
          gap: 10px;
          align-items: center;
          justify-content: center;
          flex-shrink: 0;
        }
        .kco-search {
          width: 220px;
          padding: 8px 12px;
          border-radius: 8px;
          border: 1px solid #3498db;
          background: #1a1a2e;
          color: #ecf0f1;
          font-size: 13px;
          outline: none;
          touch-action: manipulation;
        }
        .kco-search::placeholder { color: #7f8c8d; }
        .kco-filters {
          display: flex;
          gap: 6px;
          flex-wrap: wrap;
        }
        .kco-filter {
          padding: 6px 12px;
          border-radius: 8px;
          border: 1px solid #7f8c8d;
          background: #1a1a2e;
          color: #bdc3c7;
          cursor: pointer;
          font-size: 12px;
          touch-action: manipulation;
        }
        .kco-filter.active {
          background: #3498db;
          border-color: #3498db;
          color: #ffffff;
        }
        .kco-sort {
          padding: 7px 10px;
          border-radius: 8px;
          border: 1px solid #7f8c8d;
          background: #1a1a2e;
          color: #ecf0f1;
          font-size: 12px;
          touch-action: manipulation;
        }
        .kco-stats {
          text-align: center;
          font-size: 12px;
          color: #bdc3c7;
          padding: 4px 0;
          flex-shrink: 0;
        }
        .kco-grid-wrap {
          flex: 1;
          overflow-y: auto;
          padding: 0 20px 12px;
        }
        .kco-grid {
          display: grid;
          grid-template-columns: repeat(12, 1fr);
          grid-auto-rows: 1fr;
          gap: 4px;
        }
        .kco-card {
          width: 100%;
          height: 100%;
          min-width: 0;
          min-height: 0;
          background: #1a1a2e;
          border: 1px solid #2c3e50;
          border-radius: 6px;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          position: relative;
          cursor: default;
          transition: border-color 0.15s, transform 0.15s;
          padding: 1px;
        }
        .kco-card.learned {
          border-color: #2ecc71;
          box-shadow: inset 0 0 0 1px #2ecc71;
          cursor: pointer;
        }
        .kco-card.learned:hover {
          transform: scale(1.05);
          border-color: #2ecc71;
        }
        .kco-card.selected {
          border-color: #f39c12;
          box-shadow: inset 0 0 0 1px #f39c12;
          cursor: pointer;
        }
        .kco-card.selectable {
          cursor: pointer;
        }
        .kco-char {
          font-size: 26px;
          color: #ffffff;
          line-height: 1;
        }
        .kco-meaning {
          font-size: 10px;
          color: #7f8c8d;
          text-align: center;
          padding: 0 1px;
          margin-top: 1px;
          line-height: 1.1;
          max-width: 100%;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }
        .kco-readings {
          font-size: 9px;
          color: #95a5a6;
          text-align: center;
          padding: 0 1px;
          margin-top: 1px;
          line-height: 1.1;
          max-width: 100%;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }
        .kco-badge {
          position: absolute;
          top: 2px;
          right: 2px;
          width: 8px;
          height: 8px;
          background: #2ecc71;
          border-radius: 50%;
        }
        .kco-empty {
          grid-column: 1 / -1;
          text-align: center;
          padding: 40px;
          color: #7f8c8d;
        }
        .kco-footer {
          padding: 12px 20px;
          text-align: center;
          flex-shrink: 0;
          border-top: 1px solid #1a1a2e;
        }
        @media (max-width: 600px) {
          .kco-grid { grid-template-columns: repeat(10, 1fr); }
        }
        @media (max-width: 400px) {
          .kco-grid { grid-template-columns: repeat(8, 1fr); }
        }
        .kco-continue {
          padding: 10px 36px;
          border-radius: 8px;
          border: none;
          background: #27ae60;
          color: #ffffff;
          font-size: 15px;
          font-weight: bold;
          cursor: pointer;
          touch-action: manipulation;
        }
        .kco-continue:hover { background: #2ecc71; }
      </style>
      <div class="kco-header">
        <h1>Kanji Library</h1>
        <p>Review your learned kanji and the journey ahead</p>
      </div>
      <div class="kco-toolbar">
        <input type="text" class="kco-search" id="kco-search" placeholder="Search character, meaning, reading..." autocomplete="off" autocorrect="off" spellcheck="false">
        <div class="kco-filters" id="kco-filters">
          <button class="kco-filter active" data-level="all">All</button>
          <button class="kco-filter" data-level="5">N5</button>
          <button class="kco-filter" data-level="4">N4</button>
          <button class="kco-filter" data-level="3">N3</button>
          <button class="kco-filter" data-level="2">N2</button>
          <button class="kco-filter" data-level="1">N1</button>
        </div>
        <select class="kco-sort" id="kco-sort">
          <option value="frequency-asc">Frequency (common first)</option>
          <option value="frequency-desc">Frequency (rare first)</option>
          <option value="jlpt-asc">JLPT (N5 → N1)</option>
          <option value="jlpt-desc">JLPT (N1 → N5)</option>
          <option value="school-asc">School Grade (1 → 6)</option>
          <option value="character-asc">Character</option>
        </select>
      </div>
      <div class="kco-stats" id="kco-stats"></div>
      <div class="kco-grid-wrap">
        <div class="kco-grid" id="kco-grid"></div>
      </div>
      <div class="kco-footer">
        <button class="kco-continue" id="kco-continue">Continue</button>
      </div>
    `

    const container = document.getElementById('game-container') || document.body
    container.appendChild(wrapper)
    this.overlayElement = wrapper

    // Event listeners
    this.searchInput = wrapper.querySelector('#kco-search')
    this.searchInput.addEventListener('input', () => this.render())

    this.filterButtons = wrapper.querySelectorAll('.kco-filter')
    this.filterButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        this.filterButtons.forEach(b => b.classList.remove('active'))
        btn.classList.add('active')
        this.currentLevel = btn.dataset.level
        this.render()
      })
    })
    this.currentLevel = 'all'

    this.sortSelect = wrapper.querySelector('#kco-sort')
    this.sortSelect.addEventListener('change', () => this.render())

    wrapper.querySelector('#kco-continue').addEventListener('click', () => {
      this.closePracticeDialog()
      if (this.kanjiDrawing) {
        this.kanjiDrawing.destroy()
        this.kanjiDrawing = null
      }
      if (this.practiceHeader && this.practiceHeader.parentNode) {
        this.practiceHeader.parentNode.removeChild(this.practiceHeader)
      }
      this.practiceHeader = null

      const focusKanji = this.computeFocusKanji()
      this.player.loadout.focusKanji = focusKanji ? focusKanji.character : null
      this.player.loadout.focusKanjiData = focusKanji
      this.player.saveLoadout()

      if (this.overlayElement && this.overlayElement.parentNode) {
        this.overlayElement.parentNode.removeChild(this.overlayElement)
      }
      this.overlayElement = null

      if (this.returnScene === 'MapScene') {
        this.scene.start('MapScene', { player: this.player })
      } else {
        this.scene.start('LoadoutScene', { player: this.player, mode: 'map', returnScene: 'MapScene' })
      }
    })

    this.gridElement = wrapper.querySelector('#kco-grid')
    this.statsElement = wrapper.querySelector('#kco-stats')
  }

  createPracticeDialog() {
    const size = 320
    const x = GAME_CONFIG.width / 2
    const y = GAME_CONFIG.height / 2

    // Use the same horizontal offset as the battle scene so the kanji is centered.
    this.kanjiDrawing = new KanjiDrawingSystem(this, x, y, size, {
      timeLimit: 30000,
      offsetXPercent: -0.038,
    })
    this.kanjiDrawing.hide()

    // Ensure the drawing canvas sits above the library overlay (z-index 200).
    this.kanjiDrawing.canvas.style.zIndex = '300'
    this.kanjiDrawing.hintText.style.zIndex = '301'
    this.kanjiDrawing.infoText.style.zIndex = '301'

    const header = document.createElement('div')
    header.id = 'kco-practice-header'
    header.style.cssText = `
      position: absolute;
      left: ${x - size / 2}px;
      top: ${y - size / 2 - 54}px;
      width: ${size}px;
      height: 46px;
      display: none;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      padding: 0 12px;
      background: rgba(26, 26, 46, 0.98);
      border: 1px solid #3498db;
      border-radius: 12px 12px 0 0;
      color: #ecf0f1;
      font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
      z-index: 302;
      box-shadow: 0 -4px 24px rgba(0,0,0,0.4);
    `

    header.innerHTML = `
      <div id="kco-practice-title" style="font-size: 16px; font-weight: bold; display: flex; align-items: center; gap: 8px;">
        <span id="kco-practice-char" style="font-size: 22px; color: #f1c40f;"></span>
        <span id="kco-practice-meaning" style="font-size: 13px; color: #bdc3c7;"></span>
      </div>
      <button id="kco-practice-close" style="
        background: #7f8c8d;
        border: none;
        border-radius: 6px;
        color: #fff;
        font-size: 12px;
        font-weight: bold;
        padding: 6px 12px;
        cursor: pointer;
      ">Close</button>
    `

    const wrapper = document.getElementById('game-wrapper') || document.getElementById('game-container') || document.body
    wrapper.appendChild(header)
    this.practiceHeader = header

    header.querySelector('#kco-practice-close').addEventListener('click', () => this.closePracticeDialog())
  }

  openPracticeDialog(kanji) {
    if (!kanji || !kanji.stroke_data || !(kanji.stroke_data.strokes || []).length) {
      this.showPracticeStatus('No stroke data available for this kanji.')
      return
    }

    this.practiceOpen = true
    const charEl = this.practiceHeader.querySelector('#kco-practice-char')
    const meaningEl = this.practiceHeader.querySelector('#kco-practice-meaning')
    charEl.textContent = kanji.character
    meaningEl.textContent = (kanji.meanings || []).join(', ')
    this.practiceHeader.style.display = 'flex'

    const hint = `Draw ${kanji.character} in the correct stroke order`
    this.kanjiDrawing.start(kanji.stroke_data, hint, {
      onComplete: (result) => {
        const status = result.completed
          ? `Completed! Wrong strokes: ${result.wrongStrokes || 0}`
          : `Time's up! Wrong strokes: ${result.wrongStrokes || 0}`
        this.updatePracticeTitle(status)
        setTimeout(() => this.closePracticeDialog(), 1500)
      },
      onWrongStroke: (result) => {
        this.updatePracticeTitle(`Wrong stroke! (${result.count})`)
      },
    })
  }

  closePracticeDialog() {
    this.practiceOpen = false
    if (this.kanjiDrawing) {
      this.kanjiDrawing.hide()
    }
    if (this.practiceHeader) {
      this.practiceHeader.style.display = 'none'
    }
  }

  updatePracticeTitle(text) {
    const meaningEl = this.practiceHeader.querySelector('#kco-practice-meaning')
    if (meaningEl) meaningEl.textContent = text
  }

  computeFocusKanji() {
    // If a non-learned kanji is selected, use it as the focus lesson.
    if (this.selectedChar && !this.learnedChars.has(this.selectedChar)) {
      return this.allKanji.find(k => k.character === this.selectedChar) || null
    }

    // Otherwise auto-select the first non-learned kanji by JLPT level (N5 → N1).
    for (const level of [5, 4, 3, 2, 1]) {
      const found = this.allKanji.find(k => (k.jlpt_level || 0) === level && !this.learnedChars.has(k.character))
      if (found) return found
    }

    return null
  }

  showPracticeStatus(text) {
    this.statsElement.textContent = text
    setTimeout(() => this.render(), 2000)
  }

  getFilteredAndSortedKanji() {
    const query = (this.searchInput?.value || '').trim().toLowerCase()

    let list = this.allKanji.filter(k => {
      if (this.currentLevel !== 'all') {
        const level = Number(this.currentLevel)
        if ((k.jlpt_level || 0) !== level) return false
      }
      if (!query) return true
      if (k.character === query) return true
      const meanings = (k.meanings || []).join(' ').toLowerCase()
      if (meanings.includes(query)) return true
      const readings = (k.readings || []).join(' ').toLowerCase()
      if (readings.includes(query)) return true
      return false
    })

    const sortValue = this.sortSelect?.value || 'frequency-asc'
    list.sort((a, b) => {
      switch (sortValue) {
        case 'frequency-asc':
          return (a.frequency || 9999) - (b.frequency || 9999)
        case 'frequency-desc':
          return (b.frequency || 9999) - (a.frequency || 9999)
        case 'jlpt-asc':
          return (a.jlpt_level || 99) - (b.jlpt_level || 99)
        case 'jlpt-desc':
          return (b.jlpt_level || 99) - (a.jlpt_level || 99)
        case 'school-asc':
          return (a.school_level || 99) - (b.school_level || 99)
        case 'character-asc':
        default:
          return a.character.localeCompare(b.character, 'ja')
      }
    })

    return list
  }

  render() {
    if (!this.gridElement) return

    const list = this.getFilteredAndSortedKanji()
    const learnedCount = list.filter(k => this.learnedChars.has(k.character)).length

    this.statsElement.textContent =
      `${list.length} characters · ${learnedCount} learned · ${this.allKanji.length} total`

    this.gridElement.innerHTML = ''

    if (list.length === 0) {
      const empty = document.createElement('div')
      empty.className = 'kco-empty'
      empty.textContent = 'No kanji match your filters.'
      this.gridElement.appendChild(empty)
      return
    }

    const fragment = document.createDocumentFragment()
    for (const k of list) {
      const card = document.createElement('div')
      const learned = this.learnedChars.has(k.character)
      const hasStrokes = k.stroke_data && (k.stroke_data.strokes || []).length > 0
      card.className = `kco-card${learned ? ' learned' : ''}`
      card.title = `${k.character}\n${(k.meanings || []).join(', ')}\n${(k.readings || []).join(', ')}`.trim()

      const char = document.createElement('div')
      char.className = 'kco-char'
      char.textContent = k.character
      card.appendChild(char)

      const meaning = document.createElement('div')
      meaning.className = 'kco-meaning'
      meaning.textContent = (k.meanings || [])[0] || ''
      card.appendChild(meaning)

      const on = (k.on_readings || [])[0]
      const kun = (k.kun_readings || [])[0]
      if (on || kun) {
        const readings = document.createElement('div')
        readings.className = 'kco-readings'
        const parts = []
        if (on) parts.push(`On: ${on}`)
        if (kun) parts.push(`Kun: ${kun}`)
        readings.textContent = parts.join(' ')
        card.appendChild(readings)
      }

      if (learned) {
        const badge = document.createElement('div')
        badge.className = 'kco-badge'
        card.appendChild(badge)
      }

      if (hasStrokes) {
        const selected = this.selectedChar === k.character
        if (selected) card.classList.add('selected')
        if (!learned) card.classList.add('selectable')

        card.addEventListener('click', () => {
          if (learned) {
            this.openPracticeDialog(k)
          } else if (this.selectedChar === k.character) {
            this.openPracticeDialog(k)
          } else {
            this.selectedChar = k.character
            this.render()
          }
        })
      }

      fragment.appendChild(card)
    }
    this.gridElement.appendChild(fragment)
  }
}
