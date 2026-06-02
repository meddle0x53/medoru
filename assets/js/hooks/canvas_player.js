const GRID_SIZES = {
  "line-small": 20,
  "line": 40,
  "line-large": 80,
}
const GRID_COLOR = "#e5e7eb"

function drawGrid(ctx, w, h, gridType) {
  if (!gridType || gridType === "none") return

  ctx.strokeStyle = GRID_COLOR
  ctx.fillStyle = GRID_COLOR
  ctx.lineWidth = 1

  const size = GRID_SIZES[gridType]
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
}

function drawStrokes(ctx, strokes) {
  for (const stroke of strokes) {
    if (stroke.points.length === 0) continue

    // Draw dot for single-point strokes
    if (stroke.points.length === 1) {
      const radius = Math.max(stroke.width / 2, 1)
      ctx.beginPath()
      ctx.arc(stroke.points[0].x, stroke.points[0].y, radius, 0, Math.PI * 2)
      if (stroke.tool === "eraser") {
        ctx.globalCompositeOperation = "destination-out"
        ctx.fillStyle = "rgba(0,0,0,0)"
      } else {
        ctx.globalCompositeOperation = "source-over"
        ctx.fillStyle = stroke.color
      }
      ctx.fill()
      continue
    }

    ctx.beginPath()
    ctx.moveTo(stroke.points[0].x, stroke.points[0].y)
    if (stroke.tool === "eraser") {
      ctx.globalCompositeOperation = "destination-out"
      ctx.lineWidth = stroke.width * 3
    } else {
      ctx.globalCompositeOperation = "source-over"
      ctx.strokeStyle = stroke.color
      ctx.lineWidth = stroke.width
    }
    for (let i = 1; i < stroke.points.length; i++) {
      ctx.lineTo(stroke.points[i].x, stroke.points[i].y)
    }
    ctx.stroke()
  }
  ctx.globalCompositeOperation = "source-over"
}

function finishDrawing(ctx, canvas, strokes, grid) {
  if (grid.keep && grid.type) {
    drawGrid(ctx, canvas.width, canvas.height, grid.type)
  }
  drawStrokes(ctx, strokes)
}

export default {
  mounted() {
    const container = this.el.querySelector(".canvas-player-container")
    if (!container) return

    const strokes = JSON.parse(this.el.dataset.strokes || "[]")
    const grid = JSON.parse(this.el.dataset.grid || "{}")
    const background = this.el.dataset.background

    const canvas = document.createElement("canvas")
    canvas.width = 600
    canvas.height = 500
    canvas.style.width = "100%"
    canvas.style.height = "100%"
    canvas.style.display = "block"
    container.appendChild(canvas)

    const ctx = canvas.getContext("2d")
    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    // White background + optional background image + optional grid + strokes
    ctx.fillStyle = "#ffffff"
    ctx.fillRect(0, 0, canvas.width, canvas.height)
    if (background) {
      const img = new Image()
      img.onload = () => {
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
        finishDrawing(ctx, canvas, strokes, grid)
      }
      img.onerror = () => {
        finishDrawing(ctx, canvas, strokes, grid)
      }
      img.src = background
    } else {
      finishDrawing(ctx, canvas, strokes, grid)
    }
  },

  destroyed() {
    const canvas = this.el.querySelector("canvas")
    if (canvas) canvas.remove()
  }
}
