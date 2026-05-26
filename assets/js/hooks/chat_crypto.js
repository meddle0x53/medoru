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

// --- Global crypto state ---
export const CryptoState = {
  privateKey: null,
  publicKeyB64: null,
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

    let privB64 = localStorage.getItem(privStore)
    let pubB64 = localStorage.getItem(pubStore)
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
      localStorage.setItem(privStore, privB64)
      localStorage.setItem(pubStore, pubB64)
      this.privateKey = kp.privateKey
      this.publicKeyB64 = pubB64
      this.ready = true
      return { ready: true, newKey: true, publicKey: pubB64 }
    }

    this.privateKey = await importPrivateKey(privB64)
    this.publicKeyB64 = pubB64
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
    for (const [userId, pubKeyB64] of Object.entries(participantPublicKeys)) {
      encryptedKeys[userId] = await encryptConversationKey(aesKey, pubKeyB64)
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

    // Parse participant public keys from data attribute
    const pubKeysJson = this.el.dataset.participantPublicKeys
    this.participantPublicKeys = pubKeysJson ? JSON.parse(pubKeysJson) : {}

    // Detect if our local key is stale relative to the server's active key.
    // If the server has a different public key for us, our private key can't
    // decrypt any conversation key re-encrypted by other participants.
    const serverPubKey = this.participantPublicKeys[currentUserId]
    const localPubKey = CryptoState.publicKeyB64
    if (serverPubKey && localPubKey && serverPubKey !== localPubKey) {
      console.log("[ChatCrypto] Local key stale (doesn't match server). Regenerating...")
      localStorage.removeItem(getPrivKeyStorage(currentUserId))
      localStorage.removeItem(getPubKeyStorage(currentUserId))
      localStorage.removeItem("medoru_chat_privkey_v2")
      localStorage.removeItem("medoru_chat_pubkey_v2")
      CryptoState.privateKey = null
      CryptoState.publicKeyB64 = null
      CryptoState.ready = false
      const freshResult = await CryptoState.init(currentUserId)
      if (freshResult.publicKey) {
        this.pushEvent("register_public_key", { public_key: freshResult.publicKey })
      }
    }

    // Load conversation key if provided
    const encryptedKey = this.el.dataset.encryptedKey
    if (encryptedKey) {
      // Always discard stale cache — the server may have reset/replaced the key
      CryptoState.conversationKeys.delete(this.convId)
      try {
        await CryptoState.getConversationKey(this.convId, encryptedKey)
        await this.decryptAll()
      } catch (e) {
        console.error("[ChatCrypto] Failed to decrypt conversation key:", e)
        // Tell server to show the re-key banner since we can't decrypt
        this.pushEvent("report_key_mismatch", {})
        // Start periodic retry in case someone comes online later
        this._startMismatchRetry()
      }
    }

    // Server sends the conversation key (initial load or after creation)
    this.handleEvent("conversation_key", async ({ encrypted_key }) => {
      if (!encrypted_key) return
      // The server sent us a key — always discard cache and try the latest one.
      // Otherwise a stale cached key silently breaks encryption/decryption.
      CryptoState.conversationKeys.delete(this.convId)
      try {
        await CryptoState.getConversationKey(this.convId, encrypted_key)
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
        // Do NOT immediately report mismatch here — that creates a tight
        // feedback loop when a user's key is permanently mismatched.
        // The periodic retry (8s) will request re-encryption instead.
        this._startMismatchRetry()
      }
    })

    // Server asks client to create a conversation key
    this.handleEvent("create_conversation_key", async ({ participant_public_keys }) => {
      if (!CryptoState.ready) {
        console.error("[ChatCrypto] Cannot create key: crypto not ready")
        return
      }
      try {
        const { aesKey, encryptedKeys } = await CryptoState.createConversationKeys(participant_public_keys)
        await CryptoState.setConversationKey(this.convId, aesKey)
        this.pushEvent("store_conversation_keys", { encrypted_keys: encryptedKeys })
      } catch (e) {
        console.error("[ChatCrypto] Failed to create conversation key:", e)
      }
    })

    // Handle request to re-encrypt conversation key for another user
    this.handleEvent("re_encrypt_for_user", async ({ target_user_id, public_key }) => {
      console.log("[ChatCrypto] Received re_encrypt_for_user for target", target_user_id)
      if (!CryptoState.ready) {
        console.error("[ChatCrypto] Cannot re-encrypt: crypto not ready")
        return
      }
      try {
        // Always prefer the DOM key — it reflects the latest server state.
        // A cached key may be stale after an encryption reset.
        let aesKey = null
        const domEncryptedKey = this.el.dataset.encryptedKey
        if (domEncryptedKey) {
          CryptoState.conversationKeys.delete(this.convId)
          try {
            aesKey = await CryptoState.getConversationKey(this.convId, domEncryptedKey)
          } catch (e) {
            console.error("[ChatCrypto] Failed to decrypt conversation key from DOM:", e)
          }
        }

        // Fallback to cached key only if DOM decrypt failed
        if (!aesKey) {
          aesKey = CryptoState.conversationKeys.get(this.convId)
        }

        if (!aesKey) {
          console.error("[ChatCrypto] Cannot re-encrypt: no conversation key available")
          return
        }
        console.log("[ChatCrypto] Re-encrypting conversation key for target", target_user_id)
        const encryptedKey = await encryptConversationKey(aesKey, public_key)
        this.pushEvent("submit_re_encrypted_key", {
          target_user_id: target_user_id,
          encrypted_key: encryptedKey
        })
        console.log("[ChatCrypto] Submitted re-encrypted key for target", target_user_id)
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
      el.textContent = text
      el.removeAttribute("data-encrypted")
      this.styleEmojiMessage(el, text)
    } catch (e) {
      console.log("[ChatCrypto] decrypt failed:", e.message)
      // Don't remove data-encrypted on failure — key may not be ready yet
    }
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
    const cleaned = str.replace(/[\s\uFE0F\u200D\u{1F3FB}-\u{1F3FF}]/gu, "")
    const nonEmoji = cleaned.replace(/[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F004}\u{1F0CF}\u{1F170}-\u{1F251}\u{238C}\u{2B50}\u{2B55}\u{2764}\u{2795}-\u{2797}\u{27A1}\u{27B0}\u{27BF}\u{2B05}-\u{2B07}\u{3030}\u{303D}\u{3297}\u{3299}\u{23F0}-\u{23F3}\u{23E9}-\u{23EF}\u{1F18E}\u{00A9}\u{00AE}]/gu, "")
    return nonEmoji.length === 0
  }
}

export default ChatCrypto
