#!/bin/bash
# Starts all metric collectors by running _init.sh in each collector directory.
# Each _init.sh decides if its collectors should run (e.g., proxmox checks for pvesh).
set -euo pipefail

# LUMENMON_HOME must be set by agent.sh before sourcing
: ${LUMENMON_HOME:?LUMENMON_HOME not set}

echo "[agent] Starting collectors..."

# Run _init.sh in each collector directory
for init in "$LUMENMON_HOME/collectors"/*/_init.sh; do
    if [ -f "$init" ]; then
        source "$init"
    fi
done

echo "[agent] Collectors started. Press Ctrl+C to stop."