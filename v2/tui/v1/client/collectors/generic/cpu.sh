#!/bin/sh
# CPU metrics collector

# === CONFIG ===
INTERVAL="allegro"
PREFIX="generic_cpu"

# === COLLECT ===
# Get CPU usage percentage (idle time)
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Get number of CPU cores
CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")

# Get load average
LOAD=$(cat /proc/loadavg | awk '{print $1}')

# === OUTPUT ===
echo "${PREFIX}_usage:${CPU_IDLE:-0}:float"
echo "${PREFIX}_cores:${CPU_CORES}:int"
echo "${PREFIX}_load:${LOAD}:float"