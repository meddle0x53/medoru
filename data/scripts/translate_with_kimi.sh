#!/bin/bash
# Translate using Kimi Code CLI or direct API
# This script processes batches and saves progress

INPUT_FILE="${1:-../export/words.json}"
OUTPUT_FILE="${2:-../export/words_bg.json}"
BATCH_SIZE="${3:-100}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

echo "=== Medoru Bulgarian Translation ==="
echo "Input: $INPUT_FILE"
echo "Output: $OUTPUT_FILE"
echo "Batch size: $BATCH_SIZE"
echo ""

# Count total items
TOTAL=$(grep -c '"id"' "$INPUT_FILE" 2>/dev/null || echo "0")
echo "Total items to translate: $TOTAL"
echo ""

# Since we're in a Kimi Code environment, let's use a simpler approach
# Process the file in chunks and call Kimi for translation

cat << 'PYTHON_SCRIPT' > /tmp/translate_processor.py
import json
import sys

def split_json_array(input_file, output_prefix, chunk_size=100):
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    total = len(data)
    chunks = []
    
    for i in range(0, total, chunk_size):
        chunk = data[i:i+chunk_size]
        chunk_file = f"{output_prefix}_chunk_{i//chunk_size:04d}.json"
        
        with open(chunk_file, 'w', encoding='utf-8') as f:
            json.dump(chunk, f, ensure_ascii=False, indent=2)
        
        chunks.append(chunk_file)
        print(f"Created {chunk_file} with {len(chunk)} items")
    
    return chunks, total

if __name__ == "__main__":
    input_file = sys.argv[1]
    prefix = sys.argv[2]
    chunk_size = int(sys.argv[3]) if len(sys.argv) > 3 else 100
    
    chunks, total = split_json_array(input_file, prefix, chunk_size)
    print(f"\nSplit {total} items into {len(chunks)} chunks")
PYTHON_SCRIPT

# Split the input file into chunks
CHUNK_PREFIX="/tmp/translation_chunks"
python3 /tmp/translate_processor.py "$INPUT_FILE" "$CHUNK_PREFIX" "$BATCH_SIZE"

echo ""
echo "Chunks created in /tmp/translation_chunks_*.json"
echo ""
echo "Next step: Translate each chunk with Kimi"
echo "Run: for f in /tmp/translation_chunks_*.json; do kimi translate \"$f\"; done"
