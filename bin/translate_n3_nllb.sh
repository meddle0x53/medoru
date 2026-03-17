#!/bin/bash

# N3 Translation with Facebook NLLB-200-3.3B (High Quality)
# Uses 12-16GB RAM for much better translations

set -e

echo "🌐 N3 High-Quality Translation (Facebook NLLB-200-3.3B)"
echo "========================================================"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found"
    exit 1
fi

# Check RAM
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
echo "💾 Available RAM: ${RAM_GB}GB"

if [ "$RAM_GB" -lt 16 ]; then
    echo "⚠️  Warning: Less than 16GB RAM. NLLB-3.3B may not work well."
    echo "   Consider using smaller model or API-based translation."
    read -p "Continue anyway? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        exit 0
    fi
fi

# Setup virtual environment
VENV_DIR=".venv_nllb"

if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# Install dependencies
if ! python3 -c "import transformers" 2>/dev/null; then
    echo "📦 Installing dependencies..."
    pip install -q transformers torch sentencepiece psutil
fi

echo ""
echo "🚀 Starting translation with NLLB-200-3.3B..."
echo "   This model is ~13GB and provides excellent quality"
echo ""

# Run translation
python3 bin/translate_n3_nllb.py "$@"
