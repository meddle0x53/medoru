// Kanji Recognizer Bundle - Combined from https://github.com/mxggle/kanji-recognizer
// Licensed under MIT License

// GeometryUtil.js
class GeometryUtil {
    static resample(points, n) {
        if (points.length < 2) return points;
        
        const interval = this.pathLength(points) / (n - 1);
        let D = 0;
        const newPoints = [points[0]];
        
        for (let i = 1; i < points.length; i++) {
            const d = this.distance(points[i - 1], points[i]);
            if (D + d >= interval) {
                const q = {
                    x: points[i - 1].x + ((interval - D) / d) * (points[i].x - points[i - 1].x),
                    y: points[i - 1].y + ((interval - D) / d) * (points[i].y - points[i - 1].y)
                };
                newPoints.push(q);
                points.splice(i, 0, q);
                D = 0;
            } else {
                D += d;
            }
        }
        
        while (newPoints.length < n) {
            newPoints.push(points[points.length - 1]);
        }
        
        return newPoints;
    }

    static pathLength(points) {
        let d = 0;
        for (let i = 1; i < points.length; i++) {
            d += this.distance(points[i - 1], points[i]);
        }
        return d;
    }

    static distance(p1, p2) {
        return Math.sqrt(Math.pow(p1.x - p2.x, 2) + Math.pow(p1.y - p2.y, 2));
    }

    static centroid(points) {
        let x = 0, y = 0;
        for (const p of points) {
            x += p.x;
            y += p.y;
        }
        return { x: x / points.length, y: y / points.length };
    }

    static translateTo(points, centroid) {
        return points.map(p => ({
            x: p.x - centroid.x,
            y: p.y - centroid.y
        }));
    }

    static scaleTo(points, size) {
        const box = this.boundingBox(points);
        const scale = size / Math.max(box.width, box.height);
        return points.map(p => ({
            x: p.x * scale,
            y: p.y * scale
        }));
    }

    static boundingBox(points) {
        let minX = Infinity, minY = Infinity;
        let maxX = -Infinity, maxY = -Infinity;
        
        for (const p of points) {
            minX = Math.min(minX, p.x);
            minY = Math.min(minY, p.y);
            maxX = Math.max(maxX, p.x);
            maxY = Math.max(maxY, p.y);
        }
        
        return {
            minX, minY, maxX, maxY,
            width: maxX - minX,
            height: maxY - minY
        };
    }
}

// StrokeRecognizer.js
class StrokeRecognizer {
    constructor(options = {}) {
        this.options = {
            resamplePoints: 32,
            passThreshold: 15,
            startDistThreshold: 40,
            lengthRatioMin: 0.5,
            lengthRatioMax: 1.5,
            ...options
        };
    }

    recognize(userStroke, templateStroke) {
        // Check start point distance
        const startDist = GeometryUtil.distance(userStroke[0], templateStroke[0]);
        if (startDist > this.options.startDistThreshold) {
            return { success: false, error: 'start_point' };
        }

        // Check stroke length ratio
        const userLen = GeometryUtil.pathLength(userStroke);
        const templateLen = GeometryUtil.pathLength(templateStroke);
        const ratio = userLen / templateLen;
        
        if (ratio < this.options.lengthRatioMin || ratio > this.options.lengthRatioMax) {
            return { success: false, error: 'length' };
        }

        // Resample and normalize
        const userNorm = this.normalize(userStroke);
        const templateNorm = this.normalize(templateStroke);

        // Calculate average distance
        let totalDist = 0;
        for (let i = 0; i < userNorm.length; i++) {
            totalDist += GeometryUtil.distance(userNorm[i], templateNorm[i]);
        }
        const avgDist = totalDist / userNorm.length;

        return {
            success: avgDist < this.options.passThreshold,
            distance: avgDist
        };
    }

    normalize(points) {
        let result = GeometryUtil.resample(points, this.options.resamplePoints);
        const centroid = GeometryUtil.centroid(result);
        result = GeometryUtil.translateTo(result, centroid);
        result = GeometryUtil.scaleTo(result, 100);
        return result;
    }
}

// KanjiVGParser.js
class KanjiVGParser {
    static parse(svgContent) {
        const paths = [];
        const pathRegex = /<path[^>]*d="([^"]*)"[^>]*>/g;
        let match;
        
        while ((match = pathRegex.exec(svgContent)) !== null) {
            paths.push(match[1]);
        }
        
        return paths;
    }

    static parsePath(pathData) {
        const points = [];
        const commands = pathData.match(/[MmLlHhVvCcSsQqTtAaZz][^MmLlHhVvCcSsQqTtAaZz]*/g) || [];
        
        let currentX = 0, currentY = 0;
        
        for (const cmd of commands) {
            const type = cmd[0].toUpperCase();
            const isRelative = cmd[0] !== type;
            const args = cmd.slice(1).trim().split(/[\s,]+/).filter(s => s).map(parseFloat);
            
            switch (type) {
                case 'M':
                    currentX = isRelative ? currentX + args[0] : args[0];
                    currentY = isRelative ? currentY + args[1] : args[1];
                    points.push({x: currentX, y: currentY});
                    break;
                case 'L':
                    currentX = isRelative ? currentX + args[0] : args[0];
                    currentY = isRelative ? currentY + args[1] : args[1];
                    points.push({x: currentX, y: currentY});
                    break;
                case 'C':
                    // For cubic bezier, sample points
                    for (let i = 0; i <= 10; i++) {
                        const t = i / 10;
                        const x = this.cubicBezier(t, currentX, args[0], args[2], args[4]);
                        const y = this.cubicBezier(t, currentY, args[1], args[3], args[5]);
                        points.push({x, y});
                    }
                    currentX = isRelative ? currentX + args[4] : args[4];
                    currentY = isRelative ? currentY + args[5] : args[5];
                    break;
            }
        }
        
        return points;
    }

    static cubicBezier(t, p0, p1, p2, p3) {
        const u = 1 - t;
        return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3;
    }
}

// KanjiWriter.js
class KanjiWriter {
    constructor(elementId, kanjiData, options = {}) {
        this.container = typeof elementId === 'string' 
            ? document.getElementById(elementId) 
            : elementId;
        
        if (!this.container) {
            throw new Error(`Element not found: ${elementId}`);
        }

        this.kanjiData = kanjiData; // Array of SVG path strings
        this.currentStroke = 0;
        this.userStrokes = [];
        this.isDrawing = false;
        this.currentPath = [];

        this.options = {
            width: 300,
            height: 300,
            strokeColor: "#333",
            correctColor: "#4CAF50",
            incorrectColor: "#F44336",
            hintColor: "cyan",
            gridColor: "#ddd",
            ghostColor: "#ff0000",
            showGhost: true,
            showGrid: true,
            checkMode: 'stroke', // 'stroke', 'full', or 'free'
            strokeWidth: 4,
            gridWidth: 0.5,
            ghostOpacity: "0.1",
            passThreshold: 15,
            startDistThreshold: 40,
            lengthRatioMin: 0.5,
            lengthRatioMax: 1.5,
            ...options
        };

        this.recognizer = new StrokeRecognizer({
            passThreshold: this.options.passThreshold,
            startDistThreshold: this.options.startDistThreshold,
            lengthRatioMin: this.options.lengthRatioMin,
            lengthRatioMax: this.options.lengthRatioMax
        });

        this.init();
    }

    init() {
        this.createSVG();
        this.setupEventListeners();
        this.drawGrid();
        if (this.options.showGhost && this.kanjiData[this.currentStroke]) {
            this.drawGhost();
        }
    }

    createSVG() {
        this.svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
        this.svg.setAttribute("width", this.options.width);
        this.svg.setAttribute("height", this.options.height);
        this.svg.setAttribute("viewBox", "0 0 109 109");
        this.svg.style.cursor = "crosshair";
        this.svg.style.touchAction = "none";
        this.container.appendChild(this.svg);
    }

    drawGrid() {
        if (!this.options.showGrid) return;

        const gridGroup = document.createElementNS("http://www.w3.org/2000/svg", "g");
        gridGroup.setAttribute("stroke", this.options.gridColor);
        gridGroup.setAttribute("stroke-width", this.options.gridWidth);

        // Diagonal lines
        const d1 = document.createElementNS("http://www.w3.org/2000/svg", "line");
        d1.setAttribute("x1", 0); d1.setAttribute("y1", 0);
        d1.setAttribute("x2", 109); d1.setAttribute("y2", 109);
        gridGroup.appendChild(d1);

        const d2 = document.createElementNS("http://www.w3.org/2000/svg", "line");
        d2.setAttribute("x1", 109); d2.setAttribute("y1", 0);
        d2.setAttribute("x2", 0); d2.setAttribute("y2", 109);
        gridGroup.appendChild(d2);

        // Center cross
        const h = document.createElementNS("http://www.w3.org/2000/svg", "line");
        h.setAttribute("x1", 0); h.setAttribute("y1", 54.5);
        h.setAttribute("x2", 109); h.setAttribute("y2", 54.5);
        gridGroup.appendChild(h);

        const v = document.createElementNS("http://www.w3.org/2000/svg", "line");
        v.setAttribute("x1", 54.5); v.setAttribute("y1", 0);
        v.setAttribute("x2", 54.5); v.setAttribute("y2", 109);
        gridGroup.appendChild(v);

        this.svg.appendChild(gridGroup);
        this.gridGroup = gridGroup;
    }

    drawGhost() {
        if (this.ghostPath) {
            this.ghostPath.remove();
        }

        const pathData = this.kanjiData[this.currentStroke];
        if (!pathData) return;

        this.ghostPath = document.createElementNS("http://www.w3.org/2000/svg", "path");
        this.ghostPath.setAttribute("d", pathData);
        this.ghostPath.setAttribute("fill", "none");
        this.ghostPath.setAttribute("stroke", this.options.ghostColor);
        this.ghostPath.setAttribute("stroke-width", this.options.strokeWidth);
        this.ghostPath.setAttribute("stroke-opacity", this.options.ghostOpacity);
        this.ghostPath.setAttribute("stroke-linecap", "round");
        this.ghostPath.setAttribute("stroke-linejoin", "round");
        
        this.svg.insertBefore(this.ghostPath, this.svg.firstChild);
    }

    setupEventListeners() {
        const start = (e) => this.startStroke(e);
        const move = (e) => this.moveStroke(e);
        const end = () => this.endStroke();

        this.svg.addEventListener('pointerdown', start);
        this.svg.addEventListener('pointermove', move);
        this.svg.addEventListener('pointerup', end);
        this.svg.addEventListener('pointerleave', end);
    }

    getPoint(e) {
        const rect = this.svg.getBoundingClientRect();
        const scaleX = 109 / rect.width;
        const scaleY = 109 / rect.height;
        return {
            x: (e.clientX - rect.left) * scaleX,
            y: (e.clientY - rect.top) * scaleY
        };
    }

    startStroke(e) {
        e.preventDefault();
        this.isDrawing = true;
        this.currentPath = [this.getPoint(e)];
    }

    moveStroke(e) {
        if (!this.isDrawing) return;
        e.preventDefault();
        this.currentPath.push(this.getPoint(e));
        this.renderCurrentPath();
    }

    endStroke() {
        if (!this.isDrawing) return;
        this.isDrawing = false;

        if (this.options.checkMode === 'free') {
            this.userStrokes.push(this.currentPath);
            this.finalizeStroke();
            return;
        }

        const templatePath = this.kanjiData[this.currentStroke];
        if (!templatePath) return;

        const templatePoints = KanjiVGParser.parsePath(templatePath);
        const result = this.recognizer.recognize(this.currentPath, templatePoints);

        if (result.success) {
            this.userStrokes.push(this.currentPath);
            this.finalizeStroke(true);
            this.onCorrect?.();
            
            this.currentStroke++;
            if (this.currentStroke >= this.kanjiData.length) {
                this.onComplete?.();
            } else if (this.options.showGhost) {
                this.drawGhost();
            }
        } else {
            this.finalizeStroke(false);
            this.onIncorrect?.(result);
        }

        this.currentPath = [];
    }

    renderCurrentPath() {
        if (this.tempPath) {
            this.tempPath.remove();
        }

        const d = this.pathToSVG(this.currentPath);
        this.tempPath = document.createElementNS("http://www.w3.org/2000/svg", "path");
        this.tempPath.setAttribute("d", d);
        this.tempPath.setAttribute("fill", "none");
        this.tempPath.setAttribute("stroke", this.options.strokeColor);
        this.tempPath.setAttribute("stroke-width", this.options.strokeWidth);
        this.tempPath.setAttribute("stroke-linecap", "round");
        this.tempPath.setAttribute("stroke-linejoin", "round");
        
        this.svg.appendChild(this.tempPath);
    }

    finalizeStroke(correct) {
        if (this.tempPath) {
            this.tempPath.setAttribute("stroke", correct ? this.options.strokeColor : this.options.incorrectColor);
            this.tempPath = null;
        }
    }

    pathToSVG(points) {
        if (points.length === 0) return "";
        return "M " + points.map(p => `${p.x},${p.y}`).join(" L ");
    }

    clear() {
        this.userStrokes = [];
        this.currentStroke = 0;
        this.currentPath = [];
        this.isDrawing = false;
        
        while (this.svg.lastChild && this.svg.lastChild !== this.gridGroup) {
            this.svg.removeChild(this.svg.lastChild);
        }
        
        if (this.ghostPath) {
            this.ghostPath.remove();
            this.ghostPath = null;
        }
        
        if (this.options.showGhost && this.kanjiData[0]) {
            this.drawGhost();
        }
        
        this.onClear?.();
    }

    destroy() {
        this.svg.remove();
    }

    // Event callbacks
    onCorrect() {}
    onIncorrect(result) {}
    onComplete() {}
    onClear() {}
}

// Export for module use
export { KanjiWriter, StrokeRecognizer, GeometryUtil, KanjiVGParser };
