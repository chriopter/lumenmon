#!/bin/bash
# Collects Intel GPU busy percentage when available.
# Exits cleanly on hosts without Intel GPU tooling.

RHYTHM="CYCLE"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    if command -v intel_gpu_top >/dev/null 2>&1; then
        gpu_busy=$(timeout 2 intel_gpu_top -J -s 1000 2>/dev/null | python3 - <<'PY'
import json,sys
lines = sys.stdin.read().strip().splitlines()
value = None
for line in reversed(lines):
    try:
        payload = json.loads(line)
    except Exception:
        continue
    engines = payload.get('engines', {})
    values = []
    for item in engines.values():
        busy = item.get('busy')
        if isinstance(busy, (int, float)):
            values.append(float(busy))
    if values:
        value = max(values)
        break
print(int(value) if value is not None else '')
PY
)
        if [ -n "$gpu_busy" ]; then
            publish_metric "hardware_intel_gpu_busy_pct" "$gpu_busy" "INTEGER" "$CYCLE" 0 100
        fi
    fi

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
