#!/usr/bin/env python3
"""
Resumable translation script for Medoru content.
Saves progress after each batch so translation can be resumed if interrupted.

Usage:
    python translate_resumable.py --type words --input ../export/words.json --output ../export/words_bg.json --batch-size 100
    
    # Resume previous translation
    python translate_resumable.py --type words --input ../export/words.json --output ../export/words_bg.json --resume

Progress is saved to: <output_file>.progress.json
"""

import json
import os
import sys
import time
from pathlib import Path
from datetime import datetime

# Simple English to Bulgarian dictionary for common words
# In production, this would call an LLM API
EN_TO_BG = {
    # Common nouns
    "person": "човек", "people": "хора", "man": "мъж", "woman": "жена", "child": "дете",
    "family": "семейство", "friend": "приятел", "student": "ученик", "teacher": "учител",
    "school": "училище", "book": "книга", "time": "време", "day": "ден", "night": "нощ",
    "morning": "сутрин", "evening": "вечер", "today": "днес", "tomorrow": "утре", "yesterday": "вчера",
    "year": "година", "month": "месец", "week": "седмица", "hour": "час", "minute": "минута",
    "water": "вода", "food": "храна", "money": "пари", "work": "работа", "home": "дом",
    "house": "къща", "room": "стая", "door": "врата", "window": "прозорец", "table": "маса",
    "chair": "стол", "car": "кола", "train": "влак", "bus": "автобус", "bicycle": "колело",
    "road": "път", "street": "улица", "city": "град", "country": "страна", "world": "свят",
    "love": "любов", "happiness": "щастие", "sadness": "тъга", "anger": "гняв", "fear": "страх",
    "Japan": "Япония", "Japanese": "японски", "English": "английски", "Bulgarian": "български",
    
    # Numbers
    "one": "едно", "two": "две", "three": "три", "four": "четири", "five": "пет",
    "six": "шест", "seven": "седем", "eight": "осем", "nine": "девет", "ten": "десет",
    "first": "първи", "second": "втори", "third": "трети",
    
    # Colors
    "red": "червен", "blue": "син", "green": "зелен", "yellow": "жълт", "white": "бял",
    "black": "черен", "color": "цвят",
    
    # Common verbs
    "to be": "да бъда", "to do": "да правя", "to go": "да отида", "to come": "да дойда",
    "to see": "да видя", "to look": "да гледам", "to eat": "да ям", "to drink": "да пия",
    "to sleep": "да спя", "to wake up": "да се събудя", "to read": "да чета", "to write": "да пиша",
    "to speak": "да говоря", "to listen": "да слушам", "to buy": "да купя", "to sell": "да продам",
    "to wait": "да чакам", "to understand": "да разбирам", "to know": "да знам", "to think": "да мисля",
    "to say": "да кажа", "to begin": "да започна", "to finish": "да завърша", "to return": "да се върна",
    "to use": "да използвам", "to make": "да направя", "to take": "да взема", "to give": "да дам",
    "to meet": "да се срещна", "to work": "да работя", "to study": "да уча", "to learn": "да науча",
    
    # Adjectives
    "big": "голям", "small": "малък", "large": "голям", "little": "малък",
    "good": "добър", "bad": "лош", "new": "нов", "old": "стар",
    "high": "висок", "low": "нисък", "long": "дълъг", "short": "къс",
    "hot": "горещ", "cold": "студен", "warm": "топъл", "cool": "хладен",
    "beautiful": "красив", "ugly": "грозен", "easy": "лесен", "difficult": "труден",
    "happy": "щастлив", "sad": "тъжен", "angry": "ядосан", "tired": "уморен",
    
    # Common phrases
    "good morning": "добро утро", "good evening": "добър вечер", "good night": "лека нощ",
    "hello": "здравей", "goodbye": "довиждане", "thank you": "благодаря", "please": "моля",
    "sorry": "извинете", "yes": "да", "no": "не", "maybe": "може би",
    
    # Body parts
    "head": "глава", "face": "лице", "eye": "око", "ear": "ухо", "nose": "нос",
    "mouth": "уста", "hand": "ръка", "foot": "крак", "leg": "крак", "arm": "ръка",
    "hair": "коса", "body": "тяло", "heart": "сърце", "blood": "кръв",
    
    # Family
    "mother": "майка", "father": "баща", "parent": "родител", "parents": "родители",
    "sister": "сестра", "brother": "брат", "sibling": "брат/сестра",
    "grandmother": "баба", "grandfather": "дядо", "grandparent": "баба/дядо",
    "wife": "съпруга", "husband": "съпруг", "daughter": "дъщеря", "son": "син",
    
    # Food
    "rice": "ориз", "fish": "риба", "meat": "месо", "vegetable": "зеленчук", "fruit": "плод",
    "bread": "хляб", "noodle": "спагети/юфка", "soup": "супа", "tea": "чай", "coffee": "кафе",
    
    # Time
    "now": "сега", "then": "тогава", "before": "преди", "after": "след",
    "always": "винаги", "never": "никога", "sometimes": "понякога", "often": "често",
    "soon": "скоро", "already": "вече", "yet": "още", "still": "все още",
    
    # Places
    "place": "място", "building": "сграда", "store": "магазин", "shop": "магазин",
    "restaurant": "ресторант", "hospital": "болница", "bank": "банка", "post office": "поща",
    "station": "гара", "airport": "летище", "park": "парк", "garden": "градина",
    "river": "река", "mountain": "планина", "sea": "море", "sky": "небе",
    
    # Nature
    "sun": "слънце", "moon": "луна", "star": "звезда", "rain": "дъжд", "snow": "сняг",
    "wind": "вятър", "cloud": "облак", "flower": "цвете", "tree": "дърво", "grass": "трева",
    "animal": "животно", "dog": "куче", "cat": "котка", "bird": "птица", "fish": "риба",
    
    # Misc
    "thing": "нещо", "object": "предмет", "problem": "проблем", "question": "въпрос",
    "answer": "отговор", "way": "начин", "method": "метод", "reason": "причина",
    "idea": "идея", "example": "пример", "part": "част", "piece": "парче",
    "side": "страна", "front": "пред", "back": "зад", "top": "връх", "bottom": "дъно",
    "inside": "вътре", "outside": "вън", "left": "ляво", "right": "дясно",
    "up": "нагоре", "down": "надолу", "here": "тук", "there": "там",
}


def load_progress(progress_file):
    """Load translation progress if exists."""
    if os.path.exists(progress_file):
        with open(progress_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {"translated_ids": [], "total": 0, "completed": 0}


def save_progress(progress_file, progress):
    """Save translation progress."""
    with open(progress_file, 'w', encoding='utf-8') as f:
        json.dump(progress, f, ensure_ascii=False, indent=2)


def translate_simple(text):
    """Simple translation using dictionary."""
    # Clean up the text
    text_clean = text.lower().strip()
    
    # Direct match
    if text_clean in EN_TO_BG:
        return EN_TO_BG[text_clean]
    
    # Remove common prefixes
    prefixes = ["to ", "a ", "an ", "the ", "some ", "any "]
    for prefix in prefixes:
        if text_clean.startswith(prefix):
            without_prefix = text_clean[len(prefix):]
            if without_prefix in EN_TO_BG:
                return EN_TO_BG[without_prefix]
    
    # Try base form (before parentheses or commas)
    base = text_clean.split('(')[0].split(',')[0].strip()
    if base in EN_TO_BG:
        return EN_TO_BG[base]
    
    # Try first word
    first_word = text_clean.split()[0] if text_clean else ""
    if first_word in EN_TO_BG:
        return EN_TO_BG[first_word]
    
    return None  # Not translated


def translate_words(input_file, output_file, batch_size=100, resume=False):
    """Translate words with resume capability."""
    progress_file = output_file + ".progress.json"
    
    # Load input
    print(f"Loading words from {input_file}...")
    with open(input_file, 'r', encoding='utf-8') as f:
        words = json.load(f)
    
    total = len(words)
    print(f"Total words to translate: {total}")
    
    # Load progress
    progress = load_progress(progress_file) if resume else {"translated_ids": [], "total": total, "completed": 0}
    translated_ids = set(progress["translated_ids"])
    
    # Load existing output if resuming
    translated_words = []
    if resume and os.path.exists(output_file):
        with open(output_file, 'r', encoding='utf-8') as f:
            translated_words = json.load(f)
        print(f"Resumed: {len(translated_words)} words already translated")
    
    # Filter out already translated
    remaining = [w for w in words if w["id"] not in translated_ids]
    print(f"Remaining to translate: {len(remaining)}")
    
    if not remaining:
        print("All words already translated!")
        return
    
    # Process in batches
    for i in range(0, len(remaining), batch_size):
        batch = remaining[i:i+batch_size]
        batch_num = i // batch_size + 1
        total_batches = (len(remaining) + batch_size - 1) // batch_size
        
        print(f"\nBatch {batch_num}/{total_batches} ({len(batch)} words)...")
        
        for word in batch:
            # Translate
            bg_meaning = translate_simple(word["meaning"])
            
            if bg_meaning:
                word["translations"] = {"bg": {"meaning": bg_meaning}}
                word["_translated"] = True
            else:
                word["translations"] = {}
                word["_translated"] = False
            
            translated_words.append(word)
            translated_ids.add(word["id"])
        
        # Save progress after each batch
        progress["translated_ids"] = list(translated_ids)
        progress["completed"] = len(translated_ids)
        progress["last_update"] = datetime.now().isoformat()
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(translated_words, f, ensure_ascii=False, indent=2)
        
        save_progress(progress_file, progress)
        
        translated_count = sum(1 for w in translated_words if w.get("_translated"))
        print(f"  Saved: {len(translated_words)}/{total} words ({translated_count} with translation)")
    
    # Clean up _translated flag
    for w in translated_words:
        w.pop("_translated", None)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(translated_words, f, ensure_ascii=False, indent=2)
    
    # Remove progress file when done
    if os.path.exists(progress_file):
        os.remove(progress_file)
    
    print(f"\n✓ Done! Translated {len(translated_words)} words to {output_file}")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Resumable translation for Medoru")
    parser.add_argument("--type", choices=["words", "kanji", "lessons"], required=True)
    parser.add_argument("--input", required=True, help="Input JSON file")
    parser.add_argument("--output", required=True, help="Output JSON file")
    parser.add_argument("--batch-size", type=int, default=100, help="Batch size")
    parser.add_argument("--resume", action="store_true", help="Resume from previous run")
    
    args = parser.parse_args()
    
    if args.type == "words":
        translate_words(args.input, args.output, args.batch_size, args.resume)
    else:
        print(f"Type {args.type} not yet implemented")


if __name__ == "__main__":
    main()
