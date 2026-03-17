#!/usr/bin/env python3
"""
Quick quality test for NLLB-200-3.3B
Run this and wait ~5 minutes for model loading
"""

import subprocess
import sys

def get_test_words():
    """Get 10 diverse test words from DB"""
    sql = """
    SELECT text, meaning 
    FROM words 
    WHERE difficulty = 3
    ORDER BY RANDOM()
    LIMIT 10;
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
    print("🧪 NLLB-200-3.3B Quality Test (10 words)")
    print("=" * 70)
    print()
    print("⏳ Loading model (~5 minutes for 17GB)...")
    print()
    
    from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
    import torch
    
    model_name = "facebook/nllb-200-3.3B"
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    
    device = torch.device("cpu")
    model = model.to(device)
    
    print("✅ Model loaded!")
    print()
    
    # Set target language
    tokenizer.tgt_lang = "bul_Cyrl"
    
    # Get test words
    words = get_test_words()
    print(f"Testing on {len(words)} random N3 words:")
    print()
    
    # Translate
    results = []
    for w in words:
        inputs = tokenizer(w["en"], return_tensors="pt", src_lang="eng_Latn")
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        with torch.no_grad():
            tokens = model.generate(**inputs)
        
        trans = tokenizer.decode(tokens[0], skip_special_tokens=True)
        results.append({"en": w["en"], "bg": trans})
        print(f"  {w['en']:<40s} → {trans}")
    
    print()
    print("=" * 70)
    print("QUALITY ASSESSMENT")
    print("=" * 70)
    print()
    
    # Check quality
    good = sum(1 for r in results if len(r["bg"]) > 3 and r["bg"] != r["en"])
    print(f"Good translations: {good}/{len(results)}")
    print()
    
    if good >= 8:
        print("✅ EXCELLENT quality! Ready for full translation.")
        print()
        print("Start full translation with:")
        print("  python3 bin/translate_n3_nllb.py")
    elif good >= 6:
        print("⚠️  ACCEPTABLE quality. Some words may need review.")
    else:
        print("❌ POOR quality. Consider using DeepL API instead.")

if __name__ == "__main__":
    main()
