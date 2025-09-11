#!/bin/sh
# Process monitoring collector - demonstrates blob type

# === CONFIG ===
TEMPO="andante"
INTERVAL=${ANDANTE_INTERVAL:-60}
PREFIX="lumenmon_process"

# === COLLECT ===
# Count total processes
PROCESS_COUNT=$(ps aux | wc -l)

# Top 5 CPU consuming processes
TOP_CPU=$(ps aux --sort=-%cpu | head -6 | tail -5 | awk '{print $11}' | tr '\n' ',')

# Get full process list (blob type)
PROCESS_LIST=$(ps aux | head -20)

# === OUTPUT with type and interval ===
echo "${PREFIX}_count:${PROCESS_COUNT}:int:${INTERVAL}"
echo "${PREFIX}_top_cpu:${TOP_CPU}:string:${INTERVAL}"
echo "${PREFIX}_list:${PROCESS_LIST}:blob:${INTERVAL}"