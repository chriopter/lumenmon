#!/bin/sh
# Lumenmon SSH Tunnel Manager
# Maintains persistent SSH tunnel for secure metric transport

KEY_FILE="/etc/lumenmon/id_rsa"
SSH_HOST="${SSH_SERVER:-localhost}"
SSH_PORT="${SSH_PORT:-2222}"
SSH_USER="metrics"
LOCAL_PORT="8080"
REMOTE_PORT="8080"

echo "[TUNNEL] SSH Tunnel Manager starting..."
echo "[TUNNEL] Server: $SSH_HOST:$SSH_PORT"

# Wait for key to exist
while [ ! -f "$KEY_FILE" ]; do
    echo "[TUNNEL] Waiting for SSH key generation..."
    sleep 5
done

# Main tunnel loop - auto-reconnect on failure
while true; do
    echo "[TUNNEL] Attempting connection to $SSH_HOST:$SSH_PORT..."
    
    # Check if server is reachable
    if nc -z -w 5 "$SSH_HOST" "$SSH_PORT" 2>/dev/null; then
        echo "[TUNNEL] Server is reachable, establishing tunnel..."
        
        # Create SSH tunnel
        # -N: No command execution
        # -o options for reliability
        # -L: Local port forward
        ssh -N \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ServerAliveInterval=30 \
            -o ServerAliveCountMax=3 \
            -o ExitOnForwardFailure=yes \
            -o ConnectTimeout=10 \
            -o LogLevel=ERROR \
            -p "$SSH_PORT" \
            -L "${LOCAL_PORT}:localhost:${REMOTE_PORT}" \
            -i "$KEY_FILE" \
            "${SSH_USER}@${SSH_HOST}" 2>&1 | while IFS= read -r line; do
                echo "[TUNNEL] SSH: $line"
            done
        
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            echo "[TUNNEL] Connection closed normally"
        else
            echo "[TUNNEL] Connection failed with exit code: $EXIT_CODE"
            
            # Common error handling
            case $EXIT_CODE in
                255)
                    echo "[TUNNEL] SSH error - possible causes:"
                    echo "[TUNNEL]   - Key not yet approved by admin"
                    echo "[TUNNEL]   - Network connectivity issue"
                    echo "[TUNNEL]   - SSH server not running"
                    ;;
                *)
                    echo "[TUNNEL] Unexpected error"
                    ;;
            esac
        fi
    else
        echo "[TUNNEL] Server not reachable at $SSH_HOST:$SSH_PORT"
    fi
    
    echo "[TUNNEL] Retrying in 30 seconds..."
    sleep 30
done