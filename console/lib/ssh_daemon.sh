#!/bin/bash
# Start SSH daemon with custom config

set -euo pipefail

# Generate SSH host keys if needed in persistent storage
if [ ! -f /data/ssh/ssh_host_rsa_key ]; then
    echo "[console] Generating host keys in /data/ssh..."
    ssh-keygen -t rsa -f /data/ssh/ssh_host_rsa_key -N ""
    ssh-keygen -t ed25519 -f /data/ssh/ssh_host_ed25519_key -N ""
fi

echo "[console] Starting SSH authentication server..."
exec /usr/sbin/sshd -D -f /app/lib/ssh_config &
sleep 2