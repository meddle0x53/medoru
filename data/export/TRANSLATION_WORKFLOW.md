# Bulgarian Translation Workflow

## Current Status
- ✅ Kanji: 100% complete (2,212/2,212)
- ✅ Lessons: 100% complete (101/101)
- ✅ N5 Words: 100% complete (3,168/3,168)
- ⏳ N4 Words: 0% (0/6,808)
- ⏳ N3 Words: 0% (0/135,847)

## Files Location
All export/import files are in `data/export/`:
- `words_n5.json` - N5 words (translated ✓)
- `words_n4.json` - N4 words (pending)
- `words_n3.json` - N3 words (pending)
- `kanji_all.json` - All kanji (translated ✓)
- `lessons.json` - All lessons (translated ✓)

## Resumable Translation

### Option 1: Continue with Kimi Code (Recommended)
Since you're already using Kimi Code, the easiest way is to continue in batches:

```bash
# Translate N4 words in batches of 500
cd data/scripts
python3 translate_resumable.py \
  --type words \
  --input ../export/words_n4.json \
  --output ../export/words_n4_bg.json \
  --batch-size 500

# If interrupted, resume with:
python3 translate_resumable.py \
  --type words \
  --input ../export/words_n4.json \
  --output ../export/words_n4_bg.json \
  --batch-size 500 \
  --resume
```

### Option 2: Use LLM API
Set up an API key and use the translation scripts:

```bash
# Using OpenRouter (easiest)
export OPENROUTER_API_KEY="sk-or-v1-..."
python translate_bg.py \
  --type words \
  --input ../export/words_n4.json \
  --output ../export/words_n4_bg.json \
  --provider openrouter \
  --batch-size 50

# Or using Gemini (free tier available)
export GEMINI_API_KEY="..."
python translate_gemini.py \
  --type words \
  --input ../export/words_n4.json \
  --output ../export/words_n4_bg.json
```

### Option 3: Manual Batches with Kimi
Translate directly in the conversation by processing files in batches.

## Importing Translations

After each batch is translated:

```bash
# Import N4 words
mix medoru.translations import words --input=data/export/words_n4_bg.json

# Import N3 words  
mix medoru.translations import words --input=data/export/words_n3_bg.json

# Check status
mix medoru.translations status
```

## Cost Estimation (API route)

- N4 words (6,808): ~$0.50-1.00
- N3 words (135,847): ~$10-15
- Total remaining: ~$11-16

Using Google Gemini Flash (cheapest option via OpenRouter).

## Priority Order

1. **N4 words** (6,808) - Essential for elementary learners
2. **N3 words** - Start with first 10,000 most common
3. **Japanese definitions** - For Japanese-Japanese learning mode

## Notes

- Progress is automatically saved after each batch
- Failed translations can be resumed without losing progress
- The `*.progress.json` files track which items are done
- You can stop and resume at any time
