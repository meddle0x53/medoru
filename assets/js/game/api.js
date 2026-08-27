/**
 * API layer for communicating with Phoenix backend.
 */
const API_BASE = '/api/game'

async function parseResponse(resp) {
  const text = await resp.text()
  try {
    return JSON.parse(text)
  } catch (_) {
    return { raw: text }
  }
}

export async function fetchUserData() {
  try {
    const resp = await fetch(`${API_BASE}/user-data`, {
      headers: { 'Accept': 'application/json' },
      credentials: 'same-origin',
    })
    if (!resp.ok) {
      const body = await parseResponse(resp)
      console.warn('Game API user-data error:', resp.status, body)
      throw new Error(`Failed to fetch user data (${resp.status})`)
    }
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
      },
      credentials: 'same-origin',
      body: JSON.stringify(data),
    })
    if (!resp.ok) {
      const body = await parseResponse(resp)
      console.warn('Run result API error:', resp.status, body, data)
      throw new Error(`Failed to send run result (${resp.status})`)
    }
    return await resp.json()
  } catch (e) {
    console.warn('Run result API error:', e, data)
    return null
  }
}

export async function fetchSaveData() {
  try {
    const resp = await fetch(`${API_BASE}/save`, {
      headers: { 'Accept': 'application/json' },
      credentials: 'same-origin',
    })
    if (!resp.ok) {
      const body = await parseResponse(resp)
      console.warn('Game save fetch error:', resp.status, body)
      return null
    }
    return await resp.json()
  } catch (e) {
    console.warn('Game save fetch error:', e)
    return null
  }
}

export async function uploadSaveData(saveData) {
  try {
    const resp = await fetch(`${API_BASE}/save`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      credentials: 'same-origin',
      body: JSON.stringify({ save_data: saveData, version: saveData.version || 1 }),
    })
    if (!resp.ok) {
      const body = await parseResponse(resp)
      console.warn('Game save upload error:', resp.status, body)
      return { ok: false, error: body }
    }
    return { ok: true, data: await resp.json() }
  } catch (e) {
    console.warn('Game save upload error:', e)
    return { ok: false, error: e.message }
  }
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
    if (!resp.ok) {
      const body = await parseResponse(resp)
      console.warn('Kanji stroke API error:', resp.status, body)
      throw new Error(`Failed to fetch kanji strokes (${resp.status})`)
    }
    const data = await resp.json()
    return data.stroke_data || null
  } catch (e) {
    console.warn('Kanji stroke fetch error:', e)
    return null
  }
}
