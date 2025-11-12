#!/bin/bash
# Initialize database with agent registry table.
# Called on console startup.

DB_PATH="/data/metrics.db"

echo "[db-init] Initializing database..."

# Create agent registry table
sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS agent_registry (
    agent_id TEXT PRIMARY KEY,
    hostname TEXT,
    first_seen INTEGER,
    last_seen INTEGER
);

CREATE INDEX IF NOT EXISTS idx_agent_last_seen ON agent_registry(last_seen);
EOF

echo "[db-init] ✅ Database initialized"
echo "[db-init] - agent_registry table created"
