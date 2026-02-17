#!/bin/bash
# Runs all collector init paths in test mode and prints emitted metrics.
# Useful for debugging collector detection, startup, and output quickly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LUMENMON_HOME="${LUMENMON_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LUMENMON_DATA="${LUMENMON_DATA:-$LUMENMON_HOME/data}"

echo "Collector Debug"
echo "━━━━━━━━━━━━━━━"
echo "Home: $LUMENMON_HOME"
echo "Data: $LUMENMON_DATA"
echo ""

export LUMENMON_TEST_MODE=1
export LUMENMON_HOME LUMENMON_DATA
export PULSE=1 BREATHE=60 CYCLE=300 REPORT=3600

TOTAL=0
FAILED=0
EMITTED=0

run_collector() {
    local name="$1"
    local script="$2"
    local start
    local elapsed
    local output
    local rc

    TOTAL=$((TOTAL + 1))
    start=$(date +%s)

    if output=$(timeout 8s "$script" 2>&1); then
        elapsed=$(( $(date +%s) - start ))
        printf "[OK]      %-26s (%ss)\n" "$name" "$elapsed"
        if [ -n "$output" ]; then
            printf "%s\n" "$output" | sed 's/^/  /'
            EMITTED=$((EMITTED + 1))
        else
            echo "  (no metrics emitted)"
        fi
    else
        rc=$?
        elapsed=$(( $(date +%s) - start ))
        FAILED=$((FAILED + 1))
        if [ "$rc" -eq 124 ]; then
            printf "[TIMEOUT] %-26s (%ss)\n" "$name" "$elapsed"
        else
            printf "[FAILED]  %-26s (%ss, exit %s)\n" "$name" "$elapsed" "$rc"
        fi
        if [ -n "${output:-}" ]; then
            printf "%s\n" "$output" | sed 's/^/  /'
        fi
    fi
    echo ""
}

for init in "$LUMENMON_HOME/collectors"/*/_init.sh; do
    [ -f "$init" ] || continue
    echo "==> $(basename "$(dirname "$init")")"
    source "$init"
done

echo "Summary"
echo "  Collectors checked: $TOTAL"
echo "  With output:        $EMITTED"
echo "  Failed/timeouts:    $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
