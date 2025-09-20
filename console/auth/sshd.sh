#!/bin/bash
# SSH daemon setup - generates keys and starts sshd

set -euo pipefail

# Generate SSH host keys if needed
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "[auth] Generating host keys..."
    ssh-keygen -A
fi

# Setup directories
mkdir -p /data/agents

# Display info
echo "[auth] ======================================"
echo "[auth] SSH Agent Authentication System Ready"
echo "[auth] Agent data: /data/agents/"
echo "[auth] ======================================"

# Start SSH daemon with custom config
echo "[auth] Starting SSH daemon on port 22..."
exec /usr/sbin/sshd -D -f /app/auth/sshd_config &