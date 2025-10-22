#!/bin/bash
# Generates agent registration invite with permanent credentials and certificate fingerprint.
# Creates username, permanent password, and builds invite URL for agent registration.
set -euo pipefail

FINGERPRINT_FILE="/data/mqtt/fingerprint"
PASSWORD_FILE="/data/mqtt/passwd"
CONSOLE_HOST="${CONSOLE_HOST:-localhost}"

# Check if certificate exists
if [ ! -f "$FINGERPRINT_FILE" ]; then
    echo "ERROR: Certificate fingerprint not found. Run init_mqtt_cert.sh first."
    exit 1
fi

# Generate random username (agent ID format)
USERNAME="id_$(openssl rand -hex 4)"

# Generate strong permanent password
PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"

# Add credentials to mosquitto password file
if [ ! -f "$PASSWORD_FILE" ]; then
    touch "$PASSWORD_FILE"
fi

mosquitto_passwd -b "$PASSWORD_FILE" "$USERNAME" "$PASSWORD" 2>/dev/null

# Reload mosquitto to pick up new password
pkill -HUP mosquitto 2>/dev/null || true
sleep 0.5  # Brief pause to allow reload to complete

# Load certificate fingerprint
FINGERPRINT=$(cat "$FINGERPRINT_FILE")

# Build invite URL
INVITE_URL="lumenmon://$USERNAME:$PASSWORD@$CONSOLE_HOST:8884#$FINGERPRINT"

# Output bare URL first (for installer to parse)
echo "$INVITE_URL"
echo ""

# Output invite information
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Agent Registration Invite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Agent ID: $USERNAME"
echo "Certificate Fingerprint: $FINGERPRINT"
echo ""
echo "One-Click Install (copy to target machine):"
echo ""
echo "  curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install.sh | \\"
echo "    LUMENMON_INVITE=\"$INVITE_URL\" bash"
echo ""
echo "Or manual registration (if lumenmon already installed):"
echo ""
echo "  lumenmon register \"$INVITE_URL\""
echo ""
echo "Security:"
echo "  • Credentials are permanent (no rotation needed)"
echo "  • ACL enforces topic isolation (write-only to metrics/$USERNAME/#)"
echo "  • Keep this URL secure - it contains credentials"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Also output machine-readable JSON for Flask API
echo "{\"username\":\"$USERNAME\",\"url\":\"$INVITE_URL\",\"fingerprint\":\"$FINGERPRINT\"}" > /tmp/last_invite.json
