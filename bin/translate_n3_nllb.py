#!/usr/bin/env python3
"""
Translate all N3 words using Facebook NLLB-200-3.3B
High quality, resumable, saves progress every 500 words
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

def translate_batch(model, tokenizer, device, words, batch_size=32):
    """Translate a batch of words"""
    from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
    import torch
    
    results = []
    total = len(words)
    
    for i in range(0, total, batch_size):
        batch = words[i:i+batch_size]
        texts = [w["meaning"] for w in batch]
        
        # Tokenize
        inputs = tokenizer(
            texts,
            return_tensors="pt",
            padding=True,
            truncation=True,
            max_length=512,
            src_lang="eng_Latn"
        )
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        # Translate
        with torch.no_grad():
            tokens = model.generate(
                **inputs,
                forced_bos_token_id=tokenizer.lang_code_to_id["bul_Cyrl"]
            )
        
        # Decode
        translations = tokenizer.batch_decode(tokens, skip_special_tokens=True)
        
        # Store
        for word, trans in zip(batch, translations):
            results.append({
                "id": word["id"],
                "text": word["text"],
                "en": word["meaning"],
                "bg": trans
            })
        
        # Progress
        progress = min(i + batch_size, total)
        if progress % 100 == 0 or progress == total:
            print(f"   Translated: {progress}/{total} ({progress/total*100:.1f}%)")
    
    return results

def import_to_db(translations, batch_size=100):
    """Import translations to database"""
    print("📥 Importing to database...")
    
    total = len(translations)
    for i in range(0, total, batch_size):
        batch = translations[i:i+batch_size]
        
        sql_parts = []
        for t in batch:
            bg = t["bg"].replace("'", "''").replace("\\", "\\\\")
            sql_parts.append(
                f"UPDATE words SET translations = COALESCE(translations, '{{}}') || '{{\"bg\": {{\"meaning\": \"{bg}\"}}}}'::jsonb WHERE id = '{t['id']}'::uuid;"
            )
        
        sql = "\n".join(sql_parts)
        subprocess.run(
            ["psql", "-d", "medoru_dev", "-c", sql],
            capture_output=True
        )
        
        progress = min(i + batch_size, total)
        if progress % 500 == 0 or progress == total:
            print(f"   Imported: {progress}/{total}")

def main():
    print("=" * 70)
    print("🌐 N3 Translation with NLLB-200-3.3B")
    print("=" * 70)
    print()
    print("This will translate ALL remaining N3 words.")
    print("Estimated time: 6-8 hours for 135K words")
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
    
    # RAM check
    ram_gb = psutil.virtual_memory().total / (1024**3)
    print(f"💾 RAM: {ram_gb:.1f}GB")
    if ram_gb < 14:
        print()
        print("⚠️  WARNING: NLLB-3.3B needs ~12-16GB RAM")
        print("   You have {:.1f}GB which may be insufficient".format(ram_gb))
        print()
        print("Options:")
        print("  1. Use NLLB-200-1.3B (5GB, good quality)")
        print("     Edit this script: change model_name to 'facebook/nllb-200-1.3B'")
        print()
        print("  2. Close other applications and try anyway")
        print()
        confirm = input("Continue? (yes/no): ")
        if confirm.lower() != "yes":
            return
    
    # Load model
    print()
    print("📦 Loading Facebook NLLB-200-3.3B...")
    print("   (Downloads ~13GB on first run)")
    print()
    
    model_name = "facebook/nllb-200-3.3B"
    
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    except Exception as e:
        print(f"❌ Error loading model: {e}")
        print("   Try: pip install transformers==4.35.0 sentencepiece")
        return
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    print(f"✅ Model loaded on {device}")
    print()
    
    # Get words
    words = get_remaining_words()
    if not words:
        print("✅ All words already translated!")
        return
    
    print()
    
    # Progress file
    progress_file = Path("data/export/n3_nllb_progress.json")
    start_idx = 0
    
    if progress_file.exists():
        with open(progress_file) as f:
            saved = json.load(f)
            start_idx = len(saved)
            print(f"📂 Resuming from word {start_idx}")
    
    # Translate in chunks
    chunk_size = 500
    total = len(words)
    start_time = datetime.now()
    
    for i in range(start_idx, total, chunk_size):
        chunk = words[i:i+chunk_size]
        print(f"\n🔄 Chunk {i//chunk_size + 1}/{(total+chunk_size-1)//chunk_size} ({len(chunk)} words)")
        
        # Translate
        translations = translate_batch(model, tokenizer, device, chunk, batch_size=32)
        
        # Import
        import_to_db(translations)
        
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
        rate = (i + len(chunk)) / elapsed * 60 if elapsed > 0 else 0
        remaining = (total - i - len(chunk)) / rate * 60 if rate > 0 else 0
        
        print(f"   Rate: {rate:.0f} words/min")
        print(f"   ETA: {remaining/60:.1f} hours remaining")
    
    # Cleanup
    if progress_file.exists():
        progress_file.unlink()
    
    print()
    print("=" * 70)
    print("✅ Translation complete!")
    print("=" * 70)

if __name__ == "__main__":
    main()
