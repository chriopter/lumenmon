#!/bin/bash
# SSH daemon setup - generates keys and starts sshd

set -euo pipefail

# Generate SSH host keys if needed
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "[ssh] Generating host keys..."
    ssh-keygen -A
fi

# Setup collector user and keys
if [ ! -f /home/collector/.ssh/id_rsa ]; then
    echo "[ssh] Generating collector keypair..."

    # Generate key
    ssh-keygen -t rsa -b 2048 -f /home/collector/.ssh/id_rsa -N ""

    # Setup authorized_keys with forced command
    echo -n 'command="/app/ssh/receiver.sh" ' > /home/collector/.ssh/authorized_keys
    cat /home/collector/.ssh/id_rsa.pub >> /home/collector/.ssh/authorized_keys

    # Fix permissions
    chown -R collector:collector /home/collector/.ssh
    chmod 700 /home/collector/.ssh
    chmod 600 /home/collector/.ssh/authorized_keys
    chmod 600 /home/collector/.ssh/id_rsa
fi

# Copy key to shared volume for agents if mounted
if [ -d "/shared" ]; then
    echo "[ssh] Copying keys to shared volume..."
    cp /home/collector/.ssh/id_rsa /shared/agent_key
    cp /home/collector/.ssh/id_rsa.pub /shared/agent_key.pub
    chmod 644 /shared/agent_key /shared/agent_key.pub
else
    # Display public key for manual configuration
    echo "[ssh] ======================================"
    echo "[ssh] Agent connection key (add to agents):"
    echo "[ssh] ======================================"
    cat /home/collector/.ssh/id_rsa.pub
    echo "[ssh] ======================================"
fi

# Start SSH daemon
echo "[ssh] Starting SSH daemon on port 22..."
exec /usr/sbin/sshd -D &