#!/bin/sh
# Pulse/Heartbeat collector - fastest frequency (5s)
# Sends a simple heartbeat to confirm client is alive

# === CONFIG ===
INTERVAL="allegro"  # 5 second interval
PREFIX="generic_pulse"

# === COLLECT ===
# Simple timestamp as heartbeat
PULSE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
PULSE_EPOCH=$(date '+%s')

# === OUTPUT ===
echo "${PREFIX}_heartbeat:${PULSE_EPOCH}:int"
echo "${PREFIX}_timestamp:${PULSE_TIME}:string"