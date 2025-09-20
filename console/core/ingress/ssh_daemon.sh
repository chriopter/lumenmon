#!/bin/bash
# Start SSH daemon with custom config

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
/usr/sbin/sshd -D -f /app/core/ingress/ssh_config &
sleep 2