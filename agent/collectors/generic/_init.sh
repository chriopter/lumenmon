#!/bin/bash
# Generic collectors - always runs on all systems.
# Starts cpu, memory, disk, heartbeat, hostname, lumenmon collectors.

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in cpu disk heartbeat hostname lumenmon memory; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        "$COLLECTOR_DIR/${collector}.sh" 2>/tmp/collector_generic_${collector}.log &
    fi
done
