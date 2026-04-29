#!/bin/bash
# Ensure the persistent volumes for MQTT and Rails storage are writable.
set -euo pipefail

DATA_DIR="${LUMENMON_DATA_DIR:-/data}"
MQTT_DIR="$DATA_DIR/mqtt"
STORAGE_DIR="${RAILS_STORAGE_DIR:-/app/storage}"

mkdir -p "$DATA_DIR" "$MQTT_DIR" "$STORAGE_DIR"
chmod 775 "$DATA_DIR" "$STORAGE_DIR"

echo "[db] Rails storage directory ready at $STORAGE_DIR"
