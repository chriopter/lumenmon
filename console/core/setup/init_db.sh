#!/bin/bash
# Initialize persistent SQLite files and permissions for Rails.
# Keeps the data volume writable for the app and MQTT runtime.
set -euo pipefail

mkdir -p /data /data/mqtt
chmod 775 /data

DB_PATH="${LUMENMON_DB_PATH:-/data/lumenmon.sqlite3}"
touch "$DB_PATH"
chmod 664 "$DB_PATH"

echo "[db] SQLite database initialized at $DB_PATH"
