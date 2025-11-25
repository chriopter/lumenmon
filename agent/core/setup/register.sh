#!/bin/bash
# Interactive agent registration with certificate fingerprint verification.
# Parses invite URL, verifies MQTT server certificate, saves permanent credentials.
set -euo pipefail

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUMENMON_HOME="${LUMENMON_HOME:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
LUMENMON_DATA="${LUMENMON_DATA:-$LUMENMON_HOME/data}"
MQTT_DATA_DIR="$LUMENMON_DATA/mqtt"

INVITE_URL="${1:-}"
if [ -z "$INVITE_URL" ]; then
    echo "Usage: lumenmon-agent register <invite_url>"
    exit 1
fi

# Parse URI: lumenmon://username:password@host:port#fingerprint
if [[ ! "$INVITE_URL" =~ lumenmon://([^:]+):([^@]+)@([^:#]+):?([0-9]*)\#(.+)$ ]]; then
    echo "ERROR: Invalid invite URL format. Expected: lumenmon://user:pass@host:port#fingerprint"
    exit 1
fi

USERNAME="${BASH_REMATCH[1]}"
PASSWORD="${BASH_REMATCH[2]}"
MQTT_HOST="${BASH_REMATCH[3]}"
MQTT_PORT="${BASH_REMATCH[4]:-8884}"  # Default to 8884 if not specified
EXPECTED_FP="${BASH_REMATCH[5]}"

echo "[register] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[register] Agent Registration"
echo "[register] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[register] Username: $USERNAME"
echo "[register] MQTT Host: $MQTT_HOST"
echo ""

# Get actual server certificate fingerprint
echo "[register] Connecting to MQTT server to verify certificate..."
ACTUAL_FP=$(echo | openssl s_client \
    -connect "$MQTT_HOST:8884" \
    -servername "$MQTT_HOST" 2>/dev/null | \
    openssl x509 -noout -fingerprint -sha256 2>/dev/null | \
    cut -d= -f2 || echo "")

if [ -z "$ACTUAL_FP" ]; then
    echo "[register] ERROR: Could not connect to MQTT server at $MQTT_HOST:8884"
    echo "[register] Check network connectivity and hostname"
    exit 1
fi

# Download and save the server certificate
echo "[register] Downloading server certificate..."
SERVER_CERT=$(echo | openssl s_client \
    -connect "$MQTT_HOST:8884" \
    -servername "$MQTT_HOST" 2>/dev/null | \
    sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p')

if [ -z "$SERVER_CERT" ]; then
    echo "[register] ERROR: Could not download server certificate"
    exit 1
fi

# Display fingerprint comparison
echo "[register] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[register] Certificate Fingerprint Verification"
echo "[register] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "[register] Expected: $EXPECTED_FP"
echo "[register] Actual:   $ACTUAL_FP"
echo ""

if [ "$ACTUAL_FP" = "$EXPECTED_FP" ]; then
    echo "[register] Status: ✓ MATCH"
    echo ""
    echo "[register] The certificate fingerprint matches the invite."
else
    echo "[register] Status: ✗ MISMATCH"
    echo ""
    echo "[register] WARNING: Certificate fingerprint does not match!"
    echo "[register]"
    echo "[register] This could indicate:"
    echo "[register]   - Man-in-the-middle attack"
    echo "[register]   - Certificate was rotated on console"
    echo "[register]   - Connection through reverse proxy"
    echo "[register]   - Wrong hostname in invite"
    echo ""
fi

echo "[register] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Auto-accept if fingerprint matches, ask only on mismatch
if [ "$ACTUAL_FP" = "$EXPECTED_FP" ]; then
    echo "[register] ✓ Certificate accepted (fingerprint verified)"
elif [ "${LUMENMON_AUTO_ACCEPT:-}" = "1" ]; then
    echo "[register] Auto-accepting certificate (LUMENMON_AUTO_ACCEPT=1)"
else
    echo -n "[register] Accept this certificate anyway? (yes/no): "
    read RESPONSE < /dev/tty
    if [ "$RESPONSE" != "yes" ]; then
        echo "[register] Registration aborted by user"
        exit 1
    fi
fi

# Create mqtt data directory
mkdir -p "$MQTT_DATA_DIR"

# Save credentials
echo "$USERNAME" > "$MQTT_DATA_DIR/username"
echo "$PASSWORD" > "$MQTT_DATA_DIR/password"
echo "$ACTUAL_FP" > "$MQTT_DATA_DIR/fingerprint"
echo "$MQTT_HOST" > "$MQTT_DATA_DIR/host"

# Save server certificate for TLS connections
echo "$SERVER_CERT" > "$MQTT_DATA_DIR/server.crt"
chmod 644 "$MQTT_DATA_DIR/server.crt"

echo "[register] ✓ Credentials saved"
echo "[register] ✓ Server certificate saved (pinned for TLS)"

# Test connection with credentials
echo "[register] Testing connection..."
mosquitto_pub \
    -h "$MQTT_HOST" -p 8884 \
    -u "$USERNAME" -P "$PASSWORD" \
    --cafile "$MQTT_DATA_DIR/server.crt" \
    -t "metrics/$USERNAME/registration_test" \
    -m '{"value":1,"type":"INTEGER","interval":0}' 2>&1 | head -5

if [ $? -eq 0 ]; then
    echo "[register] ✓ Connection test successful!"
else
    echo "[register] ⚠ Connection test failed, but credentials are saved"
fi

echo ""
echo "[register] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[register] Registration Complete!"
echo "[register] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[register] Agent ID: $USERNAME"
echo "[register] MQTT Host: $MQTT_HOST:8884"
echo "[register] Credentials saved to: $MQTT_DATA_DIR/"
echo "[register] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
