#!/bin/sh
# Process monitoring collector - demonstrates blob type

# === CONFIG ===
INTERVAL="andante"
PREFIX="generic_process"

# === COLLECT ===
# Count total processes
PROCESS_COUNT=$(ps aux | wc -l)

# Top 5 CPU consuming processes (comma-separated, no newlines)
TOP_CPU=$(ps aux --sort=-%cpu | head -6 | tail -5 | awk '{print $11}' | tr '\n' ',' | sed 's/,$//')

# Get full process list - base64 encode to handle newlines
PROCESS_LIST=$(ps aux | head -20 | base64 -w 0)

# === OUTPUT ===
echo "${PREFIX}_count:${PROCESS_COUNT}:int"
echo "${PREFIX}_top_cpu:${TOP_CPU}:string"
echo "${PREFIX}_list:${PROCESS_LIST}:blob"