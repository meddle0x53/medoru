#!/usr/bin/env python3
"""
Translate all N3 words using Facebook NLLB-200-1.3B
Good quality, resumable, saves progress every 500 words
"""

import json
import subprocess
import sys
from pathlib import Path
from datetime import datetime

def get_remaining_words():
    """Get all N3 words without Bulgarian translations"""
    print("📤 Fetching N3 words needing translation...")
    
    sql = """
    SELECT id, text, meaning 
    FROM words 
    WHERE difficulty = 3 
    AND (translations->'bg'->>'meaning' IS NULL OR translations->'bg'->>'meaning' = '')
    ORDER BY text;
    """
    
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-A", "-F", "|", "-c", sql],
        capture_output=True, text=True
    )
    
    words = []
    for line in result.stdout.strip().split("\n"):
        if "|" in line:
            parts = line.split("|")
            if len(parts) == 3:
                words.append({"id": parts[0], "text": parts[1], "meaning": parts[2]})
    
    print(f"   Found {len(words)} words to translate")
    return words

def main():
    print("=" * 70)
    print("🌐 N3 Translation with NLLB-200-1.3B (5GB)")
    print("=" * 70)
    print()
    
    # Dependencies
    try:
        from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
        import torch
        import psutil
    except ImportError:
        print("Installing dependencies...")
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "transformers", "torch", "sentencepiece", "psutil"])
        from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
        import torch
        import psutil
    
    # Check RAM
    ram_gb = psutil.virtual_memory().total / (1024**3)
    print(f"💾 RAM: {ram_gb:.1f}GB ✓")
    print()
    
    # Load model
    print("📦 Loading Facebook NLLB-200-1.3B...")
    print("   (Downloads ~5GB on first run, ~10 min)")
    print("   Loading into memory (takes 2-3 min)...")
    print()
    
    model_name = "facebook/nllb-200-1.3B"
    
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return
    
    device = torch.device("cpu")
    model = model.to(device)
    print(f"✅ Model loaded on {device}")
    print()
    
    # Bulgarian token ID
    bulgarian_id = 256033  # bul_Cyrl
    
    # Get words
    words = get_remaining_words()
    if not words:
        print("✅ All words already translated!")
        return
    
    print()
    
    # Progress tracking
    progress_file = Path("data/export/n3_nllb_progress.json")
    start_idx = 0
    
    if progress_file.exists():
        with open(progress_file) as f:
            saved = json.load(f)
            start_idx = len(saved)
            print(f"📂 Resuming from word {start_idx}")
    
    # Translate in chunks
    chunk_size = 500
    batch_size = 32
    total = len(words)
    start_time = datetime.now()
    
    for i in range(start_idx, total, chunk_size):
        chunk = words[i:i+chunk_size]
        print(f"\n🔄 Chunk {i//chunk_size + 1}/{(total+chunk_size-1)//chunk_size} ({len(chunk)} words)")
        
        # Translate this chunk
        translations = []
        for j in range(0, len(chunk), batch_size):
            batch = chunk[j:j+batch_size]
            texts = [w["meaning"] for w in batch]
            
            inputs = tokenizer(texts, return_tensors="pt", padding=True, truncation=True, max_length=512, src_lang="eng_Latn")
            inputs = {k: v.to(device) for k, v in inputs.items()}
            
            with torch.no_grad():
                tokens = model.generate(**inputs, forced_bos_token_id=bulgarian_id, max_length=128)
            
            batch_trans = tokenizer.batch_decode(tokens, skip_special_tokens=True)
            
            for word, trans in zip(batch, batch_trans):
                translations.append({"id": word["id"], "bg": trans})
            
            progress = min(j + batch_size, len(chunk))
            if progress % 100 == 0 or progress == len(chunk):
                print(f"   Progress: {progress}/{len(chunk)}")
        
        # Import to DB
        print("   Importing to database...")
        for t in translations:
            bg = t["bg"].replace("'", "''").replace("\\", "\\\\")
            sql = f"UPDATE words SET translations = COALESCE(translations, '{{}}') || '{{\"bg\": {{\"meaning\": \"{bg}\"}}}}'::jsonb WHERE id = '{t['id']}'::uuid;"
            subprocess.run(["psql", "-d", "medoru_dev", "-c", sql], capture_output=True)
        
        # Save progress
        if progress_file.exists():
            with open(progress_file) as f:
                saved = json.load(f)
        else:
            saved = []
        saved.extend(translations)
        with open(progress_file, 'w', encoding='utf-8') as f:
            json.dump(saved, f, ensure_ascii=False, indent=2)
        
        # Stats
        elapsed = (datetime.now() - start_time).total_seconds()
        done = i + len(chunk)
        rate = done / elapsed * 3600 if elapsed > 0 else 0  # words per hour
        remaining_hours = (total - done) / rate if rate > 0 else 0
        
        print(f"   Completed: {done}/{total} ({done/total*100:.1f}%)")
        print(f"   Rate: {rate:.0f} words/hour")
        print(f"   ETA: {remaining_hours:.1f} hours")
    
    # Cleanup
    if progress_file.exists():
        progress_file.unlink()
    
    print()
    print("=" * 70)
    print("✅ Translation complete!")
    print("=" * 70)

if __name__ == "__main__":
    main()
