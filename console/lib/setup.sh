#!/bin/bash
# Setup data directories and restore agents

set -euo pipefail

echo "[console] Setting up data storage..."
mkdir -p /data/agents

# Setup registration queue with proper permissions
# 1730: sticky bit + owner rwx + group wx (no read) + others nothing
# This allows registration users to write keys but not read each other's files
mkdir -p /data/registration_queue
chgrp registration /data/registration_queue
chmod 1730 /data/registration_queue

# Restore agent users from existing directories
source /app/lib/restore_agents.sh