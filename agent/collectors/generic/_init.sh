#!/bin/bash
# Generic collectors - always runs on all systems.
# Starts cpu, memory, disk, heartbeat, hostname, lumenmon collectors.

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in cpu disk heartbeat hostname lumenmon memory; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        run_collector "generic_${collector}" "$COLLECTOR_DIR/${collector}.sh"
    fi
done
