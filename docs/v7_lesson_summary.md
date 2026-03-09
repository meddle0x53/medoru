# v7 Lesson Generation Summary

## Generation Completed
**Date:** 2026-03-09  
**Total Lessons:** 300 (100 N5 + 100 N4 + 100 N3)

## Data Sources
- **Core 6000:** 5,996 entries from `data/anki2.txt`
- **Database supplement:** Additional words to reach target counts
- **Total word pool:** 7,296 words
  - N5: 1,500 words
  - N4: 1,800 words  
  - N3: 3,996 words

## Lesson Distribution

### N5 (Difficulty 5)
- **Total:** 100 lessons
- **Grammar:** 87 lessons
- **Reading:** 3 lessons
- **Writing:** 5 lessons
- **Listening:** 5 lessons

### N4 (Difficulty 4)
- **Total:** 100 lessons
- **Grammar:** 87 lessons
- **Reading:** 3 lessons
- **Writing:** 5 lessons
- **Listening:** 5 lessons

### N3 (Difficulty 3)
- **Total:** 100 lessons
- **Grammar:** 87 lessons
- **Reading:** 3 lessons
- **Writing:** 5 lessons
- **Listening:** 5 lessons

## Word-Lesson Links
- **Total links:** 4,421
- **Average words per lesson:** ~15

## Sample N5 Lessons
1. Basic Greetings (grammar, 14 words)
2. Numbers 1-10 (grammar, 15 words)
3. Numbers 11-100 (grammar, 14 words)
4. Time Basics (grammar, 15 words)
5. Days of Week (grammar, 15 words)
6. Family Basics (grammar, 15 words)
7. Pronouns (grammar, 15 words)
8. Common Verbs 1 (grammar, 15 words)
9. Common Verbs 2 (grammar, 15 words)
10. Question Words (reading, 8 words)

## Topic Categories

### N5 Topics (100)
- Foundation (1-10): Greetings, Numbers, Time, Family, Pronouns, Verbs
- Daily Life (11-30): Food, Shopping, Money, Colors, Weather, etc.
- Actions (31-45): Verbs, Adjectives, Adverbs, Body parts, Health
- Places (46-60): Town, Stores, Nature, Animals, Directions
- Intermediate (61-80): Time expressions, Preferences, Hobbies
- Review (81-100): Reading practice, Grammar review

### N4 Topics (100)
- Foundations (1-15): Counters, Verb forms (te/ta/nai/potential/etc.)
- Abstract Concepts (16-35): Feelings, Thoughts, Plans, Dreams
- Society (36-55): Company, Business, Media, Technology
- Relationships (56-75): Friends, Dating, Travel, Food
- Review (76-100): Grammar, Reading comprehension

### N3 Topics (100)
- Advanced Grammar (1-25): Causative-passive, Honorifics, Speech patterns
- Academic (26-50): Research, Education, Employment, Economics
- Modern Life (51-75): Urban/Rural life, Health, Politics, Society
- Advanced Topics (76-100): Literature, Science, Complex reading

## Files Generated
- `data/v7_word_pool.json` - Raw parsed word data
- `data/v7_lesson_pool.json` - Enriched word pool with DB IDs
- `docs/v7_lesson_design.md` - Detailed lesson design document

## Scripts Created
- `priv/repo/parse_anki_export.exs` - Parse Anki Core 6000 data
- `priv/repo/enrich_word_pool.exs` - Enrich with database IDs
- `lib/mix/tasks/medoru.generate_lessons_v7.ex` - Lesson generator
- `priv/repo/verify_v7_lessons.exs` - Verification script

## Usage
```bash
# Regenerate lessons (WARNING: Deletes existing N5-N3 lessons!)
mix medoru.generate_lessons_v7

# Dry run (no database changes)
mix medoru.generate_lessons_v7 --dry-run

# Verify created lessons
mix run priv/repo/verify_v7_lessons.exs
```

## Notes
- Lessons are ordered sequentially within each level
- Each lesson has 14-15 words on average
- Reading lessons have 8 words for focused practice
- Word IDs are de-duplicated to prevent constraint violations
- Existing lessons and progress are deleted before regeneration
