# System Vocabulary Lessons

This document explains how system lessons are automatically generated from existing words in the database.

## Overview

System lessons are auto-generated vocabulary lessons accessible to all users. They organize words by JLPT level with 3-5 words per lesson, ordered by frequency (most common first).

## Generation

### Mix Task

```bash
# Generate all system lessons (N5-N1)
mix medoru.generate_lessons

# Generate only for specific level
mix medoru.generate_lessons --level N5

# Preview what would be created
mix medoru.generate_lessons --dry-run

# Regenerate (delete existing first)
mix medoru.generate_lessons --force
```

### Lesson Structure

| Property | Value |
|----------|-------|
| **Words per lesson** | 4 (range: 3-5) |
| **Ordering** | By usage_frequency (most common first) |
| **Difficulty** | Matches JLPT level (5=N5, 4=N4, 3=N3+) |
| **Type** | `:reading` |
| **Title** | First suitable word + "Vocabulary" |
| **Description** | Lists all words in the lesson |

## Display Order

When viewing lessons, they are sorted by:

1. **JLPT Level** (easiest first: N5 → N4 → N3 → N2 → N1)
2. **Word Length** (shorter words first - easier to learn)
3. **Order Index** (for consistent pagination)

This ensures students start with the easiest, shortest, most common words.

### Naming Rules

Lesson titles are generated from the first word that:
- Is 2-6 characters long
- Contains actual kanji
- Doesn't start with particles (お, ご, は, etc.)

Examples:
- "日本 Vocabulary" ✓
- "大きい Vocabulary" ✓
- "お金 Vocabulary" ✗ (starts with お)

## Current Stats

| Level | Lessons | Words | Avg Words/Lesson |
|-------|---------|-------|------------------|
| N5 | 787 | 3,148 | 4.0 |
| N4 | 1,702 | 6,808 | 4.0 |
| N3+ | 33,962 | 135,847 | 4.0 |
| N2 | 0 | 0 | - |
| N1 | 0 | 0 | - |
| **Total** | **36,451** | **145,803** | **4.0** |

## JLPT Level Calculation

Words are classified by kanji composition:

| Level | Rule | Example |
|-------|------|---------|
| N5 | All kanji are N5 | 日本 (日=N5, 本=N5) |
| N4 | All kanji are N5 or N4 | 会社 (会=N4, 社=N4) |
| N3+ | Contains any N3+ or unknown kanji | 勉強 (勉=N3+, 強=N4) |

**Note**: Most words are N3+ because the database has limited N5/N4 kanji coverage.

## Future Enhancements

### Iteration 14: Multi-Step Test System
- Add tests at the end of each lesson
- Test types: multiple choice, fill-in-the-blank
- Track completion and scores
- Unlock next lesson after passing test

### Possible Improvements
1. **Smarter N3+ classification** - Split into N3, N2, N1 based on actual kanji
2. **Topic-based lessons** - Group by theme (food, travel, business)
3. **Progressive difficulty** - Ensure each lesson has appropriate kanji coverage
4. **Lesson prerequisites** - Require completing N5 before N4

## Database Schema

```elixir
%Lesson{
  title: "日本 Vocabulary",
  description: "Learn 4 common Japanese vocabulary words: 日本, 日本人, 一人, 二人.",
  difficulty: 5,  # N5
  order_index: 1,
  lesson_type: :reading,
  lesson_words: [
    %{word_id: "...", position: 0},  # 日本
    %{word_id: "...", position: 1},  # 日本人
    %{word_id: "...", position: 2},  # 一人
    %{word_id: "...", position: 3},  # 二人
  ]
}
```

## Access Control

System lessons:
- Are **public** (no user restriction)
- Can be viewed by all authenticated users
- Progress is tracked per-user
- Available from the Lessons page

## Files

- `lib/mix/tasks/medoru.generate_lessons.ex` - Mix task for generation
- `lib/medoru/content.ex` - `create_lesson_with_words/2` function
- `lib/medoru/content/lesson.ex` - Lesson schema
- `lib/medoru/content/lesson_word.ex` - Lesson-Word join schema
