#!/bin/bash
# Generates persistent SSH host keys and starts SSH daemon for agent connections.
# Creates RSA and ED25519 keys in /data/ssh and displays fingerprints on startup.
set -euo pipefail

# Generate SSH host keys if needed in persistent storage
if [ ! -f /data/ssh/ssh_host_rsa_key ]; then
    echo "[console] Generating host keys in /data/ssh..."
    ssh-keygen -t rsa -f /data/ssh/ssh_host_rsa_key -N ""
    ssh-keygen -t ed25519 -f /data/ssh/ssh_host_ed25519_key -N ""
fi

# Display host key fingerprints
echo "[console] ========================================"
echo "[console] SSH Server starting on port 22"
echo "[console] Host key fingerprints:"
echo "[console] RSA: $(ssh-keygen -lf /data/ssh/ssh_host_rsa_key | awk '{print $2}')"
echo "[console] ED25519: $(ssh-keygen -lf /data/ssh/ssh_host_ed25519_key | awk '{print $2}')"
echo "[console] ========================================"

echo "[console] Starting SSH authentication server..."
# Start sshd with output redirected to container logs
/usr/sbin/sshd -D -e -f /app/core/ingress/ssh_config 2>&1 | sed 's/^/[sshd] /' &
sleep 2