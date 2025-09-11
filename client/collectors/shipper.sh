#!/bin/sh
# Shipper - Converts metrics to JSON and ships to sink with authentication
# Usage: collector | ./shipper.sh [interval] [server_url]
# Example: ./cpu.sh | ./shipper.sh allegro

# Configuration
INTERVAL_NAME="${1}"
SERVER="${2:-${SERVER_URL:-http://localhost:8080}/metrics}"
DEBUG="${DEBUG:-0}"
KEY_FILE="/etc/lumenmon/id_rsa"

# Get client identity
HOSTNAME=$(hostname)
echo "[shipper] Checking for SSH key at: ${KEY_FILE}.pub" >&2
if [ -f "${KEY_FILE}.pub" ]; then
    FINGERPRINT=$(ssh-keygen -lf "${KEY_FILE}.pub" 2>/dev/null | awk '{print $2}')
    if [ -z "$FINGERPRINT" ]; then
        echo "[shipper] ERROR: Could not extract fingerprint from ${KEY_FILE}.pub" >&2
        # Try alternative extraction
        FINGERPRINT=$(ssh-keygen -lf "${KEY_FILE}.pub" 2>&1)
        echo "[shipper] ssh-keygen output: $FINGERPRINT" >&2
        FINGERPRINT=""
    else
        echo "[shipper] Found SSH key, fingerprint: $FINGERPRINT" >&2
    fi
else
    FINGERPRINT=""
    echo "[shipper] Warning: No SSH key found at ${KEY_FILE}.pub" >&2
    ls -la /etc/lumenmon/ >&2
fi

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
while read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    
    # Parse format: name:value:type
    # Count colons to determine format
    colon_count=$(echo "$line" | tr -cd ':' | wc -c)
    
    if [ "$colon_count" -lt 2 ]; then
        log "Warning: Invalid format (need name:value:type): $line"
        continue
    fi
    
    # Extract name (before first colon)
    name="${line%%:*}"
    rest="${line#*:}"
    
    # Extract type (after last colon) - must be valid type
    type="${rest##*:}"
    
    # Validate type first
    case "$type" in
        int|float|string|blob)
            # Valid type - extract value (everything between name and type)
            value="${rest%:*}"
            ;;
        *)
            # Invalid type - treat whole rest as value, default to string
            log "Warning: Invalid type '$type', using string"
            value="$rest"
            type="string"
            ;;
    esac
    
    # Default type if empty
    type="${type:-string}"
    
    # Use jq if available for proper escaping, otherwise simple printf
    if [ "$HAS_JQ" = "1" ]; then
        # Use jq with -c flag for compact output (one line per metric)
        JSON=$(jq -c -n \
            --arg n "$name" \
            --arg v "$value" \
            --arg t "$type" \
            --argjson i "$INTERVAL_SECONDS" \
            --arg h "$HOSTNAME" \
            --arg f "$FINGERPRINT" \
            '{name: $n, value: $v, type: $t, interval: $i, hostname: $h, fingerprint: $f}')
    else
        # Fallback: Manual JSON escaping when jq is not available
        # Escape special characters in values
        escape_json() {
            # Use different delimiter to avoid issues with forward slashes
            printf '%s' "$1" | sed -e 's|\\|\\\\|g' -e 's|"|\\"|g' -e 's|	|\\t|g' -e 's|
|\\n|g' -e 's|\r|\\r|g'
        }
        
        # Escape each field
        name_escaped=$(escape_json "$name")
        value_escaped=$(escape_json "$value")
        hostname_escaped=$(escape_json "$HOSTNAME")
        fingerprint_escaped=$(escape_json "$FINGERPRINT")
        
        JSON=$(printf '{"name":"%s","value":"%s","type":"%s","interval":%d,"hostname":"%s","fingerprint":"%s"}' \
               "$name_escaped" "$value_escaped" "$type" "$INTERVAL_SECONDS" "$hostname_escaped" "$fingerprint_escaped")
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