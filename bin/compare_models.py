#!/usr/bin/env python3
"""
Compare translation quality on 10 sample words
Uses Helsinki-NLP (already downloaded)
"""

import subprocess

def get_samples():
    """Get 10 diverse test words"""
    return [
        {"en": "computer science", "ja": "コンピュータ科学"},
        {"en": "global warming", "ja": "地球温暖化"},
        {"en": "phenol resin", "ja": "フェノール樹脂"},
        {"en": "arc cutting", "ja": "アーク切断"},
        {"en": "Christmas holiday", "ja": "クリスマス休暇"},
        {"en": "democracy", "ja": "民主主義"},
        {"en": "infrastructure", "ja": "インフラ"},
        {"en": "sustainable development", "ja": "持続可能な開発"},
        {"en": "artificial intelligence", "ja": "人工知能"},
        {"en": "board of directors", "ja": "取締役会"},
    ]

def translate_helsinki(words):
    """Translate with Helsinki-NLP (already downloaded)"""
    from transformers import MarianMTModel, MarianTokenizer
    import torch
    
    model_name = "Helsinki-NLP/opus-mt-en-bg"
    tokenizer = MarianTokenizer.from_pretrained(model_name)
    model = MarianMTModel.from_pretrained(model_name)
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    
    texts = [w["en"] for w in words]
    inputs = tokenizer(texts, return_tensors="pt", padding=True, truncation=True)
    inputs = {k: v.to(device) for k, v in inputs.items()}
    
    with torch.no_grad():
        tokens = model.generate(**inputs)
    
    return tokenizer.batch_decode(tokens, skip_special_tokens=True)

def main():
    print("=" * 70)
    print("📊 Quick Quality Comparison: Helsinki-NLP/opus-mt-en-bg")
    print("=" * 70)
    print()
    print("Testing on 10 diverse words...")
    print()
    
    try:
        from transformers import MarianMTModel, MarianTokenizer
        import torch
    except ImportError:
        print("Installing dependencies...")
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "transformers", "torch", "sentencepiece"])
        from transformers import MarianMTModel, MarianTokenizer
        import torch
    
    words = get_samples()
    
    print("🤖 Loading Helsinki-NLP model (cached)...")
    translations = translate_helsinki(words)
    
    print()
    print("RESULTS:")
    print("-" * 70)
    print(f"{'English':<30s} → {'Bulgarian (Helsinki-NLP)':<35s}")
    print("-" * 70)
    
    for w, t in zip(words, translations):
        print(f"{w['en']:<30s} → {t}")
    
    print("-" * 70)
    print()
    
    # Rate
    issues = []
    for w, t in zip(words, translations):
        if len(t) < 3 or t == w["en"]:
            issues.append(f"  - '{w['en']}' copied instead of translated")
        elif "ред" in t.lower() and "поред" not in t.lower() and "редов" not in t.lower():
            # "ред" often indicates wrong translation
            pass
    
    if issues:
        print("⚠️  Issues found:")
        for i in issues:
            print(i)
    else:
        print("✅ No obvious issues")
    
    print()
    print("=" * 70)
    print("NOTES:")
    print("  • Helsinki-NLP is FAST but quality varies on technical terms")
    print("  • NLLB-200 is SLOWER but significantly better quality")
    print("  • DeepL API is FASTEST and BEST quality but costs ~$7")
    print("=" * 70)
    print()
    print("Options:")
    print("  1. Continue downloading NLLB-3.3B for best quality (6-8 hours)")
    print("  2. Use NLLB-1.3B for good quality (3-4 hours, faster download)")
    print("  3. Use Helsinki-NLP for acceptable quality (1-2 hours)")
    print("  4. Use DeepL API for best quality ($7, 30 minutes)")

if __name__ == "__main__":
    main()
