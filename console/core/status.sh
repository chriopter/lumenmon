#!/bin/sh
# Console status

# Count agents
AGENTS=$(ls /data/agents 2>/dev/null | wc -l)
echo "Console: $AGENTS agents connected"