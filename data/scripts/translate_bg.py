#!/usr/bin/env python3
"""
Translate Japanese words and kanji meanings to Bulgarian using LLM.

Usage:
    # Translate words (batch mode)
    python translate_bg.py --type words --input words.json --output words_bg.json

    # Translate kanji
    python translate_bg.py --type kanji --input kanji.json --output kanji_bg.json

    # Translate lessons
    python translate_bg.py --type lessons --input lessons.json --output lessons_bg.json

    # Dry run (show what would be translated without calling API)
    python translate_bg.py --type words --input words.json --dry-run

Environment:
    KIMI_API_KEY - Kimi (Moonshot AI) API key
    # Or use OpenAI/Anthropic/OpenRouter if preferred:
    OPENAI_API_KEY - OpenAI API key
    ANTHROPIC_API_KEY - Anthropic API key
    OPENROUTER_API_KEY - OpenRouter API key
"""

import argparse
import json
import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import requests


@dataclass
class TranslationConfig:
    provider: str = "kimi"
    api_key: Optional[str] = None
    model: str = "moonshot-v1-8k"
    batch_size: int = 50
    delay_seconds: float = 0.5


class LLMTranslator:
    """LLM-based translator for Japanese to Bulgarian."""

    def __init__(self, config: TranslationConfig):
        self.config = config
        self.api_key = config.api_key or self._get_api_key()

    def _get_api_key(self) -> str:
        """Get API key from environment."""
        env_vars = {
            "kimi": "KIMI_API_KEY",
            "moonshot": "KIMI_API_KEY",
            "openai": "OPENAI_API_KEY",
            "anthropic": "ANTHROPIC_API_KEY",
            "openrouter": "OPENROUTER_API_KEY"
        }

        env_var = env_vars.get(self.config.provider)
        if not env_var:
            raise ValueError(f"Unknown provider: {self.config.provider}")

        key = os.environ.get(env_var)
        if not key:
            raise ValueError(f"API key not found. Set {env_var} environment variable.")
        return key

    def _build_prompt(self, items: list[dict], content_type: str) -> str:
        """Build translation prompt for LLM."""
        if content_type == "words":
            items_text = "\n".join([
                f"{i+1}. Japanese: {item['text']} | Reading: {item.get('reading', 'N/A')} | English: {item['meaning']}"
                for i, item in enumerate(items)
            ])
            return f"""Translate the following Japanese words to Bulgarian.
For each word, provide the most natural Bulgarian translation.

Format: Return ONLY a JSON array with objects containing 'text', 'bg_meaning'

Words to translate:
{items_text}

Response format (JSON only, no markdown):
[
  {{"text": "日本", "bg_meaning": "Япония"}},
  {{"text": "...", "bg_meaning": "..."}}
]"""

        elif content_type == "kanji":
            items_text = "\n".join([
                f"{i+1}. Kanji: {item['character']} | English meanings: {', '.join(item['meanings'])}"
                for i, item in enumerate(items)
            ])
            return f"""Translate the meanings of the following kanji characters to Bulgarian.
For each kanji, provide Bulgarian translations that capture the core meanings.

Format: Return ONLY a JSON array with objects containing 'character', 'bg_meanings' (array)

Kanji to translate:
{items_text}

Response format (JSON only, no markdown):
[
  {{"character": "日", "bg_meanings": ["слънце", "ден", "Япония"]}},
  {{"character": "...", "bg_meanings": ["...", "..."]}}
]"""

        elif content_type == "lessons":
            items_text = "\n".join([
                f"{i+1}. Title: {item['title']} | Description: {item.get('description', '')}"
                for i, item in enumerate(items)
            ])
            return f"""Translate the following lesson titles and descriptions to Bulgarian.
Keep educational tone appropriate for language learning.

Format: Return ONLY a JSON array with objects containing 'id', 'bg_title', 'bg_description'

Lessons to translate:
{items_text}

Response format (JSON only, no markdown):
[
  {{"id": "...", "bg_title": "...", "bg_description": "..."}},
  ...
]"""

        else:
            raise ValueError(f"Unknown content type: {content_type}")

    def translate_batch(self, items: list[dict], content_type: str) -> list[dict]:
        """Translate a batch of items."""
        prompt = self._build_prompt(items, content_type)

        if self.config.provider in ("kimi", "moonshot"):
            return self._call_kimi(prompt, items, content_type)
        elif self.config.provider == "openai":
            return self._call_openai(prompt, items, content_type)
        elif self.config.provider == "anthropic":
            return self._call_anthropic(prompt, items, content_type)
        elif self.config.provider == "openrouter":
            return self._call_openrouter(prompt, items, content_type)
        else:
            raise ValueError(f"Unknown provider: {self.config.provider}")

    def _call_kimi(self, prompt: str, original_items: list[dict], content_type: str) -> list[dict]:
        """Call Kimi (Moonshot AI) API - OpenAI compatible."""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        data = {
            "model": self.config.model,
            "messages": [
                {"role": "system", "content": "You are a helpful Japanese-Bulgarian translator. Respond only with valid JSON."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.3,
            "max_tokens": 4000
        }

        try:
            response = requests.post(
                "https://api.moonshot.cn/v1/chat/completions",
                headers=headers,
                json=data,
                timeout=60
            )
            response.raise_for_status()
        except requests.exceptions.HTTPError as e:
            if response.status_code == 401:
                print(f"\n  ERROR: Authentication failed (401)")
                print(f"  Your API key appears to be invalid.")
                print(f"  Key used: {self.api_key[:15]}...")
                print(f"\n  ⚠️  IMPORTANT: Keys from kimi.com/code/console DON'T work with the API!")
                print(f"\n  You need to get an API key from the Moonshot developer platform:")
                print(f"  1. Go to https://platform.moonshot.cn/ (NOT kimi.com)")
                print(f"  2. Create a developer account")
                print(f"  3. Go to 'API Keys' section")
                print(f"  4. Create and copy your API key")
                print(f"\n  ALTERNATIVE: Use OpenRouter (easier):")
                print(f"  1. Go to https://openrouter.ai/")
                print(f"  2. Create account and get API key")
                print(f"  3. export OPENROUTER_API_KEY='your-key'")
                print(f"  4. Use --provider openrouter")
            raise

        result = response.json()
        content = result["choices"][0]["message"]["content"]
        return self._parse_and_merge(content, original_items, content_type)

    def _call_openai(self, prompt: str, original_items: list[dict], content_type: str) -> list[dict]:
        """Call OpenAI API."""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        data = {
            "model": self.config.model,
            "messages": [
                {"role": "system", "content": "You are a helpful Japanese-Bulgarian translator. Respond only with valid JSON."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.3,
            "max_tokens": 4000
        }

        response = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers=headers,
            json=data,
            timeout=60
        )
        response.raise_for_status()

        result = response.json()
        content = result["choices"][0]["message"]["content"]
        return self._parse_and_merge(content, original_items, content_type)

    def _call_anthropic(self, prompt: str, original_items: list[dict], content_type: str) -> list[dict]:
        """Call Anthropic API."""
        headers = {
            "x-api-key": self.api_key,
            "Content-Type": "application/json",
            "anthropic-version": "2023-06-01"
        }

        data = {
            "model": self.config.model or "claude-3-haiku-20240307",
            "max_tokens": 4000,
            "messages": [
                {"role": "user", "content": prompt}
            ]
        }

        response = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers=headers,
            json=data,
            timeout=60
        )
        response.raise_for_status()

        result = response.json()
        content = result["content"][0]["text"]
        return self._parse_and_merge(content, original_items, content_type)

    def _call_openrouter(self, prompt: str, original_items: list[dict], content_type: str) -> list[dict]:
        """Call OpenRouter API."""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        data = {
            "model": self.config.model or "openai/gpt-4o-mini",
            "messages": [
                {"role": "system", "content": "You are a helpful Japanese-Bulgarian translator. Respond only with valid JSON."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.3,
            "max_tokens": 4000
        }

        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers=headers,
            json=data,
            timeout=60
        )
        response.raise_for_status()

        result = response.json()
        content = result["choices"][0]["message"]["content"]
        return self._parse_and_merge(content, original_items, content_type)

    def _parse_and_merge(self, content: str, original_items: list[dict], content_type: str) -> list[dict]:
        """Parse JSON response and merge with original items."""
        # Clean up markdown code blocks if present
        content = content.strip()
        if content.startswith("```json"):
            content = content[7:]
        if content.startswith("```"):
            content = content[3:]
        if content.endswith("```"):
            content = content[:-3]
        content = content.strip()

        try:
            translations = json.loads(content)
            return self._merge_translations(original_items, translations, content_type)
        except json.JSONDecodeError as e:
            print(f"Failed to parse JSON: {e}")
            print(f"Content: {content[:500]}...")
            return []

    def _merge_translations(self, original: list[dict], translations: list[dict], content_type: str) -> list[dict]:
        """Merge translations back into original items."""
        result = []

        for orig in original:
            item = orig.copy()

            if content_type == "words":
                match = next((t for t in translations if t.get("text") == item["text"]), None)
                if match:
                    item["translations"] = item.get("translations", {})
                    item["translations"]["bg"] = {"meaning": match.get("bg_meaning", "")}

            elif content_type == "kanji":
                match = next((t for t in translations if t.get("character") == item["character"]), None)
                if match:
                    item["translations"] = item.get("translations", {})
                    item["translations"]["bg"] = {"meanings": match.get("bg_meanings", [])}

            elif content_type == "lessons":
                match = next((t for t in translations if t.get("id") == item.get("id")), None)
                if match:
                    item["translations"] = item.get("translations", {})
                    item["translations"]["bg"] = {
                        "title": match.get("bg_title", ""),
                        "description": match.get("bg_description", "")
                    }

            result.append(item)

        return result


def load_json_file(path: str) -> list[dict]:
    """Load JSON file."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
        if isinstance(data, dict):
            # Handle wrapped format
            return data.get("data", data.get("items", []))
        return data


def save_json_file(path: str, data: list[dict]):
    """Save JSON file."""
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def test_api_key(provider: str, api_key: str, model: str) -> bool:
    """Test if the API key is valid."""
    print(f"Testing {provider} API key...")

    if provider in ("kimi", "moonshot"):
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        data = {
            "model": model,
            "messages": [{"role": "user", "content": "Say 'OK'"}],
            "max_tokens": 10
        }
        try:
            response = requests.post(
                "https://api.moonshot.cn/v1/chat/completions",
                headers=headers,
                json=data,
                timeout=10
            )
            if response.status_code == 200:
                print(f"  ✓ API key is valid!")
                return True
            elif response.status_code == 401:
                print(f"  ✗ API key is invalid (401 Unauthorized)")
                return False
            else:
                print(f"  ✗ Error: {response.status_code} - {response.text[:100]}")
                return False
        except Exception as e:
            print(f"  ✗ Connection error: {e}")
            return False
    else:
        print(f"  (Skipping test for {provider})")
        return True


def main():
    parser = argparse.ArgumentParser(description="Translate Japanese content to Bulgarian")
    parser.add_argument("--type", choices=["words", "kanji", "lessons"],
                        help="Type of content to translate")
    parser.add_argument("--input", help="Input JSON file path")
    parser.add_argument("--output", help="Output JSON file path")
    parser.add_argument("--provider", default="kimi",
                        choices=["kimi", "moonshot", "openai", "anthropic", "openrouter"],
                        help="LLM provider to use (default: kimi)")
    parser.add_argument("--model", default="moonshot-v1-8k",
                        help="Model name (default: moonshot-v1-8k)")
    parser.add_argument("--batch-size", type=int, default=50, help="Batch size for translation")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be translated")
    parser.add_argument("--test-key", action="store_true", help="Test API key and exit")

    args = parser.parse_args()

    # Test API key mode
    if args.test_key:
        config = TranslationConfig(provider=args.provider, model=args.model)
        try:
            translator = LLMTranslator(config)
            success = test_api_key(args.provider, translator.api_key, args.model)
            sys.exit(0 if success else 1)
        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)

    # Validate required args for normal mode
    if not args.type or not args.input:
        print("Error: --type and --input are required (unless using --test-key)")
        parser.print_help()
        sys.exit(1)

    # Load input data
    print(f"Loading {args.type} from {args.input}...")
    items = load_json_file(args.input)
    print(f"Loaded {len(items)} items")

    if args.dry_run:
        print(f"\nDry run - would translate {len(items)} {args.type}")
        print(f"Batches: {(len(items) + args.batch_size - 1) // args.batch_size}")
        for item in items[:3]:
            print(f"  - {item}")
        if len(items) > 3:
            print(f"  ... and {len(items) - 3} more")
        return

    if not args.output:
        print("Error: --output required (unless using --dry-run)")
        sys.exit(1)

    # Setup translator
    config = TranslationConfig(
        provider=args.provider,
        model=args.model,
        batch_size=args.batch_size
    )

    try:
        translator = LLMTranslator(config)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    # Process in batches
    all_translated = []
    total_batches = (len(items) + args.batch_size - 1) // args.batch_size

    for i in range(0, len(items), args.batch_size):
        batch = items[i:i + args.batch_size]
        batch_num = i // args.batch_size + 1

        print(f"\nTranslating batch {batch_num}/{total_batches} ({len(batch)} items)...")

        try:
            translated = translator.translate_batch(batch, args.type)
            all_translated.extend(translated)

            # Save progress after each batch
            save_json_file(args.output, all_translated)
            print(f"  Saved progress: {len(all_translated)} items")

            # Rate limiting
            if i + args.batch_size < len(items):
                time.sleep(config.delay_seconds)

        except Exception as e:
            print(f"  Error in batch {batch_num}: {e}")
            print(f"  Saving progress so far...")
            save_json_file(args.output, all_translated)
            raise

    print(f"\n✓ Translation complete! Saved to {args.output}")
    print(f"  Total items: {len(all_translated)}")


if __name__ == "__main__":
    main()
