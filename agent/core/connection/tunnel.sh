#!/bin/bash
# Establish SSH tunnel to console

set -euo pipefail

# Clean up any existing socket
[ -S "$SSH_SOCKET" ] && rm -f "$SSH_SOCKET"

# Wait for console
echo "[agent] Checking network connectivity to $CONSOLE_HOST:$CONSOLE_PORT..."

# Test if host is reachable
if ping -c 1 -W 1 "$CONSOLE_HOST" >/dev/null 2>&1; then
    echo "[agent] ✓ Host $CONSOLE_HOST is reachable"
else
    echo "[agent] ⚠ Cannot ping $CONSOLE_HOST (may be normal if ICMP blocked)"
fi

# Wait for SSH port
echo "[agent] Waiting for SSH port $CONSOLE_PORT on $CONSOLE_HOST..."
attempt=0
while ! nc -z "$CONSOLE_HOST" "$CONSOLE_PORT" 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ $((attempt % 5)) -eq 0 ]; then
        echo "[agent] Still waiting for $CONSOLE_HOST:$CONSOLE_PORT (attempt $attempt)..."
    fi
    sleep 2
done
echo "[agent] ✓ SSH port is open on $CONSOLE_HOST:$CONSOLE_PORT"

# Keep trying to connect until successful
echo "[agent] Waiting for registration on $CONSOLE_HOST:$CONSOLE_PORT..."
echo "[agent] Add this agent via TUI using the public key shown above"

# Connection retry logic with adaptive delays:
# - No host key: retry every 1 second (waiting for registration)
# - Just registered: reset counter, retry every 1 second for 10 attempts
# - Persistent failures: retry every 10 seconds (real network issues)
retry_count=0
had_host_key=false
while true; do
    retry_count=$((retry_count + 1))
    echo "[agent] Connection attempt $retry_count to $AGENT_USER@$CONSOLE_HOST:$CONSOLE_PORT..."

    # Require saved host key (registration is the only way to get it)
    if [ ! -f "/home/metrics/.ssh/known_hosts" ]; then
        echo "[agent] ERROR: No host key found. Agent must be registered first."
        echo "[agent] Use registration invite to establish trust with console."
        had_host_key=false
        sleep 1  # Fast retry when waiting for registration
        continue
    fi

    # Reset counter when registration is first detected
    # This ensures we get fast retries right after registration, even if we waited long
    if [ "$had_host_key" = "false" ]; then
        echo "[agent] Registration detected! Attempting connection..."
        retry_count=1  # Reset to give 10 fast attempts post-registration
        had_host_key=true
    fi

    # Try to open SSH tunnel with strict host key checking
    if ssh -M -N -f \
        -S "$SSH_SOCKET" \
        -i "$SSH_KEY" \
        -o ControlPersist=yes \
        -o ServerAliveInterval=30 \
        -o StrictHostKeyChecking=yes \
        -o UserKnownHostsFile=/home/metrics/.ssh/known_hosts \
        -o PreferredAuthentications=publickey \
        -o PasswordAuthentication=no \
        -o ConnectTimeout=5 \
        -o LogLevel=ERROR \
        -p "$CONSOLE_PORT" \
        "$AGENT_USER@$CONSOLE_HOST" 2>/tmp/ssh_error.log; then

        # Verify connection
        if ssh -S "$SSH_SOCKET" -O check "$AGENT_USER@$CONSOLE_HOST" 2>/dev/null; then
            echo "[agent] ✓ SSH tunnel established!"
            echo "[agent] Connected as $AGENT_USER to $CONSOLE_HOST:$CONSOLE_PORT"
            break
        else
            echo "[agent] ⚠ SSH process started but socket check failed"
        fi
    else
        # Show SSH error for first few attempts
        if [ $retry_count -le 3 ] && [ -f /tmp/ssh_error.log ]; then
            error_msg=$(cat /tmp/ssh_error.log 2>/dev/null | head -1)
            if [ -n "$error_msg" ]; then
                echo "[agent] SSH error: $error_msg"
            fi
        fi
    fi

    # Clean up failed socket
    [ -S "$SSH_SOCKET" ] && rm -f "$SSH_SOCKET"

    # Adaptive retry delay based on registration and attempt count
    if [ ! -f "/home/metrics/.ssh/known_hosts" ]; then
        # No host key = not registered yet, poll quickly
        echo "[agent] Waiting for registration. Retrying in 1 second..."
        echo "[agent] (Enter invite in console TUI or add public key manually)"
        sleep 1
    elif [ $retry_count -le 10 ]; then
        # First 10 attempts after registration: fast retry
        # Handles SSH daemon recognizing new user, file system sync, etc.
        echo "[agent] Connection failed (attempt $retry_count/10 fast). Retrying in 1 second..."
        sleep 1
    else
        # After 10 fast attempts: probably real network/config issues
        echo "[agent] Connection failed. Retrying in 10 seconds..."
        echo "[agent] (Check network and console status)"
        sleep 10
    fi
done