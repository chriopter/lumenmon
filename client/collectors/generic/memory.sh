#!/bin/sh
# Memory metrics collector

# === IDENTITY ===
GROUP="generic"
COLLECTOR="memory"
PREFIX="${GROUP}_${COLLECTOR}"

# === COLLECT ===
# Parse /proc/meminfo for memory metrics
while IFS=: read -r key value; do
    case "$key" in
        MemTotal)
            MEM_TOTAL=$(echo "$value" | awk '{print $1}')
            ;;
        MemFree)
            MEM_FREE=$(echo "$value" | awk '{print $1}')
            ;;
        MemAvailable)
            MEM_AVAILABLE=$(echo "$value" | awk '{print $1}')
            ;;
        SwapTotal)
            SWAP_TOTAL=$(echo "$value" | awk '{print $1}')
            ;;
        SwapFree)
            SWAP_FREE=$(echo "$value" | awk '{print $1}')
            ;;
    esac
done < /proc/meminfo

# Calculate usage percentage
if [ -n "$MEM_TOTAL" ] && [ "$MEM_TOTAL" -gt 0 ]; then
    MEM_USED=$((MEM_TOTAL - MEM_AVAILABLE))
    MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))
fi

# === OUTPUT ===
echo "${PREFIX}_total:${MEM_TOTAL:-0}"
echo "${PREFIX}_available:${MEM_AVAILABLE:-0}"
echo "${PREFIX}_free:${MEM_FREE:-0}"
echo "${PREFIX}_percent:${MEM_PERCENT:-0}"
echo "${PREFIX}_swap_total:${SWAP_TOTAL:-0}"
echo "${PREFIX}_swap_free:${SWAP_FREE:-0}"