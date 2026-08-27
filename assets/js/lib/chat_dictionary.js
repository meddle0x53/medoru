/**
 * Chat Dictionary support for Medoru chat inputs.
 *
 * Provides two features when the user has enabled the dictionary for a chat:
 *   1. Autocomplete dropdown while typing `/d <key>` or `/dc <category> <key>`.
 *   2. Slash alias substitution on send: `/0`, `/1`, `/2`... `/t`, `/1@1` etc.
 */

const DICTIONARY_TRIGGER = /(^|\s)\/d(c)?(?:\s+)?(.*)$/
const ALIAS_PATTERN = /(^|\s)\/(\d+|t)(?:@(\d+))?(?=\s|$|[.,!?;])/g

export class ChatDictionary {
  constructor(textarea, opts = {}) {
    this.textarea = textarea
    this.hook = opts.hook || null
    this.wrapper =
      opts.wrapper ||
      (opts.wrapperSelector && document.querySelector(opts.wrapperSelector)) ||
      (this.textarea && this.textarea.closest("[data-dictionary-enabled]")) ||
      document.getElementById("chat-wrapper")
    this.dropdown = null
    this.selectedIndex = -1
    this.matches = []
    this.currentMatch = null
    this._keydownHandler = (e) => this.onKeyDown(e)
    this._inputHandler = () => this.onInput()
    this._blurHandler = () => this.hideDropdown()
    this._clickOutsideHandler = (e) => this.onClickOutside(e)

    this.textarea.addEventListener("keydown", this._keydownHandler)
    this.textarea.addEventListener("input", this._inputHandler)
    this.textarea.addEventListener("blur", this._blurHandler)
    document.addEventListener("click", this._clickOutsideHandler)
  }

  destroy() {
    this.hideDropdown()
    if (this.textarea) {
      this.textarea.removeEventListener("keydown", this._keydownHandler)
      this.textarea.removeEventListener("input", this._inputHandler)
      this.textarea.removeEventListener("blur", this._blurHandler)
    }
    document.removeEventListener("click", this._clickOutsideHandler)
  }

  isEnabled() {
    return this.wrapper?.dataset.dictionaryEnabled === "true"
  }

  getEntries() {
    try {
      return JSON.parse(this.wrapper?.dataset.dictionaryEntries || "[]")
    } catch (_e) {
      return []
    }
  }

  getAliases() {
    try {
      return JSON.parse(this.wrapper?.dataset.userAliases || "[]")
    } catch (_e) {
      return []
    }
  }

  getCurrentUserAlias() {
    return this.wrapper?.dataset.currentUserAlias || ""
  }

  onInput() {
    if (!this.isEnabled()) return
    this.updateDropdown()
  }

  onKeyDown(e) {
    if (!this.isEnabled()) return

    if (this.dropdown && this.matches.length > 0) {
      if (e.key === "ArrowDown") {
        e.preventDefault()
        this.selectedIndex = (this.selectedIndex + 1) % this.matches.length
        this.renderSelection()
        return
      }
      if (e.key === "ArrowUp") {
        e.preventDefault()
        this.selectedIndex =
          (this.selectedIndex - 1 + this.matches.length) % this.matches.length
        this.renderSelection()
        return
      }
      if (e.key === "Enter" || e.key === "Tab") {
        e.preventDefault()
        this.selectMatch(this.selectedIndex)
        return
      }
      if (e.key === "Escape") {
        this.hideDropdown()
        return
      }
    }
  }

  onClickOutside(e) {
    if (this.dropdown && !this.dropdown.contains(e.target) && e.target !== this.textarea) {
      this.hideDropdown()
    }
  }

  updateDropdown() {
    const cursor = this.textarea.selectionStart
    const textBefore = this.textarea.value.slice(0, cursor)
    const match = textBefore.match(DICTIONARY_TRIGGER)

    if (!match) {
      this.hideDropdown()
      return
    }

    const isCategorySearch = !!match[2]
    const typed = (match[3] || "").toLowerCase()
    const spaceIndex = typed.indexOf(" ")

    let category = null
    let search = typed

    if (isCategorySearch && spaceIndex > -1) {
      category = typed.slice(0, spaceIndex)
      search = typed.slice(spaceIndex + 1)
    } else if (isCategorySearch) {
      category = typed
      search = ""
    }

    if (search.length < 3) {
      this.hideDropdown()
      return
    }

    const entries = this.getEntries()
    let matches = entries.filter((entry) => {
      const key = (entry.key || "").toLowerCase()
      const entryCategory = (entry.category || "main").toLowerCase()

      if (category && entryCategory !== category) return false

      if (entry.match_mode === "substring") {
        return key.includes(search)
      }
      return key.startsWith(search)
    })

    matches = matches.slice(0, 8)

    if (matches.length === 0) {
      this.hideDropdown()
      return
    }

    this.matches = matches
    this.currentMatch = match
    this.selectedIndex = 0
    this.showDropdown()
  }

  showDropdown() {
    if (!this.dropdown) {
      this.dropdown = document.createElement("div")
      this.dropdown.className =
        "fixed z-50 bg-base-100 border border-base-300 rounded-lg shadow-xl max-h-60 overflow-y-auto w-72"
      this.dropdown.setAttribute("role", "listbox")
      document.body.appendChild(this.dropdown)
    }

    this.dropdown.innerHTML = ""
    this.matches.forEach((entry, index) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className =
        "w-full text-left px-3 py-2 text-sm hover:bg-base-200 focus:bg-base-200 focus:outline-none border-b border-base-200 last:border-b-0"
      item.setAttribute("role", "option")

      const keySpan = document.createElement("span")
      keySpan.className = "font-medium text-base-content block truncate"
      keySpan.textContent = entry.key || ""

      const valueSpan = document.createElement("span")
      valueSpan.className = "text-xs text-base-content/70 block truncate"
      valueSpan.textContent = entry.value || ""

      item.appendChild(keySpan)
      item.appendChild(valueSpan)
      item.addEventListener("mousedown", (e) => {
        e.preventDefault()
        this.selectMatch(index)
      })
      this.dropdown.appendChild(item)
    })

    this.renderSelection()
    this.positionDropdown()
  }

  renderSelection() {
    if (!this.dropdown) return
    Array.from(this.dropdown.children).forEach((child, i) => {
      const isSelected = i === this.selectedIndex
      child.classList.toggle("bg-base-200", isSelected)
      child.setAttribute("aria-selected", isSelected ? "true" : "false")
    })
  }

  positionDropdown() {
    if (!this.dropdown || !this.textarea) return
    const rect = this.textarea.getBoundingClientRect()
    this.dropdown.style.left = `${rect.left}px`
    this.dropdown.style.top = `${rect.top - Math.min(this.dropdown.offsetHeight + 8, 280)}px`
    this.dropdown.style.width = `${Math.min(rect.width, 320)}px`
  }

  selectMatch(index) {
    const entry = this.matches[index]
    if (!entry || !this.currentMatch) return

    const cursor = this.textarea.selectionStart
    const textBefore = this.textarea.value.slice(0, cursor)
    const textAfter = this.textarea.value.slice(cursor)
    const triggerStart = textBefore.length - this.currentMatch[0].length

    const replacement = entry.value || ""
    const leading = this.currentMatch[1] || ""

    const newValue =
      textBefore.slice(0, triggerStart) +
      leading +
      replacement +
      (textAfter.match(/^\s/) ? "" : " ") +
      textAfter.replace(/^\s+/, "")

    const newCursor = triggerStart + leading.length + replacement.length + 1

    this.textarea.value = newValue
    this.textarea.selectionStart = this.textarea.selectionEnd = newCursor
    this.textarea.focus()
    this.textarea.dispatchEvent(new Event("input"))
    this.hideDropdown()
  }

  hideDropdown() {
    if (this.dropdown) {
      this.dropdown.remove()
      this.dropdown = null
    }
    this.matches = []
    this.selectedIndex = -1
    this.currentMatch = null
  }

  substituteAliases(text) {
    if (!this.isEnabled()) return text

    const aliases = this.getAliases()
    const currentUserAlias = this.getCurrentUserAlias()

    return text.replace(ALIAS_PATTERN, (fullMatch, leading, ref, nicknameIndex) => {
      let replacement = null

      if (ref === "t") {
        replacement = this.resolveTeacherAlias(aliases, nicknameIndex)
      } else if (ref === "0") {
        replacement = currentUserAlias
      } else {
        const index = parseInt(ref, 10)
        replacement = this.resolveNumberedAlias(aliases, index, nicknameIndex)
      }

      if (replacement === null || replacement === "") return fullMatch
      return leading + replacement
    })
  }

  resolveNumberedAlias(aliases, index, nicknameIndex) {
    const alias = aliases.find((a) => a.ref_index === index)
    if (!alias) return null

    if (nicknameIndex) {
      const idx = parseInt(nicknameIndex, 10) - 1
      if (alias.nicknames && alias.nicknames[idx]) {
        return alias.nicknames[idx]
      }
      return alias.display_name
    }

    return alias.first_nickname || alias.display_name
  }

  resolveTeacherAlias(aliases, nicknameIndex) {
    const wrapper = this.wrapper
    if (!wrapper) return null

    const teacherId = wrapper.dataset.teacherUserId
    if (!teacherId) return null

    const alias = aliases.find((a) => String(a.user_id) === String(teacherId))
    if (!alias) return null

    if (nicknameIndex) {
      const idx = parseInt(nicknameIndex, 10) - 1
      if (alias.nicknames && alias.nicknames[idx]) {
        return alias.nicknames[idx]
      }
      return alias.display_name
    }

    return alias.first_nickname || alias.display_name
  }
}

/**
 * Replaces alias references in a message body before it is sent.
 * Useful when the hook wants to transform text without keeping state.
 */
export function substituteChatAliases(text, wrapper = null) {
  if (!wrapper) wrapper = document.getElementById("chat-wrapper")
  if (!wrapper || wrapper.dataset.dictionaryEnabled !== "true") return text

  const dict = new ChatDictionary(null, { wrapper })
  return dict.substituteAliases(text)
}
