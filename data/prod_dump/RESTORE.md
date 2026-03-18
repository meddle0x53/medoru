# Production Database Restore Instructions

## Prerequisites

1. PostgreSQL installed on production server
2. Database `medoru_prod` created
3. Migrations run (schema exists)
4. User has write access to database

## Quick Start

```bash
# 1. Create database and run migrations
createdb medoru_prod
MIX_ENV=prod mix ecto.setup

# 2. Run the restore script
./restore.sh
```

## Manual Steps

If the script doesn't work, follow these steps:

```bash
# 1. Clear existing content (optional, for clean restore)
psql -d medoru_prod -c "
TRUNCATE TABLE lesson_words, lesson_kanjis, lessons, word_kanjis, 
                  kanji_readings, words, kanji, test_steps, tests CASCADE;
"

# 2. Import base content (in order)
\copy kanji FROM '01_kanji.csv'
\copy kanji_readings FROM '02_kanji_readings.csv'
\copy words FROM '03_words.csv'
\copy word_kanjis FROM '04_word_kanjis.csv'
\copy lessons FROM '05_lessons.csv'
\copy lesson_kanjis FROM '06_lesson_kanjis.csv'
\copy lesson_words FROM '07_lesson_words.csv'
\copy tests FROM '08_tests.csv'
\copy test_steps FROM '09_test_steps.csv'

# 3. Link lessons to tests
psql -d medoru_prod -c "
CREATE TEMP TABLE tmp_lt (id uuid, test_id uuid);
\copy tmp_lt FROM '10_lesson_test_ids.csv'
UPDATE lessons l SET test_id = t.test_id FROM tmp_lt t WHERE l.id = t.id;
"
```

## File Descriptions

| File | Table | Rows (approx) |
|------|-------|---------------|
| 01_kanji.csv | kanji | 2,212 |
| 02_kanji_readings.csv | kanji_readings | 5,784 |
| 03_words.csv | words | 145,823 |
| 04_word_kanjis.csv | word_kanjis | 400,087 |
| 05_lessons.csv | lessons | 101 |
| 06_lesson_kanjis.csv | lesson_kanjis | 0 |
| 07_lesson_words.csv | lesson_words | 479 |
| 08_tests.csv | tests | 101 |
| 09_test_steps.csv | test_steps | 2,182 |
| 10_lesson_test_ids.csv | - | 101 (mapping) |

## Verification

After restore, verify counts:

```bash
psql -d medoru_prod -c "
SELECT 'kanji', COUNT(*) FROM kanji UNION ALL
SELECT 'words', COUNT(*) FROM words UNION ALL
SELECT 'lessons', COUNT(*) FROM lessons UNION ALL
SELECT 'tests', COUNT(*) FROM tests;
"
```

Expected:
- kanji: 2,212
- words: 145,823
- lessons: 101
- tests: 101
