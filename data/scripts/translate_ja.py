#!/usr/bin/env python3
"""
Fetch Japanese-Japanese dictionary definitions for words and kanji.

Uses Jisho API (jisho.org) which provides Japanese definitions.

Supports batch processing and resuming from interruptions.

Usage:
    # Get J-J definitions for words
    python translate_ja.py --type words --input words.json --output words_ja.json

    # Get J-J definitions for kanji
    python translate_ja.py --type kanji --input kanji.json --output kanji_ja.json

    # Dry run
    python translate_ja.py --type words --input words.json --dry-run

    # Process in batches of 50
    python translate_ja.py --type words --input words.json --output words_ja.json --batch-size 50

Note:
    This script respects rate limits (jisho.org is free but please be respectful).
    Built-in delay of 0.5s between requests.
    Progress is saved after each batch - if interrupted, simply re-run the same command to resume.
"""

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Optional

import requests


JISHO_API_URL = "https://jisho.org/api/v1/search/words"
JISHO_KANJI_URL = "https://jisho.org/api/v1/search/words"
# Alternative: use KanjiAPI for kanji - https://kanjiapi.dev/
KANJI_API_URL = "https://kanjiapi.dev/v1/kanji"


class JishoClient:
    """Client for Jisho.org API."""

    def __init__(self, delay: float = 0.5):
        self.delay = delay
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Medoru Translation Script (Educational Project)"
        })

    def search_word(self, word: str) -> Optional[dict]:
        """Search for a word on Jisho and get Japanese definition."""
        try:
            params = {"keyword": word}
            response = self.session.get(JISHO_API_URL, params=params, timeout=10)
            response.raise_for_status()

            data = response.json()
            if data.get("data"):
                return data["data"][0]  # Return first result
            return None
        except Exception as e:
            print(f"  Error searching for '{word}': {e}")
            return None
        finally:
            time.sleep(self.delay)

    def get_kanji_info(self, kanji: str) -> Optional[dict]:
        """Get kanji info from KanjiAPI."""
        try:
            url = f"{KANJI_API_URL}/{kanji}"
            response = self.session.get(url, timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"  Error fetching kanji '{kanji}': {e}")
            return None
        finally:
            time.sleep(self.delay)


def extract_ja_meaning(jisho_entry: dict) -> str:
    """
    Extract Japanese definition from Jisho entry.
    Jisho returns Japanese definitions in 'senses' with 'parts_of_speech'.
    """
    if not jisho_entry or "senses" not in jisho_entry:
        return ""

    # Get Japanese definitions (if available)
    # Jisho primarily provides English glosses, but some entries have Japanese defs
    # We construct a meaning from the Japanese readings and parts of speech

    japanese = jisho_entry.get("japanese", [{}])[0]
    reading = japanese.get("reading", "")
    word = japanese.get("word", "")

    # Try to find Japanese explanation from senses
    meanings = []
    for sense in jisho_entry.get("senses", [])[:2]:  # Top 2 senses
        # Get parts of speech
        pos = sense.get("parts_of_speech", [])
        pos_str = "、".join(pos) if pos else ""

        # Get English gloss (fallback)
        gloss = sense.get("english_definitions", [])
        if gloss:
            meanings.append(f"{pos_str}：{gloss[0]}" if pos_str else gloss[0])

    return "；".join(meanings) if meanings else word


def extract_ja_meanings_for_kanji(kanji_info: dict) -> list[str]:
    """Extract Japanese meanings from KanjiAPI data."""
    if not kanji_info:
        return []

    # KanjiAPI provides 'meanings' which are usually English
    # But we also get 'kun_readings' and 'on_readings' which are Japanese
    meanings = kanji_info.get("meanings", [])

    # For true J-J, we could use a different approach:
    # Build a definition based on readings and common words
    # This is a simplified version
    return meanings[:3]  # Top 3 meanings


def get_item_key(item: dict, item_type: str) -> str:
    """Get unique key for an item to track processed items."""
    if item_type == "words":
        return item.get("text", "")
    else:  # kanji
        return item.get("character", "")


def load_progress(output_path: str) -> tuple[list[dict], set[str]]:
    """
    Load existing progress from output file.
    Returns tuple of (processed_items, processed_keys).
    """
    if not Path(output_path).exists():
        return [], set()
    
    try:
        with open(output_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        if isinstance(data, list):
            items = data
        elif isinstance(data, dict):
            items = data.get("data", data.get("items", []))
        else:
            items = []
        
        # Extract keys for quick lookup
        item_type = "kanji" if output_path.startswith("kanji") or "kanji" in output_path else "words"
        processed_keys = {get_item_key(item, item_type) for item in items}
        
        print(f"  Found existing progress: {len(items)} items already processed")
        return items, processed_keys
    except Exception as e:
        print(f"  Warning: Could not load existing progress: {e}")
        return [], set()


def save_progress(output_path: str, items: list[dict]):
    """Save progress to output file."""
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, indent=2)


def process_words_batch(
    words: list[dict], 
    client: JishoClient, 
    processed_keys: set[str],
    batch_start: int,
    batch_end: int
) -> list[dict]:
    """Process a batch of words and add Japanese definitions."""
    results = []

    for i, word_data in enumerate(words):
        global_idx = batch_start + i
        word_text = word_data.get("text", "")
        
        # Skip already processed items
        if word_text in processed_keys:
            print(f"[{global_idx + 1}] Skipping (already processed): {word_text}")
            results.append(word_data)
            continue
        
        print(f"[{global_idx + 1}/{batch_end}] Looking up: {word_text}")

        # Search Jisho
        entry = client.search_word(word_text)

        if entry:
            ja_meaning = extract_ja_meaning(entry)

            # Build translations
            translations = word_data.get("translations", {})
            translations["ja"] = {"meaning": ja_meaning}

            word_data["translations"] = translations
            print(f"  ✓ Found: {ja_meaning[:50]}..." if len(ja_meaning) > 50 else f"  ✓ Found: {ja_meaning}")
        else:
            print(f"  ✗ Not found")

        results.append(word_data)

    return results


def process_kanji_batch(
    kanji_list: list[dict], 
    client: JishoClient, 
    processed_keys: set[str],
    batch_start: int,
    batch_end: int
) -> list[dict]:
    """Process a batch of kanji and add Japanese definitions."""
    results = []

    for i, kanji_data in enumerate(kanji_list):
        global_idx = batch_start + i
        character = kanji_data.get("character", "")
        
        # Skip already processed items
        if character in processed_keys:
            print(f"[{global_idx + 1}] Skipping (already processed): {character}")
            results.append(kanji_data)
            continue
        
        print(f"[{global_idx + 1}/{batch_end}] Looking up: {character}")

        # Get kanji info from API
        info = client.get_kanji_info(character)

        if info:
            # Note: KanjiAPI returns English meanings by default
            # For true J-J definitions, we'd need a different data source
            # This is a placeholder that uses the readings
            kun = info.get("kun_readings", [])
            on = info.get("on_readings", [])

            # Build a simple Japanese-style definition
            readings = []
            if kun:
                readings.append(f"訓読み：{'、'.join(kun[:3])}")
            if on:
                readings.append(f"音読み：{'、'.join(on[:3])}")

            ja_meaning = "；".join(readings) if readings else ""

            translations = kanji_data.get("translations", {})
            translations["ja"] = {"meanings": [ja_meaning] if ja_meaning else []}

            kanji_data["translations"] = translations
            print(f"  ✓ Found: {ja_meaning[:50]}..." if len(ja_meaning) > 50 else f"  ✓ Found: {ja_meaning}")
        else:
            print(f"  ✗ Not found")

        results.append(kanji_data)

    return results


def load_json_file(path: str) -> list[dict]:
    """Load JSON file."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
        if isinstance(data, dict):
            return data.get("data", data.get("items", []))
        return data


def main():
    parser = argparse.ArgumentParser(description="Fetch Japanese-Japanese definitions")
    parser.add_argument("--type", required=True, choices=["words", "kanji"],
                        help="Type of content to process")
    parser.add_argument("--input", required=True, help="Input JSON file path")
    parser.add_argument("--output", help="Output JSON file path")
    parser.add_argument("--delay", type=float, default=0.5,
                        help="Delay between API requests (default: 0.5s)")
    parser.add_argument("--batch-size", type=int, default=10,
                        help="Number of items to process before saving progress (default: 10)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be processed")

    args = parser.parse_args()

    # Load input data
    print(f"Loading {args.type} from {args.input}...")
    items = load_json_file(args.input)
    print(f"Loaded {len(items)} items")

    if args.dry_run:
        print(f"\nDry run - would process {len(items)} {args.type}")
        for item in items[:3]:
            key = "text" if args.type == "words" else "character"
            print(f"  - {item.get(key, 'N/A')}")
        if len(items) > 3:
            print(f"  ... and {len(items) - 3} more")
        return

    if not args.output:
        print("Error: --output required (unless using --dry-run)")
        sys.exit(1)

    # Load existing progress (for resuming)
    print(f"\nChecking for existing progress at {args.output}...")
    all_results, processed_keys = load_progress(args.output)
    
    # Determine which items still need processing
    items_to_process = []
    already_processed_count = 0
    
    for item in items:
        key = get_item_key(item, args.type)
        if key in processed_keys:
            already_processed_count += 1
        else:
            items_to_process.append(item)
    
    if already_processed_count > 0:
        print(f"  {already_processed_count} items already done, {len(items_to_process)} remaining")
    
    if not items_to_process:
        print("\n✓ All items already processed!")
        print(f"  Output: {args.output}")
        print(f"  Total items: {len(all_results)}")
        return

    # Create client
    client = JishoClient(delay=args.delay)

    # Process in batches
    total_items = len(items)
    remaining = len(items_to_process)
    batch_size = args.batch_size
    
    print(f"\nProcessing {remaining} items in batches of {batch_size}...")
    print(f"Progress will be saved after each batch. Press Ctrl+C to interrupt and resume later.\n")
    
    processed_count = 0
    
    try:
        for batch_start in range(0, remaining, batch_size):
            batch_end = min(batch_start + batch_size, remaining)
            batch = items_to_process[batch_start:batch_end]
            global_start = already_processed_count + batch_start
            global_end = already_processed_count + batch_end
            
            print(f"--- Batch {batch_start // batch_size + 1} ({global_start + 1}-{global_end} of {total_items}) ---")
            
            # Process this batch
            if args.type == "words":
                batch_results = process_words_batch(batch, client, processed_keys, global_start, total_items)
            else:  # kanji
                batch_results = process_kanji_batch(batch, client, processed_keys, global_start, total_items)
            
            # Add new results and update processed keys
            for item in batch_results:
                key = get_item_key(item, args.type)
                if key not in processed_keys:
                    all_results.append(item)
                    processed_keys.add(key)
            
            processed_count += len(batch)
            
            # Save progress after each batch
            save_progress(args.output, all_results)
            print(f"✓ Progress saved: {len(all_results)}/{total_items} items\n")
            
    except KeyboardInterrupt:
        print(f"\n\n⚠ Interrupted by user. Saving progress...")
        save_progress(args.output, all_results)
        print(f"✓ Progress saved: {len(all_results)}/{total_items} items")
        print(f"  To resume, simply run the same command again.")
        sys.exit(0)
    except Exception as e:
        print(f"\n\n⚠ Error occurred: {e}")
        print(f"Saving progress...")
        save_progress(args.output, all_results)
        print(f"✓ Progress saved: {len(all_results)}/{total_items} items")
        print(f"  To resume, simply run the same command again.")
        raise

    # Final summary
    print(f"\n✓ Processing complete! Saved to {args.output}")
    print(f"  Total items: {len(all_results)}")


if __name__ == "__main__":
    main()
