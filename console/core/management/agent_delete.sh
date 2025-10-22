#!/bin/bash
# Deletes an agent completely: drops all database tables, removes system user and home directory.
# Called by management API endpoint. Takes agent_id as first argument. Logs to /data/agents.log.
set -euo pipefail

AGENT_ID="${1:-}"

if [ -z "$AGENT_ID" ]; then
    echo "ERROR: agent_id required"
    exit 1
fi

# Validate agent_id format (must start with id_)
if [[ ! "$AGENT_ID" =~ ^id_ ]]; then
    echo "ERROR: invalid agent_id format (must start with id_)"
    exit 1
fi

echo "[DELETE] Starting deletion for agent: $AGENT_ID"

# 1. Drop all database tables for this agent
DB_PATH="/data/metrics.db"
if [ -f "$DB_PATH" ]; then
    echo "[DELETE] Dropping database tables..."

    # Get all tables for this agent
    TABLES=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '${AGENT_ID}_%';" 2>/dev/null || echo "")

    if [ -n "$TABLES" ]; then
        while IFS= read -r table; do
            if [ -n "$table" ]; then
                echo "[DELETE]   Dropping table: $table"
                sqlite3 "$DB_PATH" "DROP TABLE IF EXISTS \"$table\";" 2>/dev/null || true
            fi
        done <<< "$TABLES"
    else
        echo "[DELETE]   No tables found for agent"
    fi
else
    echo "[DELETE]   Database not found, skipping table deletion"
fi

# 2. Delete system user (removes home directory and SSH keys with -r flag)
if id "$AGENT_ID" &>/dev/null; then
    echo "[DELETE] Removing system user..."
    userdel -r "$AGENT_ID" 2>/dev/null || {
        echo "[DELETE]   WARNING: failed to remove user, continuing..."
    }
else
    echo "[DELETE]   User does not exist, skipping user deletion"
fi

# 3. Clean up any remaining files in /data/agents
AGENT_DIR="/data/agents/$AGENT_ID"
if [ -d "$AGENT_DIR" ]; then
    echo "[DELETE] Removing agent directory..."
    rm -rf "$AGENT_DIR" 2>/dev/null || {
        echo "[DELETE]   WARNING: failed to remove directory, continuing..."
    }
fi

# 4. Log deletion
echo "[$(date)] Deleted agent: $AGENT_ID" >> /data/agents.log

echo "[DELETE] Agent deletion complete: $AGENT_ID"
exit 0
