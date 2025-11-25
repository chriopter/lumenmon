#!/bin/bash
# MQTT publishing helper for collectors. Uses mosquitto_pub with TLS.

# Resolve paths
: ${LUMENMON_HOME:="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
: ${LUMENMON_DATA:="$LUMENMON_HOME/data"}

# Load credentials once (cached)
_mqtt_load_creds() {
    if [ -z "$_MQTT_CREDS_LOADED" ]; then
        local data_dir="$LUMENMON_DATA/mqtt"
        _MQTT_HOST=$(cat "$data_dir/host" 2>/dev/null)
        _MQTT_USER=$(cat "$data_dir/username" 2>/dev/null)
        _MQTT_PASS=$(cat "$data_dir/password" 2>/dev/null)
        _MQTT_CERT="$data_dir/server.crt"
        _MQTT_CREDS_LOADED=1
    fi
}

publish_metric() {
    local metric_name="$1"
    local value="$2"
    local type="$3"
    local interval="${4:-60}"  # Default 60s if not specified

    _mqtt_load_creds

    # Build JSON payload
    local payload="{\"value\":$value,\"type\":\"$type\",\"interval\":$interval}"
    local topic="metrics/$_MQTT_USER/$metric_name"

    # Publish via mosquitto_pub with TLS
    mosquitto_pub \
        -h "$_MQTT_HOST" -p 8884 \
        -u "$_MQTT_USER" -P "$_MQTT_PASS" \
        --cafile "$_MQTT_CERT" \
        -t "$topic" \
        -m "$payload" 2>/dev/null || \
        echo "[collector] WARNING: Failed to publish $metric_name" >&2
}
