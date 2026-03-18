#!/bin/bash
# Restore content to production database

set -e  # Exit on error

DB_URL="${DATABASE_URL:-postgres://localhost/medoru_prod}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Medoru Production Database Restore"
echo "=========================================="
echo ""
echo "Database: $DB_URL"
echo ""

# Check if files exist
for file in "$SCRIPT_DIR"/0*.csv; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file $file not found"
        exit 1
    fi
done

echo "Step 1: Clearing existing content..."
psql "$DB_URL" -c "
TRUNCATE TABLE lesson_words, lesson_kanjis, lessons, word_kanjis, 
                  kanji_readings, words, kanji, test_steps, tests CASCADE;
" 2>/dev/null || echo "  (Tables may not exist yet, continuing...)"

echo ""
echo "Step 2: Importing kanji..."
psql "$DB_URL" -c "\copy kanji FROM '$SCRIPT_DIR/01_kanji.csv'"

echo "Step 3: Importing kanji_readings..."
psql "$DB_URL" -c "\copy kanji_readings FROM '$SCRIPT_DIR/02_kanji_readings.csv'"

echo "Step 4: Importing words..."
psql "$DB_URL" -c "\copy words FROM '$SCRIPT_DIR/03_words.csv'"

echo "Step 5: Importing word_kanjis..."
psql "$DB_URL" -c "\copy word_kanjis FROM '$SCRIPT_DIR/04_word_kanjis.csv'"

echo "Step 6: Importing lessons (without test_id)..."
psql "$DB_URL" -c "\copy lessons FROM '$SCRIPT_DIR/05_lessons.csv'"

echo "Step 7: Importing lesson_kanjis..."
psql "$DB_URL" -c "\copy lesson_kanjis FROM '$SCRIPT_DIR/06_lesson_kanjis.csv'"

echo "Step 8: Importing lesson_words..."
psql "$DB_URL" -c "\copy lesson_words FROM '$SCRIPT_DIR/07_lesson_words.csv'"

echo "Step 9: Importing tests..."
psql "$DB_URL" -c "\copy tests FROM '$SCRIPT_DIR/08_tests.csv'"

echo "Step 10: Importing test_steps..."
psql "$DB_URL" -c "\copy test_steps FROM '$SCRIPT_DIR/09_test_steps.csv'"

echo "Step 11: Linking lessons to tests..."
# Use a single psql session with heredoc
psql "$DB_URL" << EOF
CREATE TEMP TABLE tmp_lt (id uuid, test_id uuid);
\copy tmp_lt FROM '$SCRIPT_DIR/10_lesson_test_ids.csv'
UPDATE lessons l SET test_id = t.test_id FROM tmp_lt t WHERE l.id = t.id;
EOF

echo ""
echo "=========================================="
echo "✅ Restore Complete!"
echo "=========================================="
echo ""
echo "Verifying counts:"
psql "$DB_URL" -c "
SELECT 'kanji' as table_name, COUNT(*) as rows FROM kanji
UNION ALL SELECT 'kanji_readings', COUNT(*) FROM kanji_readings
UNION ALL SELECT 'words', COUNT(*) FROM words
UNION ALL SELECT 'word_kanjis', COUNT(*) FROM word_kanjis
UNION ALL SELECT 'lessons', COUNT(*) FROM lessons
UNION ALL SELECT 'tests', COUNT(*) FROM tests
UNION ALL SELECT 'test_steps', COUNT(*) FROM test_steps
ORDER BY rows DESC;
"
