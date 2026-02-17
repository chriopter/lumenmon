#!/bin/bash
# MQTT publishing helper for collectors. Uses mosquitto_pub with TLS.

# Resolve paths
: ${LUMENMON_HOME:="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
: ${LUMENMON_DATA:="$LUMENMON_HOME/data"}

# Load credentials once (cached)
_mqtt_load_creds() {
    if [ -z "${_MQTT_CREDS_LOADED:-}" ]; then
        local data_dir="$LUMENMON_DATA/mqtt"
        _MQTT_HOST=$(cat "$data_dir/host" 2>/dev/null)
        _MQTT_PORT=$(cat "$data_dir/port" 2>/dev/null || printf '8884')
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
    local min_value="${5:-}"   # Optional min bound
    local max_value="${6:-}"   # Optional max bound

    # Test mode: print instead of publish
    if [ "${LUMENMON_TEST_MODE:-}" = "1" ]; then
        printf "  %-24s %s\n" "$metric_name" "$value"
        return 0
    fi

    _mqtt_load_creds

    # Build JSON payload - handle TEXT type needing quoted value
    local json_value="$value"
    if [ "$type" = "TEXT" ]; then
        json_value="\"$value\""
    fi

    # Start with required fields
    local payload="{\"value\":$json_value,\"type\":\"$type\",\"interval\":$interval"

    # Add optional min/max if provided
    [ -n "$min_value" ] && payload="$payload,\"min\":$min_value"
    [ -n "$max_value" ] && payload="$payload,\"max\":$max_value"

    payload="$payload}"

    local topic="metrics/$_MQTT_USER/$metric_name"

    # Publish via mosquitto_pub with TLS
    # Note: --insecure skips hostname verification (we use cert pinning instead)
    mosquitto_pub \
        -h "$_MQTT_HOST" -p "$_MQTT_PORT" \
        -u "$_MQTT_USER" -P "$_MQTT_PASS" \
        --cafile "$_MQTT_CERT" --insecure \
        -t "$topic" \
        -m "$payload" 2>/dev/null || \
        echo "[collector] WARNING: Failed to publish $metric_name" >&2
}
