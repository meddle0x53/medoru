const COLORS = [
  "#000000", "#ef4444", "#f97316", "#eab308",
  "#22c55e", "#3b82f6", "#a855f7", "#ec4899"
]

const DEFAULT_WIDTH = 600
const DEFAULT_HEIGHT = 500
const GRID_SIZES = {
  "line-small": 20,
  "line": 40,
  "line-large": 80,
}
const GRID_COLOR = "#e5e7eb"

export default {
  mounted() {
    this.strokes = []
    this.currentStroke = null
    this.tool = "pencil"
    this.color = COLORS[0]
    this.lineWidth = 3
    this.isDrawing = false
    this.lastPt = null
    this.gridType = "none"
    this.keepGrid = false
    this.backgroundImage = null
    this.backgroundDataUrl = null

    this.container = this.el.querySelector(".free-draw-canvas-container")
    if (!this.container) {
      console.error("[FreeDraw] Canvas container not found")
      return
    }

    this.canvas = document.createElement("canvas")
    this.canvas.width = DEFAULT_WIDTH
    this.canvas.height = DEFAULT_HEIGHT
    this.canvas.style.width = "100%"
    this.canvas.style.height = "100%"
    this.canvas.style.display = "block"
    this.canvas.style.touchAction = "none"
    this.canvas.style.userSelect = "none"
    this.canvas.style.webkitUserSelect = "none"
    this.container.appendChild(this.canvas)

    this.ctx = this.canvas.getContext("2d")
    this.ctx.lineCap = "round"
    this.ctx.lineJoin = "round"

    this.drawBackground()
    this.canvas.style.cursor = "crosshair"

    this.bindEvents()
    this.bindToolbar()
  },

  destroyed() {
    if (this.canvas) {
      this.canvas.remove()
    }
  },

  getPoint(e) {
    const rect = this.canvas.getBoundingClientRect()
    const scaleX = this.canvas.width / rect.width
    const scaleY = this.canvas.height / rect.height
    return {
      x: (e.clientX - rect.left) * scaleX,
      y: (e.clientY - rect.top) * scaleY
    }
  },

  setCtxStyle() {
    if (this.tool === "eraser") {
      this.canvas.style.cursor = "cell"
      this.ctx.globalCompositeOperation = "destination-out"
      this.ctx.lineWidth = this.lineWidth * 3
    } else {
      this.canvas.style.cursor = "crosshair"
      this.ctx.globalCompositeOperation = "source-over"
      this.ctx.strokeStyle = this.color
      this.ctx.lineWidth = this.lineWidth
    }
  },

  drawDot(pt) {
    const radius = Math.max(this.lineWidth / 2, 1)
    this.ctx.beginPath()
    this.ctx.arc(pt.x, pt.y, radius, 0, Math.PI * 2)
    this.ctx.fillStyle = this.tool === "eraser" ? "rgba(0,0,0,0)" : this.color
    this.ctx.fill()
  },

  drawGrid(ctx, w, h) {
    if (this.gridType === "none") return

    ctx.strokeStyle = GRID_COLOR
    ctx.fillStyle = GRID_COLOR
    ctx.lineWidth = 1

    const size = GRID_SIZES[this.gridType]
    if (size) {
      ctx.beginPath()
      for (let x = size; x < w; x += size) {
        ctx.moveTo(x, 0)
        ctx.lineTo(x, h)
      }
      for (let y = size; y < h; y += size) {
        ctx.moveTo(0, y)
        ctx.lineTo(w, y)
      }
      ctx.stroke()
    }
  },

  drawBackground() {
    this.ctx.globalCompositeOperation = "source-over"
    this.ctx.fillStyle = "#ffffff"
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height)
    this.drawBackgroundImage(this.ctx, this.canvas.width, this.canvas.height)
    this.drawGrid(this.ctx, this.canvas.width, this.canvas.height)
  },

  drawBackgroundImage(ctx, w, h) {
    if (this.backgroundImage && this.backgroundImage.complete) {
      ctx.drawImage(this.backgroundImage, 0, 0, w, h)
    }
  },

  loadBackgroundImage(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = (e) => {
        const dataUrl = e.target.result
        const img = new Image()
        img.onload = () => {
          this.backgroundImage = img
          this.backgroundDataUrl = dataUrl
          this.redraw()
          resolve(dataUrl)
        }
        img.onerror = reject
        img.src = dataUrl
      }
      reader.onerror = reject
      reader.readAsDataURL(file)
    })
  },

  clearBackgroundImage() {
    this.backgroundImage = null
    this.backgroundDataUrl = null
    const input = this.el.querySelector("[data-draw-background-input]")
    if (input) input.value = ""
    this.redraw()
  },

  bindEvents() {
    this.canvas.addEventListener("pointerdown", (e) => {
      e.preventDefault()
      this.isDrawing = true
      const pt = this.getPoint(e)
      this.lastPt = pt
      this.currentStroke = {
        tool: this.tool,
        color: this.color,
        width: this.lineWidth,
        points: [pt]
      }
      this.setCtxStyle()
      this.drawDot(pt)
    })

    this.canvas.addEventListener("pointermove", (e) => {
      if (!this.isDrawing) return
      e.preventDefault()
      const pt = this.getPoint(e)
      this.currentStroke.points.push(pt)

      this.setCtxStyle()
      this.ctx.beginPath()
      this.ctx.moveTo(this.lastPt.x, this.lastPt.y)
      this.ctx.lineTo(pt.x, pt.y)
      this.ctx.stroke()

      this.lastPt = pt
    })

    this.canvas.addEventListener("pointerup", (e) => {
      if (!this.isDrawing) return
      e.preventDefault()
      this.isDrawing = false
      this.strokes.push(this.currentStroke)
      this.currentStroke = null
      this.lastPt = null
      this.ctx.globalCompositeOperation = "source-over"
    })

    this.canvas.addEventListener("pointerleave", (e) => {
      if (this.isDrawing) {
        this.isDrawing = false
        this.strokes.push(this.currentStroke)
        this.currentStroke = null
        this.lastPt = null
        this.ctx.globalCompositeOperation = "source-over"
      }
    })
  },

  bindToolbar() {
    // Tool buttons
    this.el.querySelectorAll("[data-draw-tool]").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault()
        this.tool = btn.dataset.drawTool
        this.el.querySelectorAll("[data-draw-tool]").forEach((b) =>
          b.classList.remove("active-tool")
        )
        btn.classList.add("active-tool")
      })
    })

    // Color buttons
    this.el.querySelectorAll("[data-draw-color]").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault()
        this.color = btn.dataset.drawColor
        this.tool = "pencil"
        this.el.querySelectorAll("[data-draw-color]").forEach((b) =>
          b.classList.remove("ring-2", "ring-offset-2", "ring-base-content")
        )
        btn.classList.add("ring-2", "ring-offset-2", "ring-base-content")
        this.el.querySelectorAll("[data-draw-tool]").forEach((b) =>
          b.classList.remove("active-tool")
        )
        const pencilBtn = this.el.querySelector('[data-draw-tool="pencil"]')
        if (pencilBtn) pencilBtn.classList.add("active-tool")
      })
    })

    // Grid buttons
    this.el.querySelectorAll("[data-draw-grid]").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault()
        this.gridType = btn.dataset.drawGrid
        this.el.querySelectorAll("[data-draw-grid]").forEach((b) =>
          b.classList.remove("btn-active")
        )
        btn.classList.add("btn-active")
        this.redraw()
      })
    })

    // Keep grid checkbox
    const keepGridCheckbox = this.el.querySelector("[data-draw-keep-grid]")
    if (keepGridCheckbox) {
      keepGridCheckbox.addEventListener("change", (e) => {
        this.keepGrid = e.target.checked
      })
    }

    // Line width
    const widthInput = this.el.querySelector("[data-draw-width]")
    if (widthInput) {
      widthInput.addEventListener("input", () => {
        this.lineWidth = parseInt(widthInput.value, 10)
      })
    }

    // Undo
    const undoBtn = this.el.querySelector('[data-draw-action="undo"]')
    if (undoBtn) {
      undoBtn.addEventListener("click", (e) => {
        e.preventDefault()
        this.undo()
      })
    }

    // Clear
    const clearBtn = this.el.querySelector('[data-draw-action="clear"]')
    if (clearBtn) {
      clearBtn.addEventListener("click", (e) => {
        e.preventDefault()
        this.clear()
      })
    }

    // Background image upload
    const bgInput = this.el.querySelector("[data-draw-background-input]")
    if (bgInput) {
      bgInput.addEventListener("change", (e) => {
        const file = e.target.files[0]
        if (file) {
          this.loadBackgroundImage(file).catch(() => {
            alert("Could not load image")
          })
        }
      })
    }

    const clearBgBtn = this.el.querySelector('[data-draw-action="clear-background"]')
    if (clearBgBtn) {
      clearBgBtn.addEventListener("click", (e) => {
        e.preventDefault()
        this.clearBackgroundImage()
      })
    }

    // Post canvas
    const postBtn = this.el.querySelector('[data-draw-action="post"]')
    if (postBtn) {
      postBtn.addEventListener("click", (e) => {
        e.preventDefault()
        const payload = { strokes: this.strokes }
        if (this.keepGrid && this.gridType !== "none") {
          payload.grid = { type: this.gridType, keep: true }
        }
        if (this.backgroundDataUrl) {
          payload.background = this.backgroundDataUrl
        }
        this.pushEvent("save_canvas", payload)
      })
    }
  },

  undo() {
    if (this.strokes.length === 0) return
    this.strokes.pop()
    this.redraw()
  },

  clear() {
    this.strokes = []
    this.drawBackground()
  },

  redraw() {
    this.drawBackground()

    for (const stroke of this.strokes) {
      if (stroke.points.length === 0) continue

      // Draw dot for single-point strokes
      if (stroke.points.length === 1) {
        const radius = Math.max(stroke.width / 2, 1)
        this.ctx.beginPath()
        this.ctx.arc(stroke.points[0].x, stroke.points[0].y, radius, 0, Math.PI * 2)
        if (stroke.tool === "eraser") {
          this.ctx.globalCompositeOperation = "destination-out"
          this.ctx.fillStyle = "rgba(0,0,0,0)"
        } else {
          this.ctx.globalCompositeOperation = "source-over"
          this.ctx.fillStyle = stroke.color
        }
        this.ctx.fill()
        continue
      }

      this.ctx.beginPath()
      this.ctx.moveTo(stroke.points[0].x, stroke.points[0].y)

      if (stroke.tool === "eraser") {
        this.ctx.globalCompositeOperation = "destination-out"
        this.ctx.lineWidth = stroke.width * 3
      } else {
        this.ctx.globalCompositeOperation = "source-over"
        this.ctx.strokeStyle = stroke.color
        this.ctx.lineWidth = stroke.width
      }

      for (let i = 1; i < stroke.points.length; i++) {
        this.ctx.lineTo(stroke.points[i].x, stroke.points[i].y)
      }
      this.ctx.stroke()
    }

    this.ctx.globalCompositeOperation = "source-over"
  }
}
