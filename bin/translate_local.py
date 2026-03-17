#!/usr/bin/env python3
"""
Local English→Bulgarian translation using Helsinki-NLP/opus-mt-en-bg
Free, private, runs entirely on your machine

Setup:
    pip install transformers torch sentencepiece sacremoses

Usage:
    python bin/translate_local.py
"""

import json
import subprocess
import sys
from pathlib import Path

def check_dependencies():
    """Check if required packages are installed"""
    try:
        import transformers
        import torch
        return True
    except ImportError:
        print("❌ Missing dependencies. Install with:")
        print("   pip install transformers torch sentencepiece sacremoses")
        return False

def export_untranslated():
    """Export words with English placeholders"""
    print("📤 Exporting untranslated words...")
    
    sql = """
    SELECT id, text, meaning 
    FROM words 
    WHERE difficulty = 3 AND translations->'bg'->>'meaning' = meaning
    ORDER BY text;
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
                id, text, meaning = parts
                words.append({"id": id, "text": text, "meaning": meaning})
    
    output_file = Path("data/export/n3_to_translate.json")
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Exported {len(words)} words to {output_file}")
    return words

def translate_with_local_model(words, batch_size=50):
    """Translate using local Helsinki-NLP/opus-mt-en-bg model"""
    print("🤖 Loading translation model (first run downloads ~300MB)...")
    
    from transformers import MarianMTModel, MarianTokenizer
    import torch
    
    # Use Helsinki-NLP's English→Bulgarian model
    model_name = "Helsinki-NLP/opus-mt-en-bg"
    
    # Load model and tokenizer
    tokenizer = MarianTokenizer.from_pretrained(model_name)
    model = MarianMTModel.from_pretrained(model_name)
    
    # Use GPU if available, otherwise CPU
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    
    print(f"   Using device: {device}")
    print(f"   Translating {len(words)} words in batches of {batch_size}...")
    
    translated = []
    total = len(words)
    progress_file = Path("data/export/translation_progress.json")
    
    # Load existing progress if any
    if progress_file.exists():
        with open(progress_file, 'r', encoding='utf-8') as f:
            translated = json.load(f)
        print(f"   Resumed from progress file: {len(translated)} words already done")
    
    for i in range(0, total, batch_size):
        batch = words[i:i+batch_size]
        texts = [w["meaning"] for w in batch]
        
        # Tokenize
        inputs = tokenizer(texts, return_tensors="pt", padding=True, truncation=True, max_length=512)
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        # Translate
        with torch.no_grad():
            translated_tokens = model.generate(**inputs)
        
        # Decode
        translations = tokenizer.batch_decode(translated_tokens, skip_special_tokens=True)
        
        # Store results
        for word, trans in zip(batch, translations):
            translated.append({
                "id": word["id"],
                "text": word["text"],
                "meaning": word["meaning"],
                "bg_meaning": trans
            })
        
        # Progress
        progress = min(i + batch_size, total)
        print(f"   Progress: {progress}/{total} ({progress/total*100:.1f}%)")
        
        # Save progress after each batch
        if progress_file.parent.exists():
            with open(progress_file, 'w', encoding='utf-8') as f:
                json.dump(translated, f, ensure_ascii=False, indent=2)
    
    # Save final results
    output_file = Path("data/export/n3_translated.json")
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(translated, f, ensure_ascii=False, indent=2)
    
    # Clean up progress file
    if progress_file.exists():
        progress_file.unlink()
    
    print(f"✅ Saved translations to {output_file}")
    return translated

def import_translations():
    """Import translated words back to database"""
    print("📥 Importing translations to database...")
    
    input_file = Path("data/export/n3_translated.json")
    
    with open(input_file, "r", encoding="utf-8") as f:
        words = json.load(f)
    
    total = len(words)
    batch_size = 100
    
    for i in range(0, total, batch_size):
        batch = words[i:i+batch_size]
        sql_parts = []
        
        for word in batch:
            bg = word["bg_meaning"].replace("'", "''")
            sql_parts.append(
                f"UPDATE words SET translations = COALESCE(translations, '{{}}') || '{{\"bg\": {{\"meaning\": \"{bg}\"}}}}'::jsonb WHERE id = '{word['id']}';"
            )
        
        batch_sql = "\n".join(sql_parts)
        result = subprocess.run(
            ["psql", "-d", "medoru_dev", "-c", batch_sql],
            capture_output=True, text=True
        )
        
        progress = min(i + batch_size, total)
        print(f"   Progress: {progress}/{total} ({progress/total*100:.1f}%)")
    
    print("✅ All translations imported!")

def verify_translations():
    """Check how many English placeholders remain"""
    sql = """
    SELECT COUNT(*) FROM words 
    WHERE difficulty = 3 AND translations->'bg'->>'meaning' = meaning;
    """
    
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-A", "-c", sql],
        capture_output=True, text=True
    )
    
    count = int(result.stdout.strip())
    print(f"\n📊 Remaining English placeholders: {count}")
    
    # Also check proper Bulgarian count
    sql2 = """
    SELECT COUNT(*) FROM words 
    WHERE difficulty = 3 AND translations->>'bg' IS NOT NULL;
    """
    result2 = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-A", "-c", sql2],
        capture_output=True, text=True
    )
    total_bg = int(result2.stdout.strip())
    print(f"📊 Total with Bulgarian field: {total_bg}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Local English→Bulgarian Translation")
        print("==================================")
        print()
        print("Usage: python bin/translate_local.py [export|translate|import|all|verify]")
        print()
        print("Commands:")
        print("  export     - Export words needing translation")
        print("  translate  - Translate using local model")
        print("  import     - Import translations to database")
        print("  all        - Run full pipeline (export → translate → import)")
        print("  verify     - Check remaining English placeholders")
        print()
        print("Full pipeline: python bin/translate_local.py all")
        sys.exit(1)
    
    cmd = sys.argv[1]
    
    if cmd == "export":
        export_untranslated()
    
    elif cmd == "translate":
        if not check_dependencies():
            sys.exit(1)
        words = export_untranslated()
        translate_with_local_model(words)
    
    elif cmd == "import":
        import_translations()
        verify_translations()
    
    elif cmd == "all":
        if not check_dependencies():
            sys.exit(1)
        words = export_untranslated()
        translate_with_local_model(words)
        import_translations()
        verify_translations()
    
    elif cmd == "verify":
        verify_translations()
    
    else:
        print(f"Unknown command: {cmd}")
