#!/bin/bash
# Reads metric history from TSV files for sparkline and graph generation.
# Provides get_history() and get_history_line() to extract multiple time-series points. Sourced by tui.sh.
# Get last N values from a metric file
# Usage: get_history <agent_id> <metric_file> <points>
get_history() {
    local agent=$1
    local metric=$2
    local points=${3:-10}
    local file="/data/agents/$agent/$metric"

    [ -f "$file" ] || return 1

    # Read last N lines, extract values (field 3)
    tail -"$points" "$file" 2>/dev/null | awk '{print $3}'
}

# Get history as space-separated string (for sparkline)
# Usage: get_history_line <agent_id> <metric_file> <points>
get_history_line() {
    local agent=$1
    local metric=$2
    local points=${3:-10}

    get_history "$agent" "$metric" "$points" | tr '\n' ' '
}
