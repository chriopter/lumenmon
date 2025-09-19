#!/bin/bash
# SSH daemon setup - generates keys and starts sshd

set -euo pipefail

# Generate SSH host keys if needed
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "[ssh] Generating host keys..."
    ssh-keygen -A
fi

# Initialize authorized_keys if it doesn't exist
if [ ! -f /home/collector/.ssh/authorized_keys ]; then
    echo "[ssh] Creating authorized_keys..."
    touch /home/collector/.ssh/authorized_keys
fi

# Display info
echo "[ssh] ======================================"
echo "[ssh] SSH directory: /home/collector/.ssh/"
echo "[ssh] (mounted from: ./console/data/ssh/)"
echo "[ssh] ======================================"

# Start SSH daemon
echo "[ssh] Starting SSH daemon on port 22..."
exec /usr/sbin/sshd -D &