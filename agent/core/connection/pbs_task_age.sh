#!/bin/bash
# Shared PBS task-age helper for backup/gc/sync/verify collectors.
# Uses task list timestamps first, then legacy log mtime fallback.

pbs_latest_task_ts() {
    local task_kind="$1"
    local raw=""

    command -v proxmox-backup-manager >/dev/null 2>&1 || return 1
    command -v python3 >/dev/null 2>&1 || return 1

    raw="$(LC_ALL=C proxmox-backup-manager task list --output-format json 2>/dev/null || true)"
    [ -n "$raw" ] || return 1

    printf '%s\n' "$raw" | python3 - "$task_kind" <<'PY'
import json
import re
import sys

task_kind = sys.argv[1]

patterns = {
    'backup': r'\bbackup\b',
    'gc': r'\bgc\b|garbage',
    'sync': r'\bsync\b',
    'verify': r'\bverify\b|verification',
}

pattern = patterns.get(task_kind)
if pattern is None:
    raise SystemExit(1)

try:
    payload = json.loads(sys.stdin.read() or '[]')
except Exception:
    raise SystemExit(1)

if isinstance(payload, dict):
    payload = payload.get('data', [])
if not isinstance(payload, list):
    raise SystemExit(1)

latest = 0
for task in payload:
    if not isinstance(task, dict):
        continue

    search_text = ' '.join(str(task.get(key, '')) for key in ('worker_type', 'task', 'upid')).lower()
    if not re.search(pattern, search_text, re.I):
        continue

    ts = 0
    for key in ('endtime', 'end_time', 'starttime', 'start_time', 'timestamp', 'time'):
        value = task.get(key)
        if isinstance(value, (int, float)):
            ts = max(ts, int(value))
        elif isinstance(value, str) and value.isdigit():
            ts = max(ts, int(value))

    if ts <= 0:
        upid = str(task.get('upid') or '')
        parts = upid.split(':')
        if len(parts) > 4:
            try:
                ts = int(parts[4], 16)
            except Exception:
                ts = 0

    latest = max(latest, ts)

if latest > 0:
    print(latest)
PY
}

get_pbs_task_age_hours() {
    local task_kind="$1"
    local fallback_log_file="$2"
    local max_hours="$3"
    local latest_ts=""
    local now=""
    local mtime=""

    if latest_ts="$(pbs_latest_task_ts "$task_kind")" && [[ "$latest_ts" =~ ^[0-9]+$ ]]; then
        now="$(date +%s)"
        if [ "$latest_ts" -ge "$now" ]; then
            echo 0
        else
            echo $(((now - latest_ts) / 3600))
        fi
        return 0
    fi

    if [ -f "$fallback_log_file" ]; then
        now="$(date +%s)"
        mtime="$(stat -c %Y "$fallback_log_file" 2>/dev/null || echo "$now")"
        echo $(((now - mtime) / 3600))
        return 0
    fi

    # No task evidence and no legacy log file: publish bounded failure value.
    echo $((max_hours + 1))
}
