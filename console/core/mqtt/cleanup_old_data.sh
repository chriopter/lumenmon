#!/bin/bash
# Deletes data older than 7 days from all metrics tables.
# Runs daily to keep database size manageable.

DB_PATH="/data/metrics.db"
DAYS_TO_KEEP=7
CUTOFF_TIMESTAMP=$(($(date +%s) - (DAYS_TO_KEEP * 86400)))

echo "[cleanup] Starting cleanup of data older than $DAYS_TO_KEEP days..."
echo "[cleanup] Cutoff timestamp: $CUTOFF_TIMESTAMP ($(date -d @$CUTOFF_TIMESTAMP))"

# Get list of all tables
TABLES=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'id_%'")

TOTAL_DELETED=0
TABLE_COUNT=0

for table in $TABLES; do
    # Delete old rows
    DELETED=$(sqlite3 "$DB_PATH" "DELETE FROM \"$table\" WHERE timestamp < $CUTOFF_TIMESTAMP; SELECT changes()")

    if [ "$DELETED" -gt 0 ]; then
        echo "[cleanup] $table: deleted $DELETED rows"
        TOTAL_DELETED=$((TOTAL_DELETED + DELETED))
    fi

    TABLE_COUNT=$((TABLE_COUNT + 1))
done

# Vacuum to reclaim space
echo "[cleanup] Vacuuming database..."
sqlite3 "$DB_PATH" "VACUUM"

echo "[cleanup] ✅ Cleanup complete"
echo "[cleanup] Tables processed: $TABLE_COUNT"
echo "[cleanup] Total rows deleted: $TOTAL_DELETED"
