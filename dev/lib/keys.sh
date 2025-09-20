#!/bin/bash
# Check SSH keys inside containers
set -e

# Colors
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}[KEYS]${NC} Checking SSH keys inside containers..."

echo -e "${CYAN}Console keys (/data/ssh/):${NC}"
docker exec lumenmon-console sh -c 'for f in /data/ssh/*.pub; do [ -f "$f" ] && echo "  $(basename "$f"): $(head -c 100 "$f")..."; done' 2>/dev/null || echo "  Console not running"

echo -e "${CYAN}Agent keys (/home/metrics/.ssh/):${NC}"
docker exec lumenmon-agent sh -c 'for f in /home/metrics/.ssh/*.pub; do [ -f "$f" ] && echo "  $(basename "$f"): $(head -c 100 "$f")..."; done' 2>/dev/null || echo "  Agent not running"