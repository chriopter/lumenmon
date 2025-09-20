#!/bin/bash
# Start SSH daemon with custom config

set -euo pipefail

# Generate SSH host keys if needed
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "[console] Generating host keys..."
    ssh-keygen -A
fi

echo "[console] Starting SSH authentication server..."
exec /usr/sbin/sshd -D -f /app/app/ssh_config &
sleep 2