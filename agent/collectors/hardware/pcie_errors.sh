#!/bin/bash
# Collects PCIe/AER error count from the last 24 hours.
# Uses journal logs as a platform-neutral signal for bus instability.

RHYTHM="REPORT"
METRIC="hardware_pcie_errors_24h"
TYPE="INTEGER"
MIN=0
MAX=0

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    if command -v journalctl >/dev/null 2>&1; then
        count=$(journalctl --since '24 hours ago' --no-pager 2>/dev/null | awk 'BEGIN {IGNORECASE=1} /AER:|PCIe Bus Error|pcieport.*error/ {count++} END {print count+0}')
    else
        count=$(dmesg 2>/dev/null | awk 'BEGIN {IGNORECASE=1} /AER:|PCIe Bus Error|pcieport.*error/ {count++} END {print count+0}')
    fi
    publish_metric "$METRIC" "$count" "$TYPE" "$REPORT" "$MIN" "$MAX"

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$REPORT"
done
