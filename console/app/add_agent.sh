#!/bin/bash
# Add new agent - creates user and folder from public key

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 'ssh-ed25519 AAAA...'"
    exit 1
fi

PUBLIC_KEY="$1"

# Validate it's a valid SSH key
if ! echo "$PUBLIC_KEY" | ssh-keygen -lf - >/dev/null 2>&1; then
    echo "ERROR: Invalid SSH key"
    exit 1
fi

# Generate fingerprint with id_ prefix
FINGERPRINT="id_$(echo "$PUBLIC_KEY" | ssh-keygen -lf - | awk '{print $2}' | cut -d: -f2 | tr '/+' '_-' | cut -c1-14)"

# Check if already exists
if id "$FINGERPRINT" &>/dev/null; then
    echo "Agent already exists: $FINGERPRINT"
    exit 0
fi

# Create Linux user
useradd -m -s /bin/false "$FINGERPRINT"

# Create data folder (same name!)
mkdir -p "/data/metrics/$FINGERPRINT"
chown "$FINGERPRINT:$FINGERPRINT" "/data/metrics/$FINGERPRINT"
chmod 700 "/data/metrics/$FINGERPRINT"

# Setup SSH access
mkdir -p "/home/$FINGERPRINT/.ssh"
echo "$PUBLIC_KEY" > "/home/$FINGERPRINT/.ssh/authorized_keys"
chown -R "$FINGERPRINT:$FINGERPRINT" "/home/$FINGERPRINT/.ssh"
chmod 700 "/home/$FINGERPRINT/.ssh"
chmod 600 "/home/$FINGERPRINT/.ssh/authorized_keys"

# Log
echo "[$(date)] Added agent: $FINGERPRINT" >> /data/metrics.log

echo "Agent ready: $FINGERPRINT"
echo "Configure agent with: AGENT_USER=$FINGERPRINT"