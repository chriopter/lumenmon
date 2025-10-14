#!/bin/bash
# Read metric values from TSV files

# Read latest value from a metric file
# Usage: get_metric <agent_id> <metric_file>
get_metric() {
    local agent=$1
    local metric=$2
    local file="/data/agents/$agent/$metric"

    [ -f "$file" ] || return 1

    # Read last line, extract value (field 3)
    tail -1 "$file" 2>/dev/null | awk '{print $3}'
}

# Get metric age in seconds
# Usage: get_metric_age <agent_id> <metric_file>
get_metric_age() {
    local agent=$1
    local metric=$2
    local file="/data/agents/$agent/$metric"

    [ -f "$file" ] || { echo "999"; return 1; }

    # Read timestamp (field 1)
    local ts=$(tail -1 "$file" 2>/dev/null | awk '{print $1}')

    # Calculate age
    echo $(($(date +%s) - ${ts:-0}))
}
