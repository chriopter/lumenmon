#!/bin/bash
# TrueNAS collectors - runs on TrueNAS CORE and SCALE.
# Detects TrueNAS by checking for midclt (SCALE) or freenas-debug (CORE).

# Check if this is a TrueNAS host
is_truenas=false
if command -v midclt &>/dev/null; then
    is_truenas=true
    truenas_type="SCALE"
elif [ -f /etc/version ] && grep -qi "truenas\|freenas" /etc/version 2>/dev/null; then
    is_truenas=true
    truenas_type="CORE"
fi

if [ "$is_truenas" != "true" ]; then
    return 0 2>/dev/null || true
fi

echo "[agent] TrueNAS $truenas_type detected"

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in zfs shares; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        run_collector "truenas_${collector}" "$COLLECTOR_DIR/${collector}.sh"
    fi
done
