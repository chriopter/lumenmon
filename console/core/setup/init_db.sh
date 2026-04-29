#!/bin/bash
# Initialize persistent SQLite files and permissions for Rails.
# Keeps the data volume writable for the app and MQTT runtime.
set -euo pipefail

DATA_DIR="${LUMENMON_DATA_DIR:-/data}"
MQTT_DIR="$DATA_DIR/mqtt"

mkdir -p "$DATA_DIR" "$MQTT_DIR"
chmod 775 "$DATA_DIR"

DB_PATH="${LUMENMON_DB_PATH:-$DATA_DIR/lumenmon.sqlite3}"
touch "$DB_PATH"
chmod 664 "$DB_PATH"

echo "[db] SQLite database initialized at $DB_PATH"
