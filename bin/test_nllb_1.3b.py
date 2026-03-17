#!/usr/bin/env python3
"""
Quick test with NLLB-200-1.3B (5GB model, faster download)
Good enough to verify quality before committing to 3.3B
"""

import subprocess
import sys

def get_test_words():
    sql = """
    SELECT text, meaning 
    FROM words 
    WHERE difficulty = 3
    ORDER BY RANDOM()
    LIMIT 50;
    """
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-A", "-F", "|", "-c", sql],
        capture_output=True, text=True
    )
    words = []
    for line in result.stdout.strip().split("\n"):
        if "|" in line:
            parts = line.split("|")
            words.append({"text": parts[0], "en": parts[1]})
    return words

def main():
    print("=" * 70)
    print("🧪 Quick Test: Facebook NLLB-200-1.3B (5GB)")
    print("=" * 70)
    print()
    print("This is the SMALLER model for quick testing.")
    print("Downloads ~5GB vs 13GB for the 3.3B model.")
    print()
    
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
    
    ram_gb = psutil.virtual_memory().total / (1024**3)
    print(f"💾 RAM: {ram_gb:.1f}GB ✓")
    print()
    
    # Load smaller model
    print("📦 Loading facebook/nllb-200-1.3B...")
    print("   (Downloads ~5GB on first run, ~10-15 min)")
    print("   Starting download... this will show progress")
    print()
    
    model_name = "facebook/nllb-200-1.3B"
    
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    except Exception as e:
        print(f"❌ Error: {e}")
        return
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    print(f"✅ Model loaded on {device}")
    print()
    
    # Get words
    words = get_test_words()
    print(f"🔄 Translating {len(words)} words...")
    print()
    
    # Translate
    texts = [w["en"] for w in words]
    translations = []
    batch_size = 10
    
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        inputs = tokenizer(batch, return_tensors="pt", padding=True, truncation=True, max_length=512, src_lang="eng_Latn")
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        with torch.no_grad():
            tokens = model.generate(**inputs, forced_bos_token_id=tokenizer.lang_code_to_id["bul_Cyrl"])
        
        translations.extend(tokenizer.batch_decode(tokens, skip_special_tokens=True))
        print(f"  Progress: {min(i+batch_size, len(texts))}/{len(texts)}")
    
    print()
    print("=" * 70)
    print("RESULTS")
    print("=" * 70)
    print()
    
    # Show samples
    good = 0
    print("Sample Translations:")
    print("-" * 70)
    for w, t in zip(words[:15], translations[:15]):
        status = "✓" if len(t) > 3 and t != w["en"] else "?"
        if status == "✓":
            good += 1
        print(f"{status} {w['en'][:40]:40s} → {t[:40]}")
    print("-" * 70)
    print()
    
    # Rate quality
    quality = good / 15 * 100
    print(f"Quality Score: {quality:.0f}% ({good}/15 good translations)")
    print()
    
    if quality >= 80:
        print("✅ EXCELLENT - This model produces good translations!")
        print()
        print("Recommendations:")
        print("  • For FULL dataset: Use 1.3B (faster, ~3-4 hours)")
        print("  • For BEST quality: Use 3.3B (slower, ~6-8 hours)")
        print()
        print("Run full translation:")
        print("  python3 bin/translate_n3_nllb.py")
        print()
        print("(Edit the script to use 'facebook/nllb-200-1.3B' for faster run)")
    elif quality >= 60:
        print("⚠️  ACCEPTABLE - Some translations may need review")
        print("   Consider using the 3.3B model for better quality")
    else:
        print("❌ POOR - Try a different approach (DeepL API?)")

if __name__ == "__main__":
    main()
