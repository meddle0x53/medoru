#!/usr/bin/env python3
"""
Test NLLB-200-1.3B quality on 10 words
Downloads ~5GB model, takes ~10 minutes total
"""

import subprocess
import sys

def main():
    print("=" * 70)
    print("🧪 Testing Facebook NLLB-200-1.3B (5GB)")
    print("=" * 70)
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
    
    print("📦 Loading facebook/nllb-200-1.3B...")
    print("   (Downloads ~5GB on first run)")
    print()
    
    model_name = "facebook/nllb-200-1.3B"
    
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    except Exception as e:
        print(f"❌ Error: {e}")
        return
    
    device = torch.device("cpu")
    model = model.to(device)
    print(f"✅ Model loaded on {device}")
    print()
    
    # Bulgarian token ID
    bulgarian_id = 256033
    
    # Get 20 random test words from DB
    sql = """
    SELECT meaning 
    FROM words 
    WHERE difficulty = 3
    ORDER BY RANDOM()
    LIMIT 20;
    """
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-c", sql],
        capture_output=True, text=True
    )
    test_words = [w.strip() for w in result.stdout.strip().split('\n') if w.strip()]
    
    print("Translations:")
    print("-" * 70)
    
    good = 0
    for text in test_words:
        inputs = tokenizer(text, return_tensors="pt", src_lang="eng_Latn")
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        with torch.no_grad():
            tokens = model.generate(**inputs, forced_bos_token_id=bulgarian_id, max_length=128)
        
        trans = tokenizer.decode(tokens[0], skip_special_tokens=True)
        status = "✓" if len(trans) > 3 and trans != text else "?"
        if status == "✓":
            good += 1
        print(f"{status} {text:<40s} → {trans}")
    
    print("-" * 70)
    print()
    print(f"Quality Score: {good}/{len(test_words)} good translations")
    print()
    
    if good >= 8:
        print("✅ EXCELLENT quality!")
        print()
        print("Start full translation:")
        print("  python3 bin/translate_n3_nllb.py")
    elif good >= 6:
        print("⚠️  ACCEPTABLE quality (some may need review)")
    else:
        print("❌ POOR quality - try different approach")

if __name__ == "__main__":
    main()
