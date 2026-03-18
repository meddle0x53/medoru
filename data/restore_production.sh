#!/bin/bash
# Restore content + referenced tests to production database

DB_URL="${DATABASE_URL:-postgres://localhost/medoru_prod}"

echo "Restoring content + tests to production database..."
echo "DB: $DB_URL"
echo ""

echo "1. Clearing existing content data..."
psql "$DB_URL" -c "
TRUNCATE TABLE lesson_words, lesson_kanjis, word_kanjis, kanji_readings, words, lessons, kanji CASCADE;
TRUNCATE TABLE test_steps, tests;
" 2>/dev/null

echo ""
echo "2. Restoring kanji..."
psql -d medoru_dev -c "COPY kanji TO STDOUT" | psql "$DB_URL" -c "COPY kanji FROM STDIN"

echo "3. Restoring kanji_readings..."
psql -d medoru_dev -c "COPY kanji_readings TO STDOUT" | psql "$DB_URL" -c "COPY kanji_readings FROM STDIN"

echo "4. Restoring words..."
psql -d medoru_dev -c "COPY words TO STDOUT" | psql "$DB_URL" -c "COPY words FROM STDIN"

echo "5. Restoring word_kanjis..."
psql -d medoru_dev -c "COPY word_kanjis TO STDOUT" | psql "$DB_URL" -c "COPY word_kanjis FROM STDIN"

echo "6. Restoring tests (only those referenced by lessons)..."
psql -d medoru_dev -c "
COPY (
  SELECT id, title, description, difficulty, time_limit, passing_score, test_type, lesson_id, creator_id, inserted_at, updated_at 
  FROM tests 
  WHERE id IN (SELECT test_id FROM lessons WHERE test_id IS NOT NULL)
) TO STDOUT
" | psql "$DB_URL" -c "COPY tests FROM STDIN"

echo "7. Restoring test_steps..."
psql -d medoru_dev -c "
COPY (
  SELECT id, test_id, step_number, step_type, question_type, question, options, correct_answer, explanation, points, hints, time_limit, kanji_id, word_id, inserted_at, updated_at 
  FROM test_steps 
  WHERE test_id IN (SELECT test_id FROM lessons WHERE test_id IS NOT NULL)
) TO STDOUT
" | psql "$DB_URL" -c "COPY test_steps FROM STDIN"

echo "8. Restoring lessons..."
psql -d medoru_dev -c "
COPY (SELECT id, title, description, difficulty, order_index, inserted_at, updated_at, lesson_type, test_id, translations FROM lessons) TO STDOUT
" | psql "$DB_URL" -c "COPY lessons FROM STDIN"

echo "9. Restoring lesson_kanjis..."
psql -d medoru_dev -c "COPY lesson_kanjis TO STDOUT" | psql "$DB_URL" -c "COPY lesson_kanjis FROM STDIN"

echo "10. Restoring lesson_words..."
psql -d medoru_dev -c "COPY lesson_words TO STDOUT" | psql "$DB_URL" -c "COPY lesson_words FROM STDIN"

echo ""
echo "✅ Restore complete!"
echo ""
echo "Verifying counts:"
psql "$DB_URL" -c "
SELECT 'kanji' as table_name, COUNT(*) as rows FROM kanji
UNION ALL SELECT 'kanji_readings', COUNT(*) FROM kanji_readings
UNION ALL SELECT 'words', COUNT(*) FROM words
UNION ALL SELECT 'word_kanjis', COUNT(*) FROM word_kanjis
UNION ALL SELECT 'tests', COUNT(*) FROM tests
UNION ALL SELECT 'test_steps', COUNT(*) FROM test_steps
UNION ALL SELECT 'lessons', COUNT(*) FROM lessons
UNION ALL SELECT 'lesson_kanjis', COUNT(*) FROM lesson_kanjis
UNION ALL SELECT 'lesson_words', COUNT(*) FROM lesson_words
ORDER BY rows DESC;
"
