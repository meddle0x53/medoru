#!/bin/bash

# Complete N3 Re-translation Script
# Re-translates ALL 135,847 N3 words for uniform quality

set -e

echo "🌐 Complete N3 Re-translation (135,847 words)"
echo "=============================================="
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3."
    exit 1
fi

# Check/create virtual environment
VENV_DIR=".venv_translation"

if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Install dependencies if needed
if ! python3 -c "import transformers" 2>/dev/null; then
    echo "📦 Installing dependencies (this may take a few minutes)..."
    pip install -q transformers torch sentencepiece sacremoses
    echo "✅ Dependencies installed"
fi

# Run the re-translation
python3 bin/retranslate_all_n3.py "$@"

# Deactivate virtual environment
deactivate
