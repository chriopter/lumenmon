#!/bin/bash
# NOEXEC — This is a template, not a runnable collector.
# COLLECTOR TEMPLATE
# Copy this file to create a new collector.
# Place it in the appropriate subdirectory:
#   collectors/generic/   → generic_*  (runs on all Linux systems)
#   collectors/debian/    → debian_*   (Debian/Ubuntu only)
#   collectors/proxmox/   → proxmox_*  (Proxmox VE only)
#   collectors/optional/  → *          (opt-in via agent.conf)
#
# IMPORTANT:
# - The RHYTHM variable MUST match the sleep variable used below
# - Use LC_ALL=C for any command that produces localized output
# - Support LUMENMON_TEST_MODE for `lumenmon-agent status` to work

# ── Config ──────────────────────────────────────────────────────────
RHYTHM="BREATHE"          # PULSE=1s | BREATHE=60s | CYCLE=5m | REPORT=1h
METRIC="generic_example"  # Metric name (prefix with category)
TYPE="REAL"               # REAL (decimals) | INTEGER (whole) | TEXT (strings)
MIN=0                     # Minimum valid value (optional, for health detection)
MAX=100                   # Maximum valid value (optional, for health detection)
# Health: values outside MIN/MAX show as FAILED in dashboard

# ── Setup ───────────────────────────────────────────────────────────
set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

# ── Main loop ───────────────────────────────────────────────────────
while true; do
    # Collect your metric value here
    # Use LC_ALL=C for commands with localized output:
    #   value=$(LC_ALL=C some_command | parse_output)
    value="0"

    # Publish: name, value, type, interval, [min], [max]
    # The interval MUST use the same variable as RHYTHM (e.g. $BREATHE)
    publish_metric "$METRIC" "$value" "$TYPE" "$BREATHE" "$MIN" "$MAX"

    # Support test mode (required for `lumenmon-agent status`)
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    # Sleep MUST use the same timing variable as RHYTHM
    sleep $BREATHE
done

# ── Notes ───────────────────────────────────────────────────────────
# Rhythm variables (set by agent.sh):
#   $PULSE   = 1s    → high-frequency (cpu, heartbeat)
#   $BREATHE = 60s   → medium (disk, memory)
#   $CYCLE   = 300s  → low (proxmox, optional)
#   $REPORT  = 3600s → rare (hostname, version, updates)
#
# One-time metrics (no loop needed):
#   publish_metric "name" "$value" "TEXT" 0
#   → interval=0 means the value never goes stale
#
# Dynamic bounds (e.g. ZFS online drives must equal total):
#   publish_metric "zfs_online" "$online" "INTEGER" "$CYCLE" "$total" "$total"
#
# Multiple metrics from one collector:
#   Just call publish_metric multiple times with different names.
#   See collectors/generic/lumenmon.sh for an example.
