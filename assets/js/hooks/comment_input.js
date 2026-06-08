const ALLOWED_TYPES = [
  "image/jpeg", "image/png", "image/gif", "image/webp",
  "audio/mpeg", "audio/wav", "audio/wave", "audio/x-wav",
  "audio/webm", "audio/ogg",
  "video/mp4", "video/webm", "video/ogg", "video/quicktime",
  "application/pdf", "text/plain", "text/csv",
  "application/json", "text/markdown", "text/x-markdown",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/epub+zip"
]

const MAX_SIZE_DEFAULT = 50 * 1024 * 1024
const MAX_SIZE_VIDEO = 200 * 1024 * 1024

export default {
  mounted() {
    this.textInput = this.el.querySelector("input[type='text']")
    this.attachmentBtn = this.el.querySelector("[data-comment-attachment-btn]")
    this.fileInput = this.el.querySelector("[data-comment-file-input]")

    if (!this.textInput) return

    if (this.attachmentBtn && this.fileInput) {
      this.attachmentBtn.addEventListener("click", () => {
        this.fileInput.click()
      })

      this.fileInput.addEventListener("change", (e) => {
        this.handleFileSelect(e)
      })
    }
  },

  handleFileSelect(e) {
    const file = e.target.files[0]
    if (!file) return
    this.processFile(file)
    this.fileInput.value = ""
  },

  processFile(file) {
    const isAllowedType = ALLOWED_TYPES.includes(file.type) || this.allowedByExtension(file.name)

    if (!isAllowedType) {
      alert("File type not allowed.")
      return
    }

    const isVideo = file.type.startsWith("video/") || this.isVideoExtension(file.name)
    const canUploadVideo = this.el.dataset.canUploadVideo === "true"

    if (isVideo && !canUploadVideo) {
      alert("Video uploads are only available for teachers and admins.")
      return
    }

    const maxSize = isVideo ? MAX_SIZE_VIDEO : MAX_SIZE_DEFAULT
    const maxSizeMb = maxSize / (1024 * 1024)

    if (file.size > maxSize) {
      alert(`File too large. Maximum size is ${maxSizeMb}MB.`)
      return
    }

    this.uploadFile(file)
  },

  allowedByExtension(filename) {
    const ext = filename.split('.').pop()?.toLowerCase()
    const allowedExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp3', 'wav', 'webm', 'ogg', 'mp4', 'mov', 'ogv', 'pdf', 'txt', 'csv', 'json', 'md', 'docx', 'xlsx', 'epub']
    return allowedExts.includes(ext)
  },

  isVideoExtension(filename) {
    const ext = filename.split('.').pop()?.toLowerCase()
    return ['mp4', 'mov', 'ogv', 'webm'].includes(ext)
  },

  async uploadFile(file) {
    const formData = new FormData()
    formData.append("file", file)

    try {
      const resp = await fetch("/api/chat/uploads", {
        method: "POST",
        body: formData
      })

      const result = await resp.json()

      if (!resp.ok) {
        alert(result.error || "Upload failed")
        return
      }

      this.insertFileMarkdown(result, file.name)
    } catch (e) {
      console.error("[CommentInput] Upload failed:", e)
      alert("Upload failed")
    }
  },

  insertFileMarkdown(result, originalName) {
    if (!this.textInput) return
    const start = this.textInput.selectionStart || 0
    const end = this.textInput.selectionEnd || 0
    const value = this.textInput.value

    let markdown = ""
    if (result.type === "image") {
      markdown = `![${originalName}](${result.path})`
    } else if (result.type === "audio") {
      markdown = `[🎤 ${originalName}](${result.path})`
    } else if (result.type === "video") {
      markdown = `[🎬 ${originalName}](${result.path})`
    } else {
      markdown = `[📎 ${originalName}](${result.path})`
    }

    const before = value.slice(0, start)
    const after = value.slice(end)
    const separator = before.length > 0 && !before.endsWith(" ") && !before.endsWith("\n") ? " " : ""

    this.textInput.value = before + separator + markdown + (after.length > 0 ? " " + after : "")
    this.textInput.focus()
    this.textInput.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
