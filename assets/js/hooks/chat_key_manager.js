const ChatKeyManager = {
  mounted() {
    this.exportBtn = this.el.querySelector("#chat-key-export-btn")
    this.importBtn = this.el.querySelector("#chat-key-import-btn")
    this.importArea = this.el.querySelector("#chat-key-import-area")
    this.importInput = this.el.querySelector("#chat-key-import-input")
    this.importConfirm = this.el.querySelector("#chat-key-import-confirm")
    this.statusEl = this.el.querySelector("#chat-key-status")
    this.keyDisplay = this.el.querySelector("#chat-key-display")

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

  checkKeyStatus() {
    const privKey = localStorage.getItem("medoru_chat_privkey_v2")
    if (privKey) {
      this.showStatus("active", "Your encryption key is active on this device.")
      if (this.keyDisplay) {
        this.keyDisplay.value = privKey
      }
    } else {
      this.showStatus("missing", "No encryption key found on this device. You may need to import one from another device.")
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
    const privKey = localStorage.getItem("medoru_chat_privkey_v2")
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
      const privateKey = await crypto.subtle.importKey(
        "pkcs8",
        binary,
        { name: "RSA-OAEP", hash: "SHA-256" },
        true,
        ["decrypt"]
      )

      // Derive the public key from the private key
      const publicKey = await crypto.subtle.exportKey("spki", privateKey)
      const publicKeyB64 = this.bufferToB64(publicKey)

      // Save to localStorage
      localStorage.setItem("medoru_chat_privkey_v2", keyText)
      localStorage.setItem("medoru_chat_pubkey_v2", publicKeyB64)

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
  }
}

export default ChatKeyManager
