/**
 * End-to-End Encryption for Medoru Chat (Group-capable).
 *
 * Architecture:
 * - Each user has an RSA-OAEP 2048 key pair (private in localStorage, public on server)
 * - Each conversation has a shared AES-256-GCM key
 * - The conversation key is encrypted with each participant's RSA public key
 * - Messages are encrypted/decrypted with the conversation AES key
 */

function getPrivKeyStorage(userId) { return `medoru_chat_privkey_v2_${userId}` }
function getPubKeyStorage(userId) { return `medoru_chat_pubkey_v2_${userId}` }

// --- Base64 helpers ---
function ab2b64(buffer) {
  const bytes = new Uint8Array(buffer)
  let binary = ""
  for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i])
  return btoa(binary)
}

function b642ab(base64) {
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

// --- User key pair ---
async function generateUserKeyPair() {
  return crypto.subtle.generateKey(
    { name: "RSA-OAEP", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["encrypt", "decrypt"]
  )
}

async function exportPublicKey(keyPair) {
  return ab2b64(await crypto.subtle.exportKey("spki", keyPair.publicKey))
}

async function exportPrivateKey(keyPair) {
  return ab2b64(await crypto.subtle.exportKey("pkcs8", keyPair.privateKey))
}

async function importPrivateKey(b64) {
  return crypto.subtle.importKey(
    "pkcs8",
    b642ab(b64),
    { name: "RSA-OAEP", hash: "SHA-256" },
    false,
    ["decrypt"]
  )
}

async function importPublicKey(b64) {
  return crypto.subtle.importKey(
    "spki",
    b642ab(b64),
    { name: "RSA-OAEP", hash: "SHA-256" },
    false,
    ["encrypt"]
  )
}

// --- Conversation key ---
async function generateConversationKey() {
  return crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, true, ["encrypt", "decrypt"])
}

async function exportConversationKey(aesKey) {
  return ab2b64(await crypto.subtle.exportKey("raw", aesKey))
}

async function importConversationKey(b64) {
  return crypto.subtle.importKey("raw", b642ab(b64), { name: "AES-GCM" }, false, ["encrypt", "decrypt"])
}

async function encryptConversationKey(aesKey, publicKeyB64) {
  const pubKey = await importPublicKey(publicKeyB64)
  const raw = await crypto.subtle.exportKey("raw", aesKey)
  const encrypted = await crypto.subtle.encrypt({ name: "RSA-OAEP" }, pubKey, raw)
  return ab2b64(encrypted)
}

async function decryptConversationKey(encryptedKeyB64, privateKey) {
  const encrypted = b642ab(encryptedKeyB64)
  const raw = await crypto.subtle.decrypt({ name: "RSA-OAEP" }, privateKey, encrypted)
  // Import as extractable so the key can be re-exported and re-encrypted for other users
  return crypto.subtle.importKey("raw", raw, { name: "AES-GCM" }, true, ["encrypt", "decrypt"])
}

// --- Message encryption ---
async function encryptMessage(aesKey, text) {
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const data = new TextEncoder().encode(text)
  const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, aesKey, data)
  return { ciphertext: ab2b64(ct), iv: ab2b64(iv) }
}

async function decryptMessage(aesKey, ciphertextB64, ivB64) {
  const iv = new Uint8Array(b642ab(ivB64))
  const ct = b642ab(ciphertextB64)
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, aesKey, ct)
  return new TextDecoder().decode(plain)
}

// --- Key fingerprinting ---
export async function keyFingerprint(publicKeyB64) {
  const spki = b642ab(publicKeyB64)
  const hash = await crypto.subtle.digest("SHA-256", spki)
  const hex = Array.from(new Uint8Array(hash))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("")
  return hex.slice(0, 16)
}

function getFingerprintStorage(userId) { return `medoru_chat_keyfp_v2_${userId}` }

// --- Global crypto state ---
export const CryptoState = {
  privateKey: null,
  publicKeyB64: null,
  keyFingerprint: null,
  conversationKeys: new Map(), // conversation_id -> AES key
  ready: false,

  async init(userId) {
    if (!window.crypto || !window.crypto.subtle) {
      console.error("[ChatCrypto] WebCrypto not available")
      return { ready: false }
    }

    if (!userId) {
      console.error("[ChatCrypto] No userId provided for key isolation")
      return { ready: false }
    }

    this.userId = userId
    const privStore = getPrivKeyStorage(userId)
    const pubStore = getPubKeyStorage(userId)
    const fpStore = getFingerprintStorage(userId)

    let privB64 = localStorage.getItem(privStore)
    let pubB64 = localStorage.getItem(pubStore)
    let fp = localStorage.getItem(fpStore)
    let migrated = false

    // Always prefer the legacy key if it still exists — it can decrypt existing messages.
    // A new key may have been auto-generated before this migration ran; the old key
    // should take precedence so the user doesn't lose access to historical chats.
    const oldPriv = localStorage.getItem("medoru_chat_privkey_v2")
    const oldPub = localStorage.getItem("medoru_chat_pubkey_v2")
    if (oldPriv && oldPub) {
      console.log("[ChatCrypto] Migrating legacy keys to user-isolated storage")
      localStorage.setItem(privStore, oldPriv)
      localStorage.setItem(pubStore, oldPub)
      localStorage.removeItem("medoru_chat_privkey_v2")
      localStorage.removeItem("medoru_chat_pubkey_v2")
      privB64 = oldPriv
      pubB64 = oldPub
      migrated = true
    }

    if (!privB64 || !pubB64) {
      const kp = await generateUserKeyPair()
      privB64 = await exportPrivateKey(kp)
      pubB64 = await exportPublicKey(kp)
      fp = await keyFingerprint(pubB64)
      localStorage.setItem(privStore, privB64)
      localStorage.setItem(pubStore, pubB64)
      localStorage.setItem(fpStore, fp)
      this.privateKey = kp.privateKey
      this.publicKeyB64 = pubB64
      this.keyFingerprint = fp
      this.ready = true
      return { ready: true, newKey: true, publicKey: pubB64 }
    }

    // If we have keys but no stored fingerprint (e.g. existing user before
    // this deployment), compute and store the fingerprint now.
    if (!fp) {
      fp = await keyFingerprint(pubB64)
      localStorage.setItem(fpStore, fp)
    }

    this.privateKey = await importPrivateKey(privB64)
    this.publicKeyB64 = pubB64
    this.keyFingerprint = fp
    this.ready = true
    return { ready: true, newKey: false, migrated: migrated, publicKey: pubB64 }
  },

  async getConversationKey(convId, encryptedKeyB64) {
    if (!this.ready || !this.privateKey) throw new Error("Crypto not initialized")

    const cached = this.conversationKeys.get(convId)
    if (cached) return cached

    const key = await decryptConversationKey(encryptedKeyB64, this.privateKey)
    this.conversationKeys.set(convId, key)
    return key
  },

  async setConversationKey(convId, aesKey) {
    this.conversationKeys.set(convId, aesKey)
  },

  async createConversationKeys(participantPublicKeys) {
    if (!this.ready) throw new Error("Crypto not initialized")
    const aesKey = await generateConversationKey()
    const encryptedKeys = {}

    for (const [userId, pubKeys] of Object.entries(participantPublicKeys)) {
      // Detect multi-key format: array of keys vs single string
      const keyList = Array.isArray(pubKeys) ? pubKeys : [pubKeys]

      const entries = []
      for (const pubKeyB64 of keyList) {
        const encrypted = await encryptConversationKey(aesKey, pubKeyB64)
        const fingerprint = await keyFingerprint(pubKeyB64)
        entries.push({ fingerprint, encrypted_key: encrypted })
      }

      // If only one entry and we're in legacy mode, send flat string for compat
      if (entries.length === 1 && !Array.isArray(pubKeys)) {
        encryptedKeys[userId] = entries[0].encrypted_key
      } else {
        encryptedKeys[userId] = entries
      }
    }
    return { aesKey, encryptedKeys }
  },

  async encrypt(convId, text) {
    const aesKey = this.conversationKeys.get(convId)
    if (!aesKey) throw new Error("No conversation key for " + convId)
    return encryptMessage(aesKey, text)
  },

  async decrypt(convId, ciphertextB64, ivB64) {
    const aesKey = this.conversationKeys.get(convId)
    if (!aesKey) throw new Error("No conversation key for " + convId)
    return decryptMessage(aesKey, ciphertextB64, ivB64)
  }
}

// --- Hook: ChatCrypto ---
const ChatCrypto = {
  async mounted() {
    this.convId = this.el.dataset.conversationId

    // Get current user ID from data attribute for key isolation
    const currentUserId = this.el.dataset.currentUserId

    // Initialize user key pair
    const result = await CryptoState.init(currentUserId)
    this._needsRegistration = (result.newKey || result.migrated) && result.publicKey ? result.publicKey : null

    if (this._needsRegistration) {
      // Try immediately; if socket isn't connected yet, updated() will retry
      this.pushEvent("register_public_key", { public_key: this._needsRegistration })
    }

    // Detect multi-key mode: server sends v2 data attributes
    const pubKeysV2Json = this.el.dataset.participantPublicKeysV2
    const encryptedKeysV2Json = this.el.dataset.encryptedKeysV2
    this.multiKeyMode = !!(pubKeysV2Json && encryptedKeysV2Json)

    if (this.multiKeyMode) {
      this.participantPublicKeysV2 = JSON.parse(pubKeysV2Json)
      this.encryptedKeysV2 = JSON.parse(encryptedKeysV2Json)
    }

    // Parse participant public keys from data attribute (legacy or v2)
    const pubKeysJson = this.el.dataset.participantPublicKeys
    this.participantPublicKeys = pubKeysJson ? JSON.parse(pubKeysJson) : {}

    if (this.multiKeyMode) {
      // Multi-key mode: stale check compares against ALL server keys.
      // Only report mismatch if our fingerprint is not in the server's list.
      const myFp = CryptoState.keyFingerprint
      const serverKeys = this.participantPublicKeysV2[currentUserId] || []
      const myKeyPresent = serverKeys.some(async (k) => {
        // Simple comparison: if our pubKeyB64 is in the list, we're good
        return k === CryptoState.publicKeyB64
      })

      // Actually, do a direct string comparison since pubKeyB64 is base64
      const isKeyPresent = serverKeys.includes(CryptoState.publicKeyB64)

      if (!result.newKey && !isKeyPresent && serverKeys.length > 0) {
        console.log("[ChatCrypto] Local key not in server's active key set. Re-registering...")
        this.pushEvent("register_public_key", { public_key: CryptoState.publicKeyB64 })
        this.pushEvent("report_key_mismatch", {})
        this._startMismatchRetry()
      }

      // Load conversation key by matching fingerprint
      if (this.encryptedKeysV2 && this.encryptedKeysV2.length > 0) {
        CryptoState.conversationKeys.delete(this.convId)
        const myEntry = this.encryptedKeysV2.find(e => e.fingerprint === CryptoState.keyFingerprint)
        if (myEntry) {
          try {
            await CryptoState.getConversationKey(this.convId, myEntry.key)
            await this.decryptAll()
          } catch (e) {
            console.error("[ChatCrypto] Failed to decrypt conversation key:", e)
            this.pushEvent("report_key_mismatch", {})
            this._startMismatchRetry()
          }
        } else {
          // No encrypted copy for our fingerprint yet — need re-encryption
          console.log("[ChatCrypto] No encrypted key found for fingerprint", CryptoState.keyFingerprint)
          this.pushEvent("report_key_mismatch", {})
          this._startMismatchRetry()
        }
      }
    } else {
      // Legacy single-key mode
      // Detect if our local key is stale relative to the server's active key.
      const serverPubKey = this.participantPublicKeys[currentUserId]
      const localPubKey = CryptoState.publicKeyB64
      if (!result.newKey && serverPubKey && localPubKey && serverPubKey !== localPubKey) {
        console.log("[ChatCrypto] Local key doesn't match server. Re-registering local key...")
        this.pushEvent("register_public_key", { public_key: localPubKey })
        this.pushEvent("report_key_mismatch", {})
        this._startMismatchRetry()
      }

      // Load conversation key if provided
      const encryptedKey = this.el.dataset.encryptedKey
      if (encryptedKey) {
        CryptoState.conversationKeys.delete(this.convId)
        try {
          await CryptoState.getConversationKey(this.convId, encryptedKey)
          await this.decryptAll()
        } catch (e) {
          console.error("[ChatCrypto] Failed to decrypt conversation key:", e)
          this.pushEvent("report_key_mismatch", {})
          this._startMismatchRetry()
        }
      }
    }

    // Server sends the conversation key (initial load or after creation)
    this.handleEvent("conversation_key", async ({ encrypted_key, encrypted_keys_v2 }) => {
      let keyToTry = null

      if (this.multiKeyMode && encrypted_keys_v2 && encrypted_keys_v2.length > 0) {
        // Multi-key mode: find the entry matching our fingerprint
        const myEntry = encrypted_keys_v2.find(e => e.fingerprint === CryptoState.keyFingerprint)
        if (myEntry) {
          keyToTry = myEntry.key
        }
      }

      // Fallback to legacy single-key format
      if (!keyToTry && encrypted_key) {
        keyToTry = encrypted_key
      }

      if (!keyToTry) return

      // Save the existing cached key in case the new one is for a different
      // device (same user, different key pair). We must not destroy a working
      // cache just because a multi-device re-encryption arrived.
      const existingKey = CryptoState.conversationKeys.get(this.convId)
      CryptoState.conversationKeys.delete(this.convId)
      try {
        await CryptoState.getConversationKey(this.convId, keyToTry)
        await this.decryptAll()
        // Stop retrying since we have a working key now
        this._stopMismatchRetry()
        // Tell server to hide the re-key banner
        this.pushEvent("acknowledge_conversation_key", {})
        // Process any pending message
        if (window.chatPendingMessage) {
          const text = window.chatPendingMessage
          window.chatPendingMessage = null
          const { ciphertext, iv } = await CryptoState.encrypt(this.convId, text)
          this.pushEvent("send_encrypted_message", { ciphertext, iv })
        }
      } catch (e) {
        console.error("[ChatCrypto] Failed to set conversation key:", e)
        // Restore the previously working key so this device doesn't break
        // just because a re-encryption for another device arrived.
        if (existingKey) {
          CryptoState.conversationKeys.set(this.convId, existingKey)
        }
        // Only start the retry timer if we don't already have a working key.
        if (!existingKey) {
          this._startMismatchRetry()
        }
      }
    })

    // Server asks client to create a conversation key
    this.handleEvent("create_conversation_key", async ({ participant_public_keys, participant_public_keys_v2 }) => {
      if (!CryptoState.ready) {
        console.error("[ChatCrypto] Cannot create key: crypto not ready")
        return
      }
      try {
        // Use v2 format if available (multi-device), otherwise legacy
        const pubKeys = participant_public_keys_v2 || participant_public_keys
        const { aesKey, encryptedKeys } = await CryptoState.createConversationKeys(pubKeys)
        await CryptoState.setConversationKey(this.convId, aesKey)
        this.pushEvent("store_conversation_keys", { encrypted_keys: encryptedKeys })
      } catch (e) {
        console.error("[ChatCrypto] Failed to create conversation key:", e)
      }
    })

    // Handle request to re-encrypt conversation key for another user
    this.handleEvent("re_encrypt_for_user", async ({ target_user_id, public_key, public_keys }) => {
      console.log("[ChatCrypto] Received re_encrypt_for_user for target", target_user_id)
      if (!CryptoState.ready) {
        console.error("[ChatCrypto] Cannot re-encrypt: crypto not ready")
        return
      }
      try {
        // Always prefer the DOM key — it reflects the latest server state.
        let aesKey = null
        const domEncryptedKey = this.el.dataset.encryptedKey
        const existingKey = CryptoState.conversationKeys.get(this.convId)

        // In multi-key mode, also try the v2 encrypted keys from DOM
        const domEncryptedKeysV2 = this.el.dataset.encryptedKeysV2
        if (domEncryptedKeysV2) {
          const entries = JSON.parse(domEncryptedKeysV2)
          const myEntry = entries.find(e => e.fingerprint === CryptoState.keyFingerprint)
          if (myEntry) {
            CryptoState.conversationKeys.delete(this.convId)
            try {
              aesKey = await CryptoState.getConversationKey(this.convId, myEntry.key)
            } catch (e) {
              console.error("[ChatCrypto] Failed to decrypt conversation key from DOM v2:", e)
            }
          }
        }

        if (!aesKey && domEncryptedKey) {
          CryptoState.conversationKeys.delete(this.convId)
          try {
            aesKey = await CryptoState.getConversationKey(this.convId, domEncryptedKey)
          } catch (e) {
            console.error("[ChatCrypto] Failed to decrypt conversation key from DOM:", e)
          }
        }

        // Fallback to cached key only if DOM decrypt failed
        if (!aesKey) {
          aesKey = existingKey
        }

        if (!aesKey) {
          console.error("[ChatCrypto] Cannot re-encrypt: no conversation key available")
          return
        }

        // Determine which keys to re-encrypt for
        const targetKeys = public_keys || (public_key ? [public_key] : [])
        if (targetKeys.length === 0) {
          console.error("[ChatCrypto] No target public keys provided")
          return
        }

        console.log("[ChatCrypto] Re-encrypting conversation key for target", target_user_id)

        if (targetKeys.length === 1) {
          // Legacy single-key response
          const encryptedKey = await encryptConversationKey(aesKey, targetKeys[0])
          this.pushEvent("submit_re_encrypted_key", {
            target_user_id: target_user_id,
            encrypted_key: encryptedKey
          })
        } else {
          // Multi-key response: encrypt for ALL target keys
          const encryptedEntries = []
          for (const pubKeyB64 of targetKeys) {
            const encrypted = await encryptConversationKey(aesKey, pubKeyB64)
            const fingerprint = await keyFingerprint(pubKeyB64)
            encryptedEntries.push({ fingerprint, encrypted_key: encrypted })
          }
          this.pushEvent("submit_re_encrypted_key", {
            target_user_id: target_user_id,
            encrypted_keys: encryptedEntries
          })
        }

        console.log("[ChatCrypto] Submitted re-encrypted key(s) for target", target_user_id)
      } catch (e) {
        console.error("[ChatCrypto] Failed to re-encrypt conversation key:", e)
      }
    })

    // Handle encryption errors from server
    this.handleEvent("encryption_error", ({ message }) => {
      console.error("[ChatCrypto] Encryption error:", message)
      // Clear pending message since we can't send
      window.chatPendingMessage = null
    })

    // Handle encryption reset (nuclear option: old keys deleted, start fresh)
    this.handleEvent("encryption_reset", () => {
      console.log("[ChatCrypto] Encryption reset for conversation", this.convId)
      CryptoState.conversationKeys.delete(this.convId)
      this._stopMismatchRetry()
      // The next message send will trigger ensure_conversation_key -> create_conversation_key
    })

    // Decrypt new messages pushed via PubSub
    this.handleEvent("decrypt_message", async ({ id, ciphertext, iv }) => {
      const el = document.querySelector(`[data-msg-id="${id}"]`)
      if (el) {
        await this.decryptElement(el, ciphertext, iv)
      }
    })

    // Handle edit mode start: decrypt the message and populate textarea
    this.handleEvent("start_edit", async ({ message_id, ciphertext, iv }) => {
      try {
        const text = await CryptoState.decrypt(this.convId, ciphertext, iv)
        window.chatEditingMessage = { message_id, text }
        const textarea = document.getElementById("chat-message-input")
        if (textarea) {
          textarea.value = text
          textarea.style.height = "auto"
          textarea.style.height = Math.min(textarea.scrollHeight, 128) + "px"
          textarea.focus()
        }
      } catch (e) {
        console.error("[ChatCrypto] Failed to decrypt message for editing:", e)
      }
    })

    // Re-decrypt on DOM updates
    this.phxUpdateHandler = () => {
      this.decryptAll()
    }
    window.addEventListener("phx:update", this.phxUpdateHandler)

    if (CryptoState.conversationKeys.has(this.convId)) {
      await this.decryptAll()
    }
  },

  async updated() {
    // Retry registration if mounted() tried before socket was connected
    if (this._needsRegistration) {
      this.pushEvent("register_public_key", { public_key: this._needsRegistration })
      this._needsRegistration = null
    }

    if (CryptoState.conversationKeys.has(this.convId)) {
      await this.decryptAll()
    }
  },

  destroyed() {
    if (this.phxUpdateHandler) {
      window.removeEventListener("phx:update", this.phxUpdateHandler)
    }
    this._stopMismatchRetry()
  },

  _startMismatchRetry() {
    if (this._mismatchRetryInterval) return
    console.log("[ChatCrypto] Starting periodic mismatch retry")
    this._mismatchRetryInterval = setInterval(() => {
      console.log("[ChatCrypto] Retrying key mismatch report...")
      this.pushEvent("report_key_mismatch", {})
    }, 8000)
  },

  _stopMismatchRetry() {
    if (this._mismatchRetryInterval) {
      clearInterval(this._mismatchRetryInterval)
      this._mismatchRetryInterval = null
      console.log("[ChatCrypto] Stopped periodic mismatch retry")
    }
  },

  async decryptAll() {
    const container = document.getElementById("chat-wrapper") || document
    if (!container) return
    const els = container.querySelectorAll('[data-encrypted="true"]')
    for (const el of els) {
      const ct = el.dataset.ciphertext
      const iv = el.dataset.iv
      if (ct && iv) {
        await this.decryptElement(el, ct, iv)
      }
    }
  },

  async decryptElement(el, ciphertext, iv) {
    try {
      const text = await CryptoState.decrypt(this.convId, ciphertext, iv)
      el.textContent = ""
      this.renderMessageContent(el, text)
      el.removeAttribute("data-encrypted")
      this.styleEmojiMessage(el, text)
    } catch (e) {
      console.log("[ChatCrypto] decrypt failed:", e.message)
      // Don't remove data-encrypted on failure — key may not be ready yet
    }
  },

  renderMessageContent(el, text) {
    // Check for /kanji command
    const kanjiMatch = text.match(/^\/(?:kanji|k)\s+(.+)$/)
    if (kanjiMatch) {
      const char = kanjiMatch[1].trim()
      if (isSingleKanji(char)) {
        this.renderKanjiPreview(el, char)
        return
      }
    }

    const emojiRegex = /(:medoru:|:ouroboros:)/
    const urlRegex = /https?:\/\/[^\s<>"{}|\\^`\[\]]+/g
    const parts = text.split(emojiRegex)

    parts.forEach((part) => {
      if (part === ":medoru:") {
        const img = document.createElement("img")
        img.src = "/favicon.png"
        img.alt = "medoru"
        img.className = "medoru-emoji inline align-text-bottom"
        el.appendChild(img)
      } else if (part === ":ouroboros:") {
        const img = document.createElement("img")
        img.src = "/images/ouroboros.png"
        img.alt = "ouroboros"
        img.className = "medoru-emoji inline align-text-bottom"
        el.appendChild(img)
      } else if (part) {
        const segments = part.split(urlRegex)
        const urls = part.match(urlRegex) || []
        segments.forEach((segment, i) => {
          if (segment) el.appendChild(document.createTextNode(segment))
          if (i < urls.length) {
            const a = document.createElement("a")
            a.href = urls[i]
            a.target = "_blank"
            a.rel = "noopener noreferrer"
            a.className = "underline break-all text-blue-300 hover:text-blue-200"
            a.textContent = urls[i]
            el.appendChild(a)
          }
        })
      }
    })
  },

  renderKanjiPreview(el, character) {
    const container = document.createElement("div")
    container.className = "kanji-chat-preview-placeholder"
    container.innerHTML = `<div class="text-sm text-base-content/50">Loading kanji...</div>`
    el.appendChild(container)

    fetchKanjiPreview(character).then((data) => {
      if (!data) {
        container.innerHTML = `<div class="text-sm text-error">Kanji not found</div>`
        return
      }

      const strokes = data.stroke_data?.strokes || []
      const bounds = data.stroke_data?.bounds || { viewBox: "0 0 100 100" }
      const total = strokes.length

      const meaningsHtml = (data.meanings || [])
        .slice(0, 3)
        .map((m, i) => `${i > 0 ? '<span class="text-base-content/30">, </span>' : ""}<span>${escapeHtml(m)}</span>`)
        .join("")

      const onHtml = data.on_reading
        ? `<span class="font-medium text-primary">${escapeHtml(data.on_reading)}</span>`
        : ""
      const kunHtml = data.kun_reading
        ? `<span class="font-medium text-accent">${escapeHtml(data.kun_reading)}</span>`
        : ""

      const strokePaths = strokes
        .map((stroke, idx) => {
          const order = stroke.order || idx + 1
          const delay = (order - 1) * 400
          const duration = Math.max(600, Math.trunc((800 / total) * 4))
          return `<path d="${stroke.path}" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="text-primary" style="stroke-dasharray: 1000; stroke-dashoffset: 1000; animation-name: draw; animation-duration: ${duration}ms; animation-timing-function: ease-in-out; animation-fill-mode: forwards; animation-delay: ${delay}ms;" />`
        })
        .join("")

      // Compact HTML with no whitespace to avoid issues with whitespace-pre-wrap
      container.outerHTML =
        `<a href="${data.path}" target="_blank" rel="noopener noreferrer" class="block max-w-[180px] kanji-chat-preview -mt-1 -mb-1">` +
        `<div class="bg-base-100 border border-base-300 rounded-xl p-2 shadow-sm hover:shadow-md hover:border-primary/30 transition-all">` +
        `<div class="text-xs text-center text-secondary mb-1 truncate px-1">${meaningsHtml}</div>` +
        `<div class="bg-base-100 border border-base-300 rounded-lg p-1.5 mx-auto w-fit"><svg viewBox="${bounds.viewBox}" class="w-20 h-20">${strokePaths}</svg></div>` +
        `<div class="text-xs text-center mt-1 flex justify-center gap-2">${onHtml}${kunHtml}</div>` +
        `</div></a>`
    })
  },

  styleEmojiMessage(el, text) {
    if (!text || !this.isEmojiOnly(text)) return
    const bubble = el.closest(".message-bubble")
    if (bubble) {
      bubble.classList.add("emoji-only")
      el.classList.remove("text-[15px]", "leading-snug")
      el.classList.add("text-4xl", "leading-none", "py-1")
      // Remove bubble background styling
      bubble.classList.remove("bg-primary", "text-primary-content", "border-primary", "bg-accent/15", "border-accent/30")
      bubble.classList.add("bg-transparent", "border-transparent", "text-base-content")
    }
  },

  isEmojiOnly(str) {
    if (!str || str.trim().length === 0) return false
    const cleaned = str.replace(/[\s\uFE0F\u200D\u{1F3FB}-\u{1F3FF}]/gu, "").replace(/:medoru:/g, "").replace(/:ouroboros:/g, "")
    const nonEmoji = cleaned.replace(/[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F004}\u{1F0CF}\u{1F170}-\u{1F251}\u{238C}\u{2B50}\u{2B55}\u{2764}\u{2795}-\u{2797}\u{27A1}\u{27B0}\u{27BF}\u{2B05}-\u{2B07}\u{3030}\u{303D}\u{3297}\u{3299}\u{23F0}-\u{23F3}\u{23E9}-\u{23EF}\u{1F18E}\u{00A9}\u{00AE}]/gu, "")
    return nonEmoji.length === 0
  }
}

const kanjiCache = new Map()

async function fetchKanjiPreview(character) {
  if (kanjiCache.has(character)) return kanjiCache.get(character)
  try {
    const resp = await fetch(`/api/kanji-preview/${encodeURIComponent(character)}`)
    if (!resp.ok) return null
    const data = await resp.json()
    kanjiCache.set(character, data)
    return data
  } catch (e) {
    console.error("[ChatCrypto] Failed to fetch kanji preview:", e)
    return null
  }
}

function isSingleKanji(str) {
  if (str.length !== 1) return false
  const code = str.codePointAt(0)
  return (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3400 && code <= 0x4DBF)
}

function escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}

export default ChatCrypto
