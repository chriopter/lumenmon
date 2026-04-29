#!/bin/bash
# Generates an agent registration invite with permanent MQTT credentials.
# Keeps dev/auto and existing operational flows compatible during the rewrite.
set -euo pipefail

DATA_DIR="${LUMENMON_DATA_DIR:-/data}"
MQTT_PORT="${MQTT_PORT:-8884}"
FINGERPRINT_FILE="$DATA_DIR/mqtt/fingerprint"
PASSWORD_FILE="$DATA_DIR/mqtt/passwd"
CONSOLE_HOST="${CONSOLE_HOST:-localhost}"

if [ ! -f "$FINGERPRINT_FILE" ]; then
    echo "ERROR: Certificate fingerprint not found. Run init_mqtt_cert.sh first."
    exit 1
fi

USERNAME="id_$(openssl rand -hex 4)"
PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"

touch "$PASSWORD_FILE"
mosquitto_passwd -b "$PASSWORD_FILE" "$USERNAME" "$PASSWORD" 2>/dev/null
if [ -n "${LUMENMON_MOSQUITTO_PID:-}" ]; then
    kill -HUP "$LUMENMON_MOSQUITTO_PID" 2>/dev/null || true
else
    pkill -HUP mosquitto 2>/dev/null || true
fi

FINGERPRINT=$(cat "$FINGERPRINT_FILE")
INVITE_URL="lumenmon://$USERNAME:$PASSWORD@$CONSOLE_HOST:$MQTT_PORT#$FINGERPRINT"

echo "$INVITE_URL"
echo "{\"username\":\"$USERNAME\",\"url\":\"$INVITE_URL\",\"fingerprint\":\"$FINGERPRINT\"}" > /tmp/last_invite.json
