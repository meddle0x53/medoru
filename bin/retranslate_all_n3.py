#!/usr/bin/env python3
"""
Complete re-translation of ALL N3 words (135,847) with Helsinki-NLP/opus-mt-en-bg
Clears existing translations and starts fresh for uniform quality.
"""

import json
import subprocess
import sys
from pathlib import Path

def clear_existing_translations():
    """Clear all existing N3 Bulgarian translations"""
    print("🧹 Clearing existing N3 Bulgarian translations...")
    
    sql = """
    UPDATE words 
    SET translations = translations - 'bg'
    WHERE difficulty = 3 AND translations ? 'bg';
    """
    
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-c", sql],
        capture_output=True, text=True
    )
    
    if result.returncode == 0:
        print("✅ Cleared existing translations")
    else:
        print(f"❌ Error: {result.stderr}")
        sys.exit(1)

def export_all_n3():
    """Export ALL N3 words for re-translation"""
    print("📤 Exporting all N3 words...")
    
    sql = """
    SELECT id, text, meaning 
    FROM words 
    WHERE difficulty = 3
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
    
    output_file = Path("data/export/n3_all_for_translation.json")
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Exported {len(words)} words to {output_file}")
    return words

def translate_with_model(words, batch_size=50):
    """Translate all words using Helsinki-NLP model"""
    print("🤖 Loading Helsinki-NLP/opus-mt-en-bg model...")
    print("   (First run downloads ~300MB)")
    
    from transformers import MarianMTModel, MarianTokenizer
    import torch
    
    model_name = "Helsinki-NLP/opus-mt-en-bg"
    tokenizer = MarianTokenizer.from_pretrained(model_name)
    model = MarianMTModel.from_pretrained(model_name)
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    
    print(f"   Using device: {device}")
    print(f"   Translating {len(words)} words...")
    
    translated = []
    total = len(words)
    progress_file = Path("data/export/n3_retranslation_progress.json")
    
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
        if progress % 500 == 0 or progress == total:
            print(f"   Progress: {progress}/{total} ({progress/total*100:.1f}%)")
            
            # Save progress
            with open(progress_file, 'w', encoding='utf-8') as f:
                json.dump(translated, f, ensure_ascii=False, indent=2)
    
    # Save final results
    output_file = Path("data/export/n3_all_translated.json")
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(translated, f, ensure_ascii=False, indent=2)
    
    # Clean up progress file
    if progress_file.exists():
        progress_file.unlink()
    
    print(f"✅ Saved all translations to {output_file}")
    return translated

def import_translations():
    """Import all translations to database"""
    print("📥 Importing translations to database...")
    
    input_file = Path("data/export/n3_all_translated.json")
    
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
        subprocess.run(
            ["psql", "-d", "medoru_dev", "-c", batch_sql],
            capture_output=True
        )
        
        progress = min(i + batch_size, total)
        if progress % 1000 == 0 or progress == total:
            print(f"   Progress: {progress}/{total} ({progress/total*100:.1f}%)")
    
    print("✅ All translations imported!")

def verify_quality():
    """Verify translation quality with random samples"""
    print("\n🔍 Verifying translation quality...")
    
    sql = """
    SELECT meaning, translations->'bg'->>'meaning' as bg
    FROM words 
    WHERE difficulty = 3 AND translations->>'bg' IS NOT NULL
    ORDER BY RANDOM()
    LIMIT 10;
    """
    
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-A", "-F", " | ", "-c", sql],
        capture_output=True, text=True
    )
    
    print("\nSample translations:")
    print("-" * 80)
    for line in result.stdout.strip().split("\n"):
        if line:
            print(f"  {line}")
    print("-" * 80)

if __name__ == "__main__":
    print("=" * 80)
    print("Complete N3 Re-translation (135,847 words)")
    print("=" * 80)
    print()
    print("This will:")
    print("  1. Clear ALL existing N3 Bulgarian translations")
    print("  2. Re-translate ALL 135,847 words with Helsinki-NLP model")
    print("  3. Import fresh translations to database")
    print()
    print("Estimated time: 2-4 hours depending on hardware")
    print()
    
    if len(sys.argv) > 1 and sys.argv[1] == "--yes":
        confirm = "yes"
    else:
        confirm = input("Are you sure? Type 'yes' to proceed: ")
    
    if confirm.lower() != "yes":
        print("Cancelled.")
        sys.exit(0)
    
    # Check dependencies
    try:
        import transformers
        import torch
    except ImportError:
        print("❌ Missing dependencies. Install with:")
        print("   pip install transformers torch sentencepiece sacremoses")
        sys.exit(1)
    
    # Run pipeline
    clear_existing_translations()
    words = export_all_n3()
    translate_with_model(words)
    import_translations()
    verify_quality()
    
    print("\n" + "=" * 80)
    print("✅ Complete re-translation finished!")
    print("=" * 80)
