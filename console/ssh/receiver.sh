#!/bin/bash
# TSV receiver - Reads from stdin, writes to tmpfs
# Ultra simple: receive TSV, write to files, maintain ring buffer

set -euo pipefail

# Data directory (tmpfs)
DATA_DIR="/var/lib/lumenmon/hot"

# Extract agent ID from forced command argument or SSH client
AGENT_ID=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            AGENT_ID="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Fallback to SSH client IP if no agent ID
if [ -z "$AGENT_ID" ]; then
    AGENT_ID="${SSH_CLIENT%% *}"
fi

# Process incoming TSV lines
# Format: timestamp \t agent_id \t metric \t type \t value \t interval
while IFS=$'\t' read -r timestamp agent_id metric type value interval; do
    # Use provided agent_id or our detected one
    [ -z "$agent_id" ] && agent_id="$AGENT_ID"

    # Ensure directories exist
    mkdir -p "$DATA_DIR/ring/$agent_id"

    # Write latest value (simple format for easy reading)
    echo -e "$timestamp\t$metric\t$value" > "$DATA_DIR/latest/$agent_id.tsv"

    # Append to ring buffer (per metric)
    echo -e "$timestamp\t$value" >> "$DATA_DIR/ring/$agent_id/$metric.tsv"

    # Keep only last 1000 entries in ring buffer
    if [ $(wc -l < "$DATA_DIR/ring/$agent_id/$metric.tsv" 2>/dev/null || echo 0) -gt 1000 ]; then
        tail -n 1000 "$DATA_DIR/ring/$agent_id/$metric.tsv" > "$DATA_DIR/ring/$agent_id/$metric.tmp"
        mv "$DATA_DIR/ring/$agent_id/$metric.tmp" "$DATA_DIR/ring/$agent_id/$metric.tsv"
    fi
done