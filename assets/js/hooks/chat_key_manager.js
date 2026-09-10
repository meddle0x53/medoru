// Storage key helpers matching ChatCrypto's user-isolated format
function getPrivKeyStorage(userId) { return `medoru_chat_privkey_v2_${userId}` }
function getPubKeyStorage(userId) { return `medoru_chat_pubkey_v2_${userId}` }
function getFingerprintStorage(userId) { return `medoru_chat_keyfp_v2_${userId}` }

function derLength(length) {
  if (length < 128) return [length]

  const bytes = []
  let value = length
  while (value > 0) {
    bytes.unshift(value & 0xff)
    value >>= 8
  }
  return [0x80 | bytes.length, ...bytes]
}

function derElement(tag, body) {
  return new Uint8Array([tag, ...derLength(body.length), ...body])
}

function concatBytes(...arrays) {
  const total = arrays.reduce((sum, bytes) => sum + bytes.length, 0)
  const out = new Uint8Array(total)
  let offset = 0
  for (const bytes of arrays) {
    out.set(bytes, offset)
    offset += bytes.length
  }
  return out
}

function readDerElement(bytes, offset, expectedTag = null) {
  const tag = bytes[offset]
  if (expectedTag !== null && tag !== expectedTag) {
    throw new Error(`Unexpected DER tag ${tag}; expected ${expectedTag}`)
  }

  let cursor = offset + 1
  let length = bytes[cursor++]
  if (length & 0x80) {
    const lengthBytes = length & 0x7f
    length = 0
    for (let i = 0; i < lengthBytes; i++) {
      length = (length << 8) | bytes[cursor++]
    }
  }

  const start = cursor
  const end = start + length
  if (end > bytes.length) {
    throw new Error("DER element extends past end of input")
  }

  return {
    tag,
    start,
    end,
    value: bytes.slice(start, end),
    encoded: bytes.slice(offset, end)
  }
}

function publicSpkiFromPkcs8PrivateKey(pkcs8Buffer) {
  const pkcs8 = new Uint8Array(pkcs8Buffer)
  const privateKeyInfo = readDerElement(pkcs8, 0, 0x30)
  let cursor = privateKeyInfo.start

  const version = readDerElement(pkcs8, cursor, 0x02)
  cursor = version.end

  const algorithm = readDerElement(pkcs8, cursor, 0x30)
  cursor = algorithm.end

  const privateKeyOctets = readDerElement(pkcs8, cursor, 0x04)
  const rsaPrivateKey = readDerElement(privateKeyOctets.value, 0, 0x30)
  cursor = rsaPrivateKey.start

  const rsaVersion = readDerElement(privateKeyOctets.value, cursor, 0x02)
  cursor = rsaVersion.end

  const modulus = readDerElement(privateKeyOctets.value, cursor, 0x02)
  cursor = modulus.end

  const publicExponent = readDerElement(privateKeyOctets.value, cursor, 0x02)
  const rsaPublicKey = derElement(0x30, concatBytes(modulus.encoded, publicExponent.encoded))
  const bitString = derElement(0x03, concatBytes(new Uint8Array([0x00]), rsaPublicKey))

  return derElement(0x30, concatBytes(algorithm.encoded, bitString)).buffer
}

const ChatKeyManager = {
  mounted() {
    this.userId = this.el.dataset.currentUserId || "default"
    this.exportBtn = this.el.querySelector("#chat-key-export-btn")
    this.importBtn = this.el.querySelector("#chat-key-import-btn")
    this.importArea = this.el.querySelector("#chat-key-import-area")
    this.importInput = this.el.querySelector("#chat-key-import-input")
    this.importConfirm = this.el.querySelector("#chat-key-import-confirm")
    this.statusEl = this.el.querySelector("#chat-key-status")
    this.mismatchWarning = this.el.querySelector("#chat-key-mismatch-warning")
    this.keyDisplay = this.el.querySelector("#chat-key-display")
    this.registeredPublicKeys = this.parseRegisteredPublicKeys()

    if (this.exportBtn) {
      this.exportBtn.addEventListener("click", () => this.exportKey())
    }

    if (this.importBtn) {
      this.importBtn.addEventListener("click", () => this.showImport())
    }

    if (this.importConfirm) {
      this.importConfirm.addEventListener("click", () => this.importKey())
    }

    // Check if key exists
    this.checkKeyStatus()
  },

  _getPrivateKey() {
    // Prefer user-isolated storage (used by ChatCrypto), fallback to legacy
    return localStorage.getItem(getPrivKeyStorage(this.userId))
      || localStorage.getItem("medoru_chat_privkey_v2")
  },

  _getPublicKey() {
    return localStorage.getItem(getPubKeyStorage(this.userId))
      || localStorage.getItem("medoru_chat_pubkey_v2")
  },

  _saveKeys(privKey, pubKey, fingerprint) {
    // Save to user-isolated storage (primary)
    localStorage.setItem(getPrivKeyStorage(this.userId), privKey)
    localStorage.setItem(getPubKeyStorage(this.userId), pubKey)
    localStorage.setItem(getFingerprintStorage(this.userId), fingerprint)
    // Also save to legacy location for backwards compatibility
    localStorage.setItem("medoru_chat_privkey_v2", privKey)
    localStorage.setItem("medoru_chat_pubkey_v2", pubKey)
  },

  parseRegisteredPublicKeys() {
    try {
      return JSON.parse(this.el.dataset.registeredPublicKeys || "[]")
    } catch (_e) {
      return []
    }
  },

  showMismatchWarning(show) {
    if (!this.mismatchWarning) return
    this.mismatchWarning.classList.toggle("hidden", !show)
  },

  checkKeyStatus() {
    const privKey = this._getPrivateKey()
    const pubKey = this._getPublicKey()
    const hasRegisteredKeys = this.registeredPublicKeys.length > 0
    const registeredOnThisDevice = pubKey && this.registeredPublicKeys.includes(pubKey)
    const usingNewestOfMultipleKeys = this.registeredPublicKeys.length > 1 && pubKey === this.registeredPublicKeys[0]

    this.showMismatchWarning(hasRegisteredKeys && (!registeredOnThisDevice || usingNewestOfMultipleKeys))

    if (privKey && pubKey && (!hasRegisteredKeys || registeredOnThisDevice)) {
      this.showStatus("active", "Your encryption key is active on this device.")
      if (this.keyDisplay) {
        this.keyDisplay.value = privKey
      }
    } else if (privKey && pubKey) {
      this.showStatus("missing", "This device has a different encryption key. Import your original key from another device to read old messages.")
      if (this.keyDisplay) {
        this.keyDisplay.value = privKey
      }
    } else if (privKey) {
      this.showStatus("error", "Your saved encryption key is incomplete. Import your original key again.")
      if (this.keyDisplay) {
        this.keyDisplay.value = privKey
      }
    } else {
      this.showStatus("missing", "No encryption key found on this device. You may need to import one from another device.")
      if (this.keyDisplay) {
        this.keyDisplay.value = ""
      }
    }
  },

  showStatus(type, message) {
    if (!this.statusEl) return
    this.statusEl.textContent = message
    this.statusEl.className = "text-sm " + (
      type === "active" ? "text-success" :
      type === "error" ? "text-error" :
      type === "success" ? "text-success" :
      "text-warning"
    )
  },

  exportKey() {
    const privKey = this._getPrivateKey()
    if (!privKey) {
      this.showStatus("error", "No encryption key found to export.")
      return
    }

    // Copy to clipboard
    navigator.clipboard.writeText(privKey).then(() => {
      this.showStatus("success", "Key copied to clipboard! Save it somewhere safe.")
    }).catch(() => {
      // Fallback: show in textarea for manual copy
      if (this.keyDisplay) {
        this.keyDisplay.select()
        this.showStatus("warning", "Please copy the key manually from the field above.")
      }
    })
  },

  showImport() {
    if (this.importArea) {
      this.importArea.classList.remove("hidden")
    }
    if (this.importBtn) {
      this.importBtn.classList.add("hidden")
    }
  },

  async importKey() {
    const keyText = this.importInput ? this.importInput.value.trim() : ""
    if (!keyText) {
      this.showStatus("error", "Please paste your encryption key.")
      return
    }

    try {
      // Validate by trying to import the private key
      const binary = this.b64ToBuffer(keyText)
      await crypto.subtle.importKey(
        "pkcs8",
        binary,
        { name: "RSA-OAEP", hash: "SHA-256" },
        false,
        ["decrypt"]
      )

      const publicKey = publicSpkiFromPkcs8PrivateKey(binary)
      const publicKeyB64 = this.bufferToB64(publicKey)
      await crypto.subtle.importKey(
        "spki",
        publicKey,
        { name: "RSA-OAEP", hash: "SHA-256" },
        false,
        ["encrypt"]
      )
      const fingerprint = await this.keyFingerprint(publicKeyB64)

      // Save to localStorage (both user-isolated and legacy)
      this._saveKeys(keyText, publicKeyB64, fingerprint)
      if (!this.registeredPublicKeys.includes(publicKeyB64)) {
        this.registeredPublicKeys = [publicKeyB64, ...this.registeredPublicKeys]
      }
      this.showMismatchWarning(this.registeredPublicKeys.length > 1 && publicKeyB64 === this.registeredPublicKeys[0])

      // Register with server
      this.pushEvent("register_public_key", { public_key: publicKeyB64 })

      this.showStatus("success", "Encryption key imported successfully! Your old messages should now be readable.")

      if (this.importArea) {
        this.importArea.classList.add("hidden")
      }
      if (this.importBtn) {
        this.importBtn.classList.remove("hidden")
      }
      if (this.keyDisplay) {
        this.keyDisplay.value = keyText
      }
    } catch (e) {
      console.error("[ChatKeyManager] Import failed:", e)
      this.showStatus("error", "Invalid encryption key. Please check and try again.")
    }
  },

  b64ToBuffer(base64) {
    const binary = atob(base64)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i)
    }
    return bytes.buffer
  },

  bufferToB64(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    return btoa(binary)
  },

  async keyFingerprint(publicKeyB64) {
    const spki = this.b64ToBuffer(publicKeyB64)
    const hash = await crypto.subtle.digest("SHA-256", spki)
    return Array.from(new Uint8Array(hash))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("")
      .slice(0, 16)
  }
}

export default ChatKeyManager
