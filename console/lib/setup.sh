#!/bin/bash
# Setup data directories

set -euo pipefail

echo "[console] Setting up data storage..."
mkdir -p /data/agents

# Create agents group for SSH matching
if ! getent group agents > /dev/null 2>&1; then
    echo "[console] Creating 'agents' group for SSH user matching..."
    groupadd agents
fi