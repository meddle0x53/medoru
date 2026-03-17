#!/usr/bin/env python3
"""
Simplified N3 translation with immediate progress feedback
Processes words directly without intermediate JSON files
"""

import subprocess
import sys
from pathlib import Path

def get_total_count():
    """Get total N3 words to translate"""
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-A", "-c", 
         "SELECT COUNT(*) FROM words WHERE difficulty = 3 AND translations->>'bg' IS NULL;"],
        capture_output=True, text=True
    )
    return int(result.stdout.strip())

def get_translated_count():
    """Get count of translated words"""
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-A", "-c",
         "SELECT COUNT(*) FROM words WHERE difficulty = 3 AND translations->>'bg' IS NOT NULL;"],
        capture_output=True, text=True
    )
    return int(result.stdout.strip())

def fetch_batch(batch_size=25):
    """Fetch a batch of untranslated words"""
    sql = f"""
    SELECT id, text, meaning 
    FROM words 
    WHERE difficulty = 3 AND translations->>'bg' IS NULL
    ORDER BY text
    LIMIT {batch_size};
    """
    
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-A", "-F", "|", "-c", sql],
        capture_output=True, text=True
    )
    
    words = []
    for line in result.stdout.strip().split("\n"):
        if line:
            parts = line.split("|")
            if len(parts) == 3:
                words.append({"id": parts[0], "text": parts[1], "meaning": parts[2]})
    return words

def translate_batch(words, tokenizer, model, device):
    """Translate a batch of words"""
    import torch
    
    texts = [w["meaning"] for w in words]
    
    # Tokenize
    inputs = tokenizer(texts, return_tensors="pt", padding=True, truncation=True, max_length=512)
    inputs = {k: v.to(device) for k, v in inputs.items()}
    
    # Translate
    with torch.no_grad():
        translated_tokens = model.generate(**inputs)
    
    # Decode
    translations = tokenizer.batch_decode(translated_tokens, skip_special_tokens=True)
    
    return list(zip(words, translations))

def update_database(translations):
    """Update database with translations"""
    sql_parts = []
    for word, trans in translations:
        escaped = trans.replace("'", "''")
        sql_parts.append(
            f"UPDATE words SET translations = COALESCE(translations, '{{}}') || '{{\"bg\": {{\"meaning\": \"{escaped}\"}}}}'::jsonb WHERE id = '{word['id']}';"
        )
    
    sql = "\n".join(sql_parts)
    subprocess.run(["psql", "-d", "medoru_dev", "-c", sql], capture_output=True)

def main():
    print("🤖 N3 Translation - Direct to Database")
    print("=" * 60)
    
    # Check dependencies
    try:
        from transformers import MarianMTModel, MarianTokenizer
        import torch
    except ImportError:
        print("❌ Install dependencies: pip install transformers torch sentencepiece sacremoses")
        sys.exit(1)
    
    # Load model
    print("\n📦 Loading Helsinki-NLP/opus-mt-en-bg model...")
    print("   (One-time 300MB download)")
    model_name = "Helsinki-NLP/opus-mt-en-bg"
    tokenizer = MarianTokenizer.from_pretrained(model_name)
    model = MarianMTModel.from_pretrained(model_name)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    print(f"   ✅ Model loaded on {device}")
    
    # Get initial counts
    total = get_total_count() + get_translated_count()
    initial_done = get_translated_count()
    
    print(f"\n📊 Total N3 words: {total}")
    print(f"   Already translated: {initial_done}")
    print(f"   Remaining: {total - initial_done}")
    print(f"\n🚀 Starting translation...")
    print("-" * 60)
    
    batch_size = 25  # Smaller batches for more frequent updates
    batch_num = 0
    
    while True:
        # Fetch batch
        words = fetch_batch(batch_size)
        
        if not words:
            break
        
        # Translate
        translations = translate_batch(words, tokenizer, model, device)
        
        # Update database
        update_database(translations)
        
        # Progress
        batch_num += 1
        done = get_translated_count()
        percent = (done / total) * 100
        
        print(f"Batch {batch_num:4d}: {done:6d}/{total} ({percent:5.1f}%) - {len(words)} words")
    
    print("-" * 60)
    print(f"✅ Complete! Translated {get_translated_count()} words")

if __name__ == "__main__":
    main()
