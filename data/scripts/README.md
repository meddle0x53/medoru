# Content Translation Scripts (Iteration 24B)

This directory contains scripts for translating Medoru's learning content (kanji, words, lessons) to Bulgarian and Japanese.

## Overview

- **Bulgarian translations**: Use LLM (Kimi/Moonshot AI) for Japanese → Bulgarian
- **Japanese definitions**: Use Jisho API + KanjiAPI for Japanese → Japanese (monolingual)

## Prerequisites

```bash
pip install requests
```

Set your API key:
```bash
export KIMI_API_KEY="your-kimi-api-key"
```

## Workflow

### 1. Export Data from Database

```bash
# Export all words
mix medoru.translations export words --output=data/export/words.json

# Export all kanji
mix medoru.translations export kanji --output=data/export/kanji.json

# Export all lessons
mix medoru.translations export lessons --output=data/export/lessons.json
```

### 2. Translate to Bulgarian (using Kimi)

```bash
# Translate words (processes in batches, saves progress)
cd data/scripts
python translate_bg.py --type words --input ../export/words.json --output ../export/words_bg.json --provider kimi

# Translate kanji
python translate_bg.py --type kanji --input ../export/kanji.json --output ../export/kanji_bg.json --provider kimi

# Translate lessons
python translate_bg.py --type lessons --input ../export/lessons.json --output ../export/lessons_bg.json --provider kimi
```

Options:
- `--provider`: `kimi` (default), `openai`, `anthropic`, `openrouter`
- `--model`: Model name (default: `moonshot-v1-8k` for Kimi)
- `--batch-size`: Number of items per API call (default: 50)

### 3. Get Japanese Definitions

```bash
# Get J-J definitions for words
python translate_ja.py --type words --input ../export/words.json --output ../export/words_ja.json

# Get kanji info (readings-based definitions)
python translate_ja.py --type kanji --input ../export/kanji.json --output ../export/kanji_ja.json
```

Note: This uses free APIs (Jisho, KanjiAPI) with built-in rate limiting (0.5s delay).

### 4. Import Translations Back to Database

```bash
# Import Bulgarian translations
mix medoru.translations import words --input=data/export/words_bg.json
mix medoru.translations import kanji --input=data/export/kanji_bg.json
mix medoru.translations import lessons --input=data/export/lessons_bg.json

# Import Japanese translations
mix medoru.translations import words --input=data/export/words_ja.json
mix medoru.translations import kanji --input=data/export/kanji_ja.json
```

### 5. Check Translation Status

```bash
mix medoru.translations status
```

## Data Format

### Words
```json
{
  "id": "uuid",
  "text": "日本",
  "reading": "にほん",
  "meaning": "Japan",
  "translations": {
    "bg": {"meaning": "Япония"},
    "ja": {"meaning": "日本の国名"}
  }
}
```

### Kanji
```json
{
  "id": "uuid",
  "character": "日",
  "meanings": ["sun", "day", "Japan"],
  "translations": {
    "bg": {"meanings": ["слънце", "ден", "Япония"]},
    "ja": {"meanings": ["たいよう", "ひ", "にち"]}
  }
}
```

### Lessons
```json
{
  "id": "uuid",
  "title": "Basic Numbers",
  "description": "Learn numbers 1-10",
  "translations": {
    "bg": {
      "title": "Основни числа",
      "description": "Научете числата от 1 до 10"
    },
    "ja": {
      "title": "基本の数字",
      "description": "1から10までの数字を学びましょう"
    }
  }
}
```

## Cost Estimation (Kimi API)

With ~146k words and ~2k kanji:

- Words: 146,000 / 50 per batch = 2,920 API calls
- Kanji: 2,212 / 50 per batch = 45 API calls
- Lessons: 300 / 50 per batch = 6 API calls

Total: ~3,000 API calls for Bulgarian translation of everything.

Kimi pricing (as of March 2025):
- moonshot-v1-8k: ~$0.50 per 1M tokens
- Each batch (~50 items): ~500-1000 tokens
- Estimated total: ~$1.50-3.00 for all content

## Testing

Dry run to see what would be translated without calling API:

```bash
python translate_bg.py --type words --input ../export/words.json --dry-run
```

## Notes

- The scripts save progress after each batch, so you can resume if interrupted
- Failed batches are logged but don't stop the process
- Duplicate translations are merged (import preserves existing translations)
- Fallback to English if translation is missing
