#!/bin/sh
# Top output collector - full system overview as blob

# === CONFIG ===
INTERVAL="andante"
PREFIX="generic_top"

# === COLLECT ===
# Get full top output (batch mode, one iteration)
# -b: batch mode (non-interactive)
# -n 1: one iteration only
# Base64 encode to handle all the special chars and newlines
TOP_OUTPUT=$(top -b -n 1 | base64 -w 0)

# === OUTPUT ===
echo "${PREFIX}_snapshot:${TOP_OUTPUT}:blob"