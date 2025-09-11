#!/bin/sh
# Shipper - Converts metrics to JSON and ships to sink
# Usage: collector | ./shipper.sh [interval] [server_url]
# Example: ./cpu.sh | ./shipper.sh allegro

# Configuration
INTERVAL_NAME="${1}"
SERVER="${2:-${SERVER_URL:-http://localhost:8080}/metrics}"
DEBUG="${DEBUG:-0}"

# Map interval name to numeric seconds
case "$INTERVAL_NAME" in
    allegro)
        INTERVAL_SECONDS=${ALLEGRO_INTERVAL:-5}
        ;;
    andante)
        INTERVAL_SECONDS=${ANDANTE_INTERVAL:-60}
        ;;
    adagio)
        INTERVAL_SECONDS=${ADAGIO_INTERVAL:-3600}
        ;;
    *)
        INTERVAL_SECONDS=0  # Unknown interval
        ;;
esac

# Debug logging
log() {
    [ "$DEBUG" = "1" ] && echo "[shipper] $1" >&2
}

log "Shipping metrics to $SERVER (interval: $INTERVAL_NAME, seconds: $INTERVAL_SECONDS)"

# Buffer to collect all JSON lines
BUFFER=""

# Check if jq is available for proper JSON escaping
HAS_JQ=$(command -v jq >/dev/null 2>&1 && echo 1 || echo 0)

# Read metrics and convert to JSON
while IFS=: read -r name value type; do
    # Skip empty lines
    [ -z "$name" ] && continue
    
    # Default type if not provided
    type="${type:-string}"
    
    # Use jq if available for proper escaping, otherwise simple printf
    if [ "$HAS_JQ" = "1" ]; then
        JSON=$(jq -n \
            --arg n "$name" \
            --arg v "$value" \
            --arg t "$type" \
            --argjson i "$INTERVAL_SECONDS" \
            '{name: $n, value: $v, type: $t, interval: $i}')
    else
        # Simple JSON formatting (doesn't handle special chars)
        JSON=$(printf '{"name":"%s","value":"%s","type":"%s","interval":%d}' \
               "$name" "$value" "$type" "$INTERVAL_SECONDS")
    fi
    
    # Add to buffer
    if [ -z "$BUFFER" ]; then
        BUFFER="$JSON"
    else
        BUFFER="$BUFFER
$JSON"
    fi
    
    log "Converted: $name ($type)"
done

# Ship all metrics at once
if [ -n "$BUFFER" ]; then
    echo "$BUFFER" | curl -X POST --data-binary @- "$SERVER" -s
    if [ $? -eq 0 ]; then
        log "Successfully shipped metrics"
    else
        log "Failed to ship metrics"
        exit 1
    fi
else
    log "No metrics to ship"
fi