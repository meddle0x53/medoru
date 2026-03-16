# Iteration 24B: Content Translation (Kanji, Words, Lessons)

**Status**: 🚧 IN PROGRESS  
**Priority**: 🟡 MEDIUM  
**Started**: March 16, 2026  
**Depends On**: Iteration 24A (UI i18n foundation)

## 📊 Progress Summary

### Bulgarian Translation Status
| Level | Total Words | Translated | Status |
|-------|-------------|------------|--------|
| **N5** | 3,168 | 3,168 | ✅ 100% Complete |
| **N4** | 6,808 | 6,808 | ✅ 100% Complete |
| **N3** | 135,847 | 0 | ⏳ Ready to start |
| **Kanji** | 2,212 | 2,212 | ✅ 100% Complete |
| **Lessons** | 101 | 101 | ✅ 100% Complete |

**Translation Method**: Manual batch processing using pipe-separated format (50 words → later 150 words for N3)

**Total Translated**: 10,089 words (N5 + N4) + 2,212 kanji + 101 lessons

## Overview

Translate all learning content (kanji meanings, word meanings, lesson titles/descriptions) into Bulgarian and Japanese. Use JSONB storage for extensibility. When a user selects Bulgarian, all meanings appear in Bulgarian; test questions validate against Bulgarian meanings.

## Database Schema Changes

### Kanji Table
```elixir
# Add translations JSONB field
field :translations, :map, default: %{
  "en" => %{"meanings" => [...]},  # existing meanings array
  "bg" => %{"meanings" => [...]},  # Bulgarian translations
  "ja" => %{"meanings" => [...], "description" => "..."}  # Japanese explanations
}
```

### Words Table
```elixir
# Add translations JSONB field
field :translations, :map, default: %{
  "en" => %{"meaning" => "..."},   # existing
  "bg" => %{"meaning" => "..."},   # Bulgarian
  "ja" => %{"meaning" => "...", "notes" => "..."}  # Japanese explanation
}
```

### Lessons Table (System Lessons Only)
```elixir
# Add translations JSONB field
field :translations, :map, default: %{
  "en" => %{"title" => "...", "description" => "..."},
  "bg" => %{"title" => "...", "description" => "..."},
  "ja" => %{"title" => "...", "description" => "..."}
}
```

## Migration Files to Create

```elixir
# priv/repo/migrations/xxx_add_translations_to_kanji.exs
alter table(:kanji) do
  add :translations, :map, default: %{}
end

# priv/repo/migrations/xxx_add_translations_to_words.exs
alter table(:words) do
  add :translations, :map, default: %{}
end

# priv/repo/migrations/xxx_add_translations_to_lessons.exs
alter table(:lessons) do
  add :translations, :map, default: %{}
end
```

## Context Functions to Add

### Content Context
```elixir
# Get kanji with localized meanings
def get_kanji_with_locale(id, locale) do
  kanji = get_kanji!(id)
  %{kanji | meanings: get_translated_meanings(kanji, locale)}
end

# Get word with localized meaning
def get_word_with_locale(id, locale) do
  word = get_word!(id)
  %{word | meaning: get_translated_meaning(word, locale)}
end

# Search words - searches in current locale
def search_words(query, locale, opts \\ []) do
  # Search in translations->locale->meaning
  # Fall back to English if no translation
end

# List lessons with localized titles
def list_lessons_with_locale(level, locale) do
  lessons = list_lessons_by_level(level)
  Enum.map(lessons, &localize_lesson(&1, locale))
end
```

### Tests Context
```elixir
# Generate test with localized content
def generate_localized_test(lesson_id, locale) do
  # Uses translations for question generation
  # "What is the meaning of X?" checks against locale meaning
end

# Validate reading text answer against locale
def validate_reading_answer(step, answer, locale) do
  # Compare against translations[locale].meaning
end
```

## Translation Script

Create a Mix task to translate all content using tokens:

```elixir
# lib/mix/tasks/medoru.translate_content.ex
defmodule Mix.Tasks.Medoru.TranslateContent do
  @moduledoc """
  Translates all kanji and word meanings to target locale.
  
  ## Examples
  
      mix medoru.translate_content --locale bg
      mix medoru.translate_content --locale ja
      mix medoru.translate_content --locale all
  """
  
  # For each kanji:
  # - Take English meanings array
  # - Translate to target language preserving nuances
  # - Store in translations["bg"]["meanings"]
  
  # For each word:
  # - Take English meaning
  # - Translate to target language
  # - Add Japanese explanation if locale=ja
  # - Store in translations["bg"]["meaning"]
  
  # For each system lesson:
  # - Translate title and description
end
```

## Content Translation Scope

### Kanji
**English (Source)**:
```elixir
%Kanji{
  character: "日",
  meanings: ["sun", "day", "Japan"],
  stroke_count: 4,
  # ...
}
```

**Bulgarian**:
```elixir
%{
  "bg" => %{
    "meanings" => ["слънце", "ден", "Япония"]
  }
}
```

**Japanese**:
```elixir
%{
  "ja" => %{
    "meanings" => ["太陽", "日", "日本"],
    "description" => "「ひ」「にち」などと読む。天体の太陽や、1日を表す基本的な漢字。"
  }
}
```

### Words
**English**:
```elixir
%Word{
  text: "日本",
  reading: "にほん",
  meaning: "Japan"
}
```

**Bulgarian**:
```elixir
%{
  "bg" => %{
    "meaning" => "Япония"
  }
}
```

**Japanese**:
```elixir
%{
  "ja" => %{
    "meaning" => "日本",
    "notes" => "漢字は「日の本」で、太陽の起源の国という意味。"
  }
}
```

### Lessons (System Only)
**English**:
- Title: "Basic Greetings"
- Description: "Learn essential Japanese greetings"

**Bulgarian**:
- Title: "Основни поздрави"
- Description: "Научете основни японски поздрави"

**Japanese**:
- Title: "基本的な挨拶"
- Description: "日本語の基本的な挨拶を学びましょう"

## LiveView Updates

### Display Layer
All views need to use localized content:

```elixir
# In mount or handle_params:
locale = socket.assigns.current_scope.locale || "en"
kanji = Content.get_kanji_with_locale(id, locale)

# In template:
<div>{@kanji.meanings |> Enum.join(", ")}</div>
```

### Test Generation
When generating tests, use the locale for:
- Question text ("What is the meaning of X?")
- Correct answer validation (compare against localized meaning)
- Hint text

### Example: Reading Text Question
```elixir
# English locale:
"What is the meaning of 日本?"
Answer validated against: "Japan"

# Bulgarian locale:
"Какво означава 日本?"
Answer validated against: "Япония"

# Japanese locale:
"日本の意味は何ですか？"
Answer validated against: "日本" (or accept "にほん" as reading)
```

## Search Functionality

Search should work in all three languages:

```elixir
# User searches "слънце" (sun in Bulgarian)
# Should find: 日 (meanings include "слънце")

# User searches "太陽" (sun in Japanese)
# Should find: 日 (meanings include "太陽")

def search_content(query, locale) do
  # Search in:
  # 1. Original text (kanji/reading)
  # 2. translations[locale].meaning
  # 3. translations["en"].meaning (fallback)
end
```

## Performance Considerations

1. **Database Indexing**:
   ```sql
   -- Create GIN index for JSONB queries
   CREATE INDEX idx_kanji_translations ON kanji USING GIN (translations);
   CREATE INDEX idx_words_translations ON words USING GIN (translations);
   ```

2. **Caching**:
   - Cache localized content in ETS or Redis
   - Key: `{:kanji, id, locale}`
   - TTL: 1 hour (translations rarely change)

3. **Preloading**:
   - When listing lessons, preload translations
   - Avoid N+1 queries

## Translation Quality (Token Usage)

### Guidelines for AI Translation
1. **Kanji Meanings**:
   - Bulgarian: Use most common equivalent
   - Japanese: Use native Japanese definitions, not just katakana of English

2. **Words**:
   - Bulgarian: Consider part of speech (noun, verb, adjective)
   - Japanese: Add contextual notes where helpful

3. **Lessons**:
   - Keep titles concise
   - Descriptions can be more descriptive

### Example Token Prompt
```
Translate the following English word meaning to Bulgarian.
Word: 日本
Reading: にほん
English Meaning: Japan

Provide:
1. Most common Bulgarian translation
2. Alternative translations if applicable
3. Part of speech

Output as JSON:
{
  "meaning": "Япония",
  "alternatives": [],
  "pos": "noun"
}
```

## Testing

### Unit Tests
- [ ] `get_kanji_with_locale/2` returns correct meanings
- [ ] `get_word_with_locale/2` returns correct meaning
- [ ] Fallback to English when translation missing
- [ ] Search works in all three languages

### Integration Tests
- [ ] Lesson list shows translated titles
- [ ] Test questions use translated meanings
- [ ] Writing tests work (kanji character is same regardless of locale)
- [ ] Daily test validates against locale meaning

### User Tests
- [ ] Bulgarian user can complete daily test with Bulgarian meanings
- [ ] Japanese user sees Japanese lesson descriptions
- [ ] Switching locale updates content immediately

## Backwards Compatibility

- Existing code using `kanji.meanings` continues to work (defaults to English)
- Migration populates `translations["en"]` from existing data
- Custom lessons not translated (created in creator's locale)

## User Approval Required

### Bulgarian Content
- [ ] Sample kanji meanings reviewed
- [ ] Sample word meanings reviewed
- [ ] Sample lesson titles/descriptions reviewed
- [ ] Full dataset approved

### Japanese Content
- [ ] Kanji descriptions (explanations in Japanese) reviewed
- [ ] Word notes reviewed
- [ ] Lesson content reviewed
- [ ] Full dataset approved

## Migration Rollback Plan

If issues found:
1. Revert to using original `meanings` field
2. Keep `translations` column for future fix
3. No data loss (original columns preserved)
