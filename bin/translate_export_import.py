#!/usr/bin/env python3
"""
Export → Translate with Google/DeepL → Import
Free option using DeepL free tier (500K chars/month) or Google Translate scraper
"""

import json
import subprocess
import time
import os

def export_untranslated():
    """Export words with English placeholders to JSON"""
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
            id, text, meaning = line.split("|")
            words.append({"id": id, "text": text, "meaning": meaning})
    
    with open("data/export/n3_to_translate.json", "w", encoding="utf-8") as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Exported {len(words)} words to data/export/n3_to_translate.json")
    return words

def translate_with_deepl(words):
    """Translate using DeepL API (500K chars free/month)"""
    import requests
    
    api_key = os.getenv("DEEPL_API_KEY")
    if not api_key:
        print("❌ Set DEEPL_API_KEY environment variable")
        return
    
    url = "https://api-free.deepl.com/v2/translate"
    
    # Process in batches of 50 (DeepL limit)
    batch_size = 50
    translated = []
    
    for i in range(0, len(words), batch_size):
        batch = words[i:i+batch_size]
        texts = [w["meaning"] for w in batch]
        
        response = requests.post(
            url,
            headers={"Authorization": f"DeepL-Auth-Key {api_key}"},
            data={
                "text": texts,
                "source_lang": "EN",
                "target_lang": "BG"
            }
        )
        
        if response.status_code == 200:
            translations = response.json()["translations"]
            for word, trans in zip(batch, translations):
                word["bg_meaning"] = trans["text"]
                translated.append(word)
            print(f"✅ Translated {len(translated)}/{len(words)}")
        else:
            print(f"❌ Error: {response.text}")
            break
        
        time.sleep(0.5)  # Rate limiting
    
    # Save translated
    with open("data/export/n3_translated.json", "w", encoding="utf-8") as f:
        json.dump(translated, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Saved translations to data/export/n3_translated.json")

def import_translations():
    """Import translated words back to database"""
    with open("data/export/n3_translated.json", "r", encoding="utf-8") as f:
        words = json.load(f)
    
    # Generate SQL
    sql_parts = []
    for word in words:
        bg = word["bg_meaning"].replace("'", "''")
        sql_parts.append(
            f"UPDATE words SET translations = COALESCE(translations, '{{}}') || '{{\"bg\": {{\"meaning\": \"{bg}\"}}}}'::jsonb WHERE id = '{word['id']}';"
        )
    
    # Execute in batches
    batch_size = 100
    for i in range(0, len(sql_parts), batch_size):
        batch_sql = "\n".join(sql_parts[i:i+batch_size])
        subprocess.run(["psql", "-d", "medoru_dev", "-c", batch_sql])
        print(f"✅ Imported {min(i+batch_size, len(words))}/{len(words)}")
    
    print("✅ All translations imported!")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python translate_export_import.py [export|translate|import]")
        sys.exit(1)
    
    cmd = sys.argv[1]
    
    if cmd == "export":
        export_untranslated()
    elif cmd == "translate":
        words = export_untranslated()
        translate_with_deepl(words)
    elif cmd == "import":
        import_translations()
    else:
        print("Unknown command")
