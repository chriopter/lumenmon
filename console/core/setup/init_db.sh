#!/bin/bash
# Ensure the persistent MQTT volume is writable.
# Rails creates its own storage/ directory via `db:prepare`.
set -euo pipefail

DATA_DIR="${LUMENMON_DATA_DIR:-/data}"
MQTT_DIR="$DATA_DIR/mqtt"

mkdir -p "$DATA_DIR" "$MQTT_DIR"
chmod 775 "$DATA_DIR"

echo "[db] MQTT data directory ready at $DATA_DIR"
