#!/bin/bash
# Server startup script
set -euo pipefail

# Generate SSH host keys if needed
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi

# Generate SSH key pair for collectors if not exists
if [ ! -f /home/collector/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 2048 -f /home/collector/.ssh/id_rsa -N ""
    cp /home/collector/.ssh/id_rsa.pub /home/collector/.ssh/authorized_keys

    # Set up forced command in authorized_keys
    # Note: We'll extract hostname from the SSH key comment or use client IP
    cat /home/collector/.ssh/id_rsa.pub > /home/collector/.ssh/authorized_keys

    chown -R collector:collector /home/collector/.ssh
    chmod 600 /home/collector/.ssh/authorized_keys
fi

# Ensure shared directory exists and has proper permissions
mkdir -p /shared
chmod 755 /shared

# Copy keys to shared volume for client with proper permissions
cp /home/collector/.ssh/id_rsa /shared/client_key
cp /home/collector/.ssh/id_rsa.pub /shared/client_key.pub
chmod 644 /shared/client_key
chmod 644 /shared/client_key.pub

# Start SSH daemon
echo "[server] Starting SSH daemon..."
/usr/sbin/sshd -D &
SSHD_PID=$!

# Wait for SSH to be ready
sleep 2

# Keep container running
echo "[server] SSH server ready on port 22"
echo "[server] To view TUI, run: docker exec -it lumenmon-server python3 /usr/local/bin/tui.py"
echo "[server] Container running... Press Ctrl+C to stop"

# Wait forever
tail -f /dev/null

# Cleanup on exit
trap "kill $SSHD_PID 2>/dev/null" EXIT