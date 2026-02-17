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

    # Check apt's update stamp first (accounts for HTTP 304 caching)
    # This file is touched whenever apt-get update successfully runs
    if [ -f /var/lib/apt/periodic/update-stamp ]; then
        local stamp_time=$(stat -c %Y /var/lib/apt/periodic/update-stamp 2>/dev/null)
        if [ -n "$stamp_time" ]; then
            local now=$(date +%s)
            local age_seconds=$((now - stamp_time))
            age_hours=$((age_seconds / 3600))
            echo "$age_hours"
            return 0
        fi
    fi

    # Fallback: Check modification time of package lists
    # (for systems not using apt-daily or manual updates)
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

    # Count updates that are actually installable now.
    # Use apt-get simulation output so phased/held-back updates are excluded.
    total=0
    security=0
    if sim_output=$(LC_ALL=C apt-get -s upgrade 2>/dev/null); then
        total=$(printf '%s\n' "$sim_output" | awk '/upgraded, [0-9]+ newly installed, [0-9]+ to remove and [0-9]+ not upgraded/ {print $1; found=1; exit} END {if (!found) print 0}')
        security=$(printf '%s\n' "$sim_output" | awk '/^Inst / && /security/ {count++} END {print count+0}')
    fi

    # Check for release upgrade (read-only check)
    release=0
    if command -v do-release-upgrade &>/dev/null; then
        LC_ALL=C do-release-upgrade -c 2>/dev/null | grep -q "New release" && release=1 || true
    fi

    # Publish metrics with thresholds
    publish_metric "$METRIC_UPDATES" "$total" "$TYPE" "$REPORT" "$MIN" "$MAX"
    publish_metric "$METRIC_SECURITY" "$security" "$TYPE" "$REPORT" "$MIN" "$MAX"
    publish_metric "$METRIC_RELEASE" "$release" "$TYPE" "$REPORT" "$MIN" "$MAX"
    publish_metric "$METRIC_FRESHNESS" "$freshness" "$TYPE" "$REPORT" 0 72  # Warn if >72h old
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    # Wait for next interval OR until apt lists change (whichever comes first)
    # inotifywait returns immediately if apt update runs, otherwise times out after REPORT seconds
    if command -v inotifywait &>/dev/null; then
        inotifywait -t $REPORT -qq -e modify -e create -e delete /var/lib/apt/lists 2>/dev/null || true
    else
        sleep $REPORT
    fi
done
