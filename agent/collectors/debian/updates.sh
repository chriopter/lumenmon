#!/bin/bash
# Collects available updates for Debian/Ubuntu via apt (read-only).
# Reports total, security, and release upgrades at REPORT interval (1hr).

# Config
RHYTHM="REPORT"                         # Uses REPORT timing (1hr)
METRIC_UPDATES="debian_updates_total"   # Total updates
METRIC_SECURITY="debian_updates_security"  # Security updates
METRIC_RELEASE="debian_updates_release" # Release upgrade (0 or 1)
METRIC_FRESHNESS="debian_updates_age"   # Hours since last apt update
TYPE="INTEGER"
MIN=0
MAX=0  # >0 triggers warning

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Get age of package lists in hours
get_update_age() {
    local age_hours=999

    # Check modification time of package lists
    if [ -d /var/lib/apt/lists ]; then
        # Find newest package file
        local newest=$(find /var/lib/apt/lists -maxdepth 1 -name "*_Packages" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1)
        if [ -n "$newest" ]; then
            local now=$(date +%s)
            local age_seconds=$((now - ${newest%.*}))
            age_hours=$((age_seconds / 3600))
        fi
    fi

    echo "$age_hours"
}

while true; do
    # Check freshness of package lists (no system modification)
    freshness=$(get_update_age)

    # Count total updates (from cached package lists)
    # Force English locale for consistent output parsing
    total=$(LC_ALL=C apt list --upgradable 2>/dev/null | grep -c "upgradable from" || echo "0")

    # Count security updates
    security=$(LC_ALL=C apt list --upgradable 2>/dev/null | grep -cE "(-security|/.*-security)" || echo "0")

    # Check for release upgrade (read-only check)
    release=0
    if command -v do-release-upgrade &>/dev/null; then
        LC_ALL=C do-release-upgrade -c 2>/dev/null | grep -q "New release" && release=1 || true
    fi

    # Publish metrics with thresholds
    publish_metric "$METRIC_UPDATES" "$total" "$TYPE" "$REPORT" "$MIN" "$MAX"
    publish_metric "$METRIC_SECURITY" "$security" "$TYPE" "$REPORT" "$MIN" "$MAX"
    publish_metric "$METRIC_RELEASE" "$release" "$TYPE" "$REPORT" "$MIN" "$MAX"
    publish_metric "$METRIC_FRESHNESS" "$freshness" "$TYPE" "$REPORT" 0 24  # Warn if >24h old

    sleep $REPORT
done