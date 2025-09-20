#!/bin/bash
# Setup data directories and restore agents

set -euo pipefail

echo "[console] Setting up data storage..."
mkdir -p /data/agents

# Restore agent users from existing directories
source /app/lib/restore_agents.sh