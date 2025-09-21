#!/bin/sh
# Console status - technical details

echo -n "Console: "

# Container running (implicit)
echo -n "Container ✓ | "

# SSH daemon
if pgrep -f sshd >/dev/null; then
    echo -n "SSHD ✓ | "
    echo -n "Port: ${CONSOLE_PORT:-2345} | "
else
    echo "SSHD ✗"
    exit
fi

# Host key
[ -f /data/ssh/ssh_host_ed25519_key ] && echo -n "HostKey ✓ | " || echo -n "HostKey ✗ | "

# Authorized keys count
if [ -f /data/ssh/authorized_keys ]; then
    KEYS=$(grep -c "^ssh-" /data/ssh/authorized_keys 2>/dev/null || echo 0)
    echo -n "Keys: $KEYS | "
fi

# Agent directories
if [ -d /data/agents ]; then
    TOTAL=$(ls /data/agents 2>/dev/null | wc -l)
    echo -n "Agents: $TOTAL | "

    # Active connections (check for user processes)
    CONNECTED=0
    for AGENT_DIR in /data/agents/*; do
        [ -d "$AGENT_DIR" ] || continue
        AGENT_ID=$(basename "$AGENT_DIR")
        # Check if user has active SSH session
        if pgrep -u "$AGENT_ID" >/dev/null 2>&1; then
            CONNECTED=$((CONNECTED + 1))
        fi
    done
    echo -n "Connected: $CONNECTED | "

    # Active data flow (recent metrics)
    ACTIVE=0
    for AGENT_DIR in /data/agents/*; do
        [ -d "$AGENT_DIR" ] || continue
        HOT="/var/lib/lumenmon/hot/$(basename "$AGENT_DIR")"
        [ -d "$HOT" ] && find "$HOT" -name "*.tsv" -mmin -1 2>/dev/null | grep -q . && ACTIVE=$((ACTIVE + 1))
    done
    echo "Active: $ACTIVE"
else
    echo "Agents: ✗"
fi