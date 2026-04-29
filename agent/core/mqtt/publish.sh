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
    local min_bound="${5:-}"   # Optional min bound
    local max_bound="${6:-}"   # Optional max bound
    local warn_min_bound="${7:-}"  # Optional warning min bound
    local warn_max_bound="${8:-}"  # Optional warning max bound

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
    [ -n "$min_bound" ] && payload="$payload,\"min\":$min_bound"
    [ -n "$max_bound" ] && payload="$payload,\"max\":$max_bound"
    [ -n "$warn_min_bound" ] && payload="$payload,\"warn_min\":$warn_min_bound"
    [ -n "$warn_max_bound" ] && payload="$payload,\"warn_max\":$warn_max_bound"

    payload="$payload}"

    local topic="metrics/$_MQTT_USER/$metric_name"

    # Publish via mosquitto_pub with TLS
    # Note: --insecure skips hostname verification (we use cert pinning instead)
    if mosquitto_pub \
        -h "$_MQTT_HOST" -p "$_MQTT_PORT" \
        -u "$_MQTT_USER" -P "$_MQTT_PASS" \
        --cafile "$_MQTT_CERT" --insecure \
        -t "$topic" \
        -m "$payload" 2>/dev/null; then
        # Success — drain spool if entries exist
        _spool_drain
    else
        echo "[collector] WARNING: Failed to publish $metric_name, spooling" >&2
        _spool_enqueue "$topic" "$payload"
    fi
}

# --- Spool-queue helpers (buffer failed publishes for replay) ---

_SPOOL_MAX_LINES=1000

_spool_file() {
    printf '%s/mqtt/spool.jsonl' "$LUMENMON_DATA"
}

_spool_enqueue() {
    local topic="$1"
    local payload="$2"
    local spool
    spool="$(_spool_file)"

    mkdir -p "$(dirname "$spool")"
    printf '%s\t%s\n' "$topic" "$payload" >> "$spool"

    # Trim to max lines (drop oldest)
    local count
    count=$(wc -l < "$spool" 2>/dev/null || echo 0)
    if [ "$count" -gt "$_SPOOL_MAX_LINES" ]; then
        local excess=$((count - _SPOOL_MAX_LINES))
        local tmp="${spool}.tmp"
        tail -n +"$((excess + 1))" "$spool" > "$tmp" && mv "$tmp" "$spool"
    fi
}

_spool_drain() {
    local spool
    spool="$(_spool_file)"

    [ -s "$spool" ] || return 0

    local tmp="${spool}.draining"
    mv "$spool" "$tmp" 2>/dev/null || return 0

    local sent=0
    local total
    total=$(wc -l < "$tmp")
    local topic payload
    while IFS=$'\t' read -r topic payload; do
        [ -z "$topic" ] && continue
        if ! mosquitto_pub \
            -h "$_MQTT_HOST" -p "$_MQTT_PORT" \
            -u "$_MQTT_USER" -P "$_MQTT_PASS" \
            --cafile "$_MQTT_CERT" --insecure \
            -t "$topic" \
            -m "$payload" 2>/dev/null; then
            # Broker down again — re-enqueue this line + remaining lines
            { printf '%s\t%s\n' "$topic" "$payload"
              tail -n +"$((sent + 2))" "$tmp"
            } >> "$spool" 2>/dev/null || true
            rm -f "$tmp"
            return 0
        fi
        sent=$((sent + 1))
    done < "$tmp"

    rm -f "$tmp"
}
