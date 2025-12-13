#!/bin/bash
# Starts all metric collectors by running _init.sh in each collector directory.
# Each _init.sh decides if its collectors should run (e.g., proxmox checks for pvesh).
set -euo pipefail

# LUMENMON_HOME must be set by agent.sh before sourcing
: ${LUMENMON_HOME:?LUMENMON_HOME not set}

# Collector log file
COLLECTOR_LOG="${LUMENMON_DATA}/collectors.log"

# Wrapper to run collectors with logging
# Usage: run_collector <name> <script_path>
run_collector() {
    local name="$1"
    local script="$2"

    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] STARTED $name"
        # Export all required environment variables for child processes
        export LUMENMON_HOME LUMENMON_DATA
        export PULSE BREATHE CYCLE REPORT
        export AGENT_ID MQTT_HOST MQTT_PORT MQTT_USERNAME MQTT_PASSWORD
        "$script" 2>&1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CRASHED $name (exit: $?)"
    } >> "$COLLECTOR_LOG" 2>&1 &

    echo "[agent] Started: $name"
}

echo "[agent] Starting collectors..."

# Run _init.sh in each collector directory
for init in "$LUMENMON_HOME/collectors"/*/_init.sh; do
    if [ -f "$init" ]; then
        source "$init"
    fi
done

echo "[agent] Collectors started. Press Ctrl+C to stop."