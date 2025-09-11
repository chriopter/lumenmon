#!/bin/sh
# Memory metrics collector

# === CONFIG ===
TEMPO="allegro"
INTERVAL=${ALLEGRO_INTERVAL:-5}
PREFIX="lumenmon_memory"

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

# === OUTPUT with type and interval ===
echo "${PREFIX}_total_kb:${MEM_TOTAL:-0}:int:${INTERVAL}"
echo "${PREFIX}_available_kb:${MEM_AVAILABLE:-0}:int:${INTERVAL}"
echo "${PREFIX}_free_kb:${MEM_FREE:-0}:int:${INTERVAL}"
echo "${PREFIX}_percent:${MEM_PERCENT:-0}:float:${INTERVAL}"
echo "${PREFIX}_swap_total_kb:${SWAP_TOTAL:-0}:int:${INTERVAL}"
echo "${PREFIX}_swap_free_kb:${SWAP_FREE:-0}:int:${INTERVAL}"