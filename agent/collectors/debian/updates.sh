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
ALERT_GRACE_HOURS=24
TOTAL_WARN_MAX=0      # >0 updates => warning (after grace)
SECURITY_WARN_MAX=0   # >0 security updates => warning (after grace)
RELEASE_FAIL_MAX=0    # >0 release upgrade check stays critical
STATE_FILE="$LUMENMON_DATA/debian_updates_pending"

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

read_pending_since() {
    local key="$1"
    local value=""
    value=$(awk -F= -v key="$key" '$1==key {print $2; exit}' "$STATE_FILE" 2>/dev/null || true)
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
    else
        echo 0
    fi
}

save_pending_since() {
    local total_since="$1"
    local security_since="$2"
    local tmp_file="${STATE_FILE}.tmp"

    printf 'total=%s\nsecurity=%s\n' "$total_since" "$security_since" > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"
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

    # Track how long updates have continuously been pending.
    now=$(date +%s)
    total_pending_since=$(read_pending_since total)
    security_pending_since=$(read_pending_since security)

    if [ "$total" -gt 0 ]; then
        [ "$total_pending_since" -le 0 ] && total_pending_since="$now"
    else
        total_pending_since=0
    fi

    if [ "$security" -gt 0 ]; then
        [ "$security_pending_since" -le 0 ] && security_pending_since="$now"
    else
        security_pending_since=0
    fi

    total_pending_hours=0
    security_pending_hours=0
    [ "$total_pending_since" -gt 0 ] && total_pending_hours=$(((now - total_pending_since) / 3600))
    [ "$security_pending_since" -gt 0 ] && security_pending_hours=$(((now - security_pending_since) / 3600))

    # Publish metrics with delayed alerting.
    # Only warn once updates have been pending for at least 24h.
    if [ "$total" -gt 0 ] && [ "$total_pending_hours" -ge "$ALERT_GRACE_HOURS" ]; then
        publish_metric "$METRIC_UPDATES" "$total" "$TYPE" "$REPORT" "$MIN" "" "" "$TOTAL_WARN_MAX"
    else
        publish_metric "$METRIC_UPDATES" "$total" "$TYPE" "$REPORT" "$MIN"
    fi

    if [ "$security" -gt 0 ] && [ "$security_pending_hours" -ge "$ALERT_GRACE_HOURS" ]; then
        publish_metric "$METRIC_SECURITY" "$security" "$TYPE" "$REPORT" "$MIN" "" "" "$SECURITY_WARN_MAX"
    else
        publish_metric "$METRIC_SECURITY" "$security" "$TYPE" "$REPORT" "$MIN"
    fi

    # Release upgrade is still treated as hard-fail signal.
    publish_metric "$METRIC_RELEASE" "$release" "$TYPE" "$REPORT" "$MIN" "$RELEASE_FAIL_MAX"
    publish_metric "$METRIC_FRESHNESS" "$freshness" "$TYPE" "$REPORT" 0 72  # Warn if >72h old

    if [ "${LUMENMON_TEST_MODE:-}" != "1" ]; then
        save_pending_since "$total_pending_since" "$security_pending_since"
    fi

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    # Wait for next interval OR until apt lists change (whichever comes first)
    # inotifywait returns immediately if apt update runs, otherwise times out after REPORT seconds
    if command -v inotifywait &>/dev/null; then
        inotifywait -t $REPORT -qq -e modify -e create -e delete /var/lib/apt/lists 2>/dev/null || true
    else
        sleep $REPORT
    fi
done
