#!/bin/bash
# Lumenmon Agent Coordinator - Runs all collectors in parallel
set -euo pipefail

# Configuration
CONSOLE_HOST=${CONSOLE_HOST:-console}
CONSOLE_PORT=${CONSOLE_PORT:-22}
CONSOLE_USER=${CONSOLE_USER:-collector}
AGENT_ID=${HOSTNAME:-$(hostname -s)}

# SSH options for persistent connection
SSH_OPTS="-o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=10"

# Collectors directory
COLLECTORS_DIR="/usr/local/bin/collectors"

# Trap to ensure clean shutdown
cleanup() {
    echo "[coordinator] Shutting down collectors..."
    # Kill all collector processes
    jobs -p | xargs -r kill 2>/dev/null || true
    wait
    echo "[coordinator] All collectors stopped"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main function
main() {
    echo "[coordinator] Starting Lumenmon Agent: $AGENT_ID"
    echo "[coordinator] Console: $CONSOLE_HOST:$CONSOLE_PORT"

    # Wait for SSH to be available
    echo "[coordinator] Testing SSH connection..."
    while ! ssh $SSH_OPTS -p $CONSOLE_PORT ${CONSOLE_USER}@${CONSOLE_HOST} echo "test" >/dev/null 2>&1; do
        echo "[coordinator] Waiting for console SSH..."
        sleep 5
    done
    echo "[coordinator] Console SSH is ready"

    # Export environment for collectors
    export CONSOLE_HOST CONSOLE_PORT CONSOLE_USER SSH_OPTS AGENT_ID

    # Start all collectors in background
    echo "[coordinator] Starting collectors..."

    # Core collectors - always run
    if [ -f "$COLLECTORS_DIR/cpu.sh" ]; then
        echo "[coordinator] Starting CPU collector"
        "$COLLECTORS_DIR/cpu.sh" &
    fi

    if [ -f "$COLLECTORS_DIR/memory.sh" ]; then
        echo "[coordinator] Starting Memory collector"
        "$COLLECTORS_DIR/memory.sh" &
    fi

    if [ -f "$COLLECTORS_DIR/disk.sh" ]; then
        echo "[coordinator] Starting Disk collector"
        "$COLLECTORS_DIR/disk.sh" &
    fi

    if [ -f "$COLLECTORS_DIR/network.sh" ]; then
        echo "[coordinator] Starting Network collector"
        "$COLLECTORS_DIR/network.sh" &
    fi

    if [ -f "$COLLECTORS_DIR/processes.sh" ]; then
        echo "[coordinator] Starting Processes collector"
        "$COLLECTORS_DIR/processes.sh" &
    fi

    if [ -f "$COLLECTORS_DIR/system.sh" ]; then
        echo "[coordinator] Starting System collector"
        "$COLLECTORS_DIR/system.sh" &
    fi

    # Optional collectors
    if [ -f "$COLLECTORS_DIR/top.sh" ]; then
        echo "[coordinator] Starting Top processes collector"
        "$COLLECTORS_DIR/top.sh" &
    fi

    if [ -f "$COLLECTORS_DIR/pulse.sh" ]; then
        echo "[coordinator] Starting Pulse collector"
        "$COLLECTORS_DIR/pulse.sh" &
    fi

    echo "[coordinator] All collectors started"

    # Wait for all background jobs
    wait
}

# Start coordinator
main