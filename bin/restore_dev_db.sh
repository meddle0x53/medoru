#!/bin/bash
# Restore a production database dump into local medoru_dev
# Usage: ./bin/restore_dev_db.sh <dump_file>
#
# Supports:
#   - PostgreSQL custom format dumps (.dump, .dump.gz)
#   - Plain SQL dumps (.sql, .sql.gz)
#
# The local dev database (medoru_dev) will be DROPPED and recreated.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DUMP_FILE="${1:-}"
DEV_DB="medoru_dev"

function show_help() {
    echo "Usage: $0 <dump_file>"
    echo ""
    echo "Restores a production PostgreSQL dump into the local dev database."
    echo "The dev database ($DEV_DB) will be DROPPED and recreated."
    echo ""
    echo "Supported formats:"
    echo "  - Custom format: .dump, .dump.gz"
    echo "  - Plain SQL:     .sql, .sql.gz"
    echo ""
    echo "Examples:"
    echo "  $0 data/backups/medoru_prod_20260101_120000.dump.gz"
    echo "  $0 data/backups/medoru_prod_20260101_120000.dump"
}

if [ -z "$DUMP_FILE" ] || [ "$DUMP_FILE" == "--help" ] || [ "$DUMP_FILE" == "-h" ]; then
    show_help
    exit 0
fi

if [ ! -f "$DUMP_FILE" ]; then
    echo -e "${RED}Error: File not found: $DUMP_FILE${NC}"
    exit 1
fi

# Resolve relative paths
DUMP_FILE="$(cd "$(dirname "$DUMP_FILE")" && pwd)/$(basename "$DUMP_FILE")"

echo -e "${YELLOW}=== Medoru Dev DB Restore ===${NC}"
echo "Dump file: $DUMP_FILE"
echo "Target DB: $DEV_DB"
echo ""

# Check local Postgres is reachable
if ! psql -d postgres -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to local PostgreSQL.${NC}"
    echo "Make sure PostgreSQL is running and peer authentication works for your user."
    exit 1
fi

# Determine dump type and prepare decompression
IS_GZIPPED=false
if [[ "$DUMP_FILE" == *.gz ]]; then
    IS_GZIPPED=true
fi

IS_CUSTOM_FORMAT=false
if [[ "$DUMP_FILE" == *.dump* ]]; then
    IS_CUSTOM_FORMAT=true
fi

# Confirm before destroying dev DB
echo -e "${RED}WARNING: This will DROP the '$DEV_DB' database and recreate it.${NC}"
read -p "Are you sure? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Drop and recreate dev DB
echo -e "${YELLOW}Dropping and recreating $DEV_DB...${NC}"
dropdb --if-exists "$DEV_DB"
createdb "$DEV_DB"

# Restore
echo -e "${YELLOW}Restoring from dump...${NC}"
if [ "$IS_CUSTOM_FORMAT" == true ]; then
    # Custom format: use pg_restore
    if [ "$IS_GZIPPED" == true ]; then
        gunzip -c "$DUMP_FILE" | pg_restore --no-owner --no-privileges -d "$DEV_DB"
    else
        pg_restore --no-owner --no-privileges -d "$DEV_DB" "$DUMP_FILE"
    fi
else
    # Plain SQL: use psql
    if [ "$IS_GZIPPED" == true ]; then
        gunzip -c "$DUMP_FILE" | psql -d "$DEV_DB"
    else
        psql -d "$DEV_DB" -f "$DUMP_FILE"
    fi
fi

echo ""
echo -e "${GREEN}=== Restore Complete ===${NC}"
echo ""

# Quick verification
echo "Row counts:"
psql -d "$DEV_DB" -c "
SELECT 'users', COUNT(*) FROM users UNION ALL
SELECT 'classrooms', COUNT(*) FROM classrooms UNION ALL
SELECT 'conversations', COUNT(*) FROM conversations UNION ALL
SELECT 'kanji', COUNT(*) FROM kanji UNION ALL
SELECT 'words', COUNT(*) FROM words;
"

echo ""
echo -e "${GREEN}Done! You can now start the dev server:${NC}"
echo "  mix phx.server"
