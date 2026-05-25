import { CryptoState } from "./chat_crypto"

const GroupChatCreator = {
  async mounted() {
    // Initialize user key pair if needed
    const currentUserId = this.el.dataset.currentUserId
    const result = await CryptoState.init(currentUserId)
    if (result.newKey && result.publicKey) {
      this.pushEvent("register_public_key", { public_key: result.publicKey })
    }

    this.button = this.el.querySelector("#create-group-button")
    this.titleInput = this.el.querySelector("#group-title-input")

    const pubKeysJson = this.el.dataset.participantPublicKeys
    this.participantPublicKeys = pubKeysJson ? JSON.parse(pubKeysJson) : {}

    if (this.button) {
      this.button.addEventListener("click", () => this.createGroup())
    }

    if (this.titleInput) {
      this.titleInput.addEventListener("keydown", (e) => {
        if (e.key === "Enter") {
          e.preventDefault()
          this.createGroup()
        }
      })
    }
  },

  async createGroup() {
    const title = this.titleInput.value.trim()
    if (!title) {
      // Let the server handle validation
      this.pushEvent("update_title", { title: "" })
      return
    }

    if (!CryptoState.ready) {
      console.error("[GroupChatCreator] Crypto not ready")
      return
    }

    try {
      const { aesKey, encryptedKeys } = await CryptoState.createConversationKeys(this.participantPublicKeys)
      this.pushEvent("create_group", { title, encrypted_keys: encryptedKeys })
    } catch (e) {
      console.error("[GroupChatCreator] Failed to create group:", e)
    }
  }
}

export default GroupChatCreator
