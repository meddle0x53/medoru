# Production Database Restore

## Files

| File | Size | Description |
|------|------|-------------|
| `medoru_prod_data.sql` | ~96MB | Clean data dump for production |

## Prerequisites

1. Database `medoru_prod` created
2. Migrations run (schema exists)
3. User has write access

## Steps

### 1. Create database and run migrations

```bash
# Create database
createdb medoru_prod

# Run migrations
MIX_ENV=prod mix ecto.setup
# or
MIX_ENV=prod mix ecto.migrate
```

### 2. Clear any seed data (optional)

```bash
psql -d medoru_prod -c "
TRUNCATE TABLE kanji CASCADE;
TRUNCATE TABLE words CASCADE;
TRUNCATE TABLE lessons CASCADE;
"
```

### 3. Restore data

```bash
psql -d medoru_prod < data/medoru_prod_data.sql
```

Or with custom format (faster):

```bash
pg_restore --data-only -d medoru_prod --no-owner --no-privileges data/medoru_content.dump
```

### 4. Fix test_id references (if needed)

If you get FK errors about `lessons.test_id`:

```bash
psql -d medoru_prod -c "
UPDATE lessons SET test_id = NULL 
WHERE test_id IS NOT NULL 
AND test_id NOT IN (SELECT id FROM tests);
"
```

### 5. Verify

```bash
psql -d medoru_prod -c "
SELECT 'kanji', COUNT(*) FROM kanji UNION ALL
SELECT 'words', COUNT(*) FROM words UNION ALL
SELECT 'lessons', COUNT(*) FROM lessons;
"
```

Expected:
- kanji: 2,212
- words: 145,823
- lessons: 101

## Notes

- The dump includes ONLY content tables (kanji, words, lessons, etc.)
- User data, tests, classrooms are NOT included
- `lessons.test_id` may be NULL for lessons that reference tests not in dump
