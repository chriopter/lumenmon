#!/bin/bash
# Initialize SQLite database with optimal settings for metrics storage.
# Sets WAL mode for better concurrency and performance. Called on container startup.

DB_PATH="/data/metrics.db"

# Ensure agents group exists (needed for database permissions)
if ! getent group agents > /dev/null 2>&1; then
    echo "[DB] Creating agents group..."
    groupadd agents
fi

# Create database if it doesn't exist and set pragmas
sqlite3 "$DB_PATH" <<EOF
-- Enable Write-Ahead Logging for better concurrent read/write performance
PRAGMA journal_mode=WAL;

-- Reduce fsync frequency (faster writes, safe for metrics data)
PRAGMA synchronous=NORMAL;

-- Set reasonable cache size (2MB)
PRAGMA cache_size=-2000;

-- Vacuum to optimize on startup (only if DB exists and has data)
VACUUM;
EOF

# Set permissions - database must be writable by agents group
chmod 664 "$DB_PATH"
chmod 664 "${DB_PATH}-wal" 2>/dev/null || true
chmod 664 "${DB_PATH}-shm" 2>/dev/null || true
chown root:agents "$DB_PATH"
chown root:agents "${DB_PATH}-wal" 2>/dev/null || true
chown root:agents "${DB_PATH}-shm" 2>/dev/null || true

# Ensure /data directory is accessible by agents group (required for SQLite WAL mode)
# SQLite WAL creates temporary files (-shm, -wal) in the same directory as the database
# Agents need write permission on the directory to create these files
chmod 775 /data
chown root:agents /data

echo "[DB] SQLite database initialized at $DB_PATH"
echo "[DB] Permissions: $(ls -la $DB_PATH)"
