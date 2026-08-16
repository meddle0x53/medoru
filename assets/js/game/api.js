/**
 * API layer for communicating with Phoenix backend.
 */
const API_BASE = '/api/game'

export async function fetchUserData() {
  try {
    const resp = await fetch(`${API_BASE}/user-data`, {
      headers: { 'Accept': 'application/json' },
      credentials: 'same-origin',
    })
    if (!resp.ok) throw new Error('Failed to fetch user data')
    return await resp.json()
  } catch (e) {
    console.warn('Game API error (using defaults):', e)
    return null
  }
}

export async function sendRunResult(data) {
  try {
    const resp = await fetch(`${API_BASE}/run-result`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': getCsrfToken(),
      },
      credentials: 'same-origin',
      body: JSON.stringify(data),
    })
    if (!resp.ok) throw new Error('Failed to send run result')
    return await resp.json()
  } catch (e) {
    console.warn('Run result API error:', e)
    return null
  }
}

function getCsrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta ? meta.getAttribute('content') : ''
}

export function getWindowGameData() {
  if (typeof window !== 'undefined' && window.gameData) {
    return window.gameData
  }
  return null
}

export async function fetchKanjiStrokes(character) {
  try {
    const resp = await fetch(`/api/v1/kanji/character/${encodeURIComponent(character)}`, {
      headers: { 'Accept': 'application/json' },
      credentials: 'same-origin',
    })
    if (!resp.ok) throw new Error('Failed to fetch kanji strokes')
    const data = await resp.json()
    return data.stroke_data || null
  } catch (e) {
    console.warn('Kanji stroke fetch error:', e)
    return null
  }
}
