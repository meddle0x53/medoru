#!/usr/bin/env python3
"""
Test NLLB-200-3.3B on 100 random N3 words
"""

import subprocess
import sys

def get_test_words():
    sql = """
    SELECT text, meaning 
    FROM words 
    WHERE difficulty = 3
    ORDER BY RANDOM()
    LIMIT 100;
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
    print("🧪 Testing Facebook NLLB-200-3.3B")
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
    print(f"💾 RAM: {ram_gb:.1f}GB")
    print()
    
    # Load model
    print("📦 Loading facebook/nllb-200-3.3B...")
    
    model_name = "facebook/nllb-200-3.3B"
    
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
    
    # Translate in batches
    texts = [w["en"] for w in words]
    translations = []
    batch_size = 10
    
    # Get Bulgarian token ID
    bulgarian_token = "bul_Cyrl"
    
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        inputs = tokenizer(batch, return_tensors="pt", padding=True, truncation=True, max_length=512, src_lang="eng_Latn")
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        # Use correct token for Bulgarian
        forced_bos = tokenizer.lang_code_to_id[bulgarian_token] if hasattr(tokenizer, 'lang_code_to_id') else tokenizer.convert_tokens_to_ids(bulgarian_token)
        
        with torch.no_grad():
            tokens = model.generate(**inputs, forced_bos_token_id=forced_bos)
        
        translations.extend(tokenizer.batch_decode(tokens, skip_special_tokens=True))
        print(f"  {min(i+batch_size, len(texts))}/{len(texts)}", end="\r")
    
    print()
    print()
    
    # Show results
    print("=" * 70)
    print("RESULTS")
    print("=" * 70)
    print()
    
    # Categorize
    good = []
    questionable = []
    
    for w, t in zip(words, translations):
        result = {"en": w["en"], "bg": t}
        if len(t) < 3 or t == w["en"] or "?" in t:
            questionable.append(result)
        else:
            good.append(result)
    
    print(f"✅ Good: {len(good)}")
    print(f"⚠️  Questionable: {len(questionable)}")
    print()
    
    print("Sample Good Translations:")
    print("-" * 70)
    for r in good[:10]:
        print(f"  {r['en'][:45]:45s} → {r['bg'][:45]}")
    print()
    
    if questionable:
        print("Questionable:")
        print("-" * 70)
        for r in questionable[:5]:
            print(f"  {r['en'][:45]:45s} → {r['bg'][:45]}")
    
    print()
    print("=" * 70)
    
    # Recommend
    if len(good) >= 85:
        print("✅ Quality looks GOOD!")
        print("   Run full translation with:")
        print("   python3 bin/translate_n3_nllb.py")
    elif len(good) >= 70:
        print("⚠️  Quality is ACCEPTABLE")
        print("   Consider reviewing some translations")
    else:
        print("❌ Quality is POOR")
        print("   Consider DeepL API for better results")

if __name__ == "__main__":
    main()
