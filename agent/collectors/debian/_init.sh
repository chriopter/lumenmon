#!/bin/bash
# Debian/Ubuntu collectors - only runs on Debian-based systems.
# Detects Debian/Ubuntu by checking for apt-get command and /etc/debian_version.

# Check if this is a Debian-based system (return early if not, don't exit - we're sourced)
if ! command -v apt-get &>/dev/null || [ ! -f /etc/debian_version ]; then
    return 0 2>/dev/null || true
fi

echo "[agent] Debian/Ubuntu detected"

COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for collector in updates; do
    if [ -f "$COLLECTOR_DIR/${collector}.sh" ]; then
        run_collector "debian_${collector}" "$COLLECTOR_DIR/${collector}.sh"
    fi
done