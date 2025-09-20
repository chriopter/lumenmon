#!/bin/bash
# Test registration by calling agent's register script
# Usage: test-register.sh "ssh://user:pass@host:port/#fingerprint"

set -e

# Colors
CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ $# -ne 1 ]; then
    echo -e "${RED}Usage: $0 \"ssh://reg_timestamp:password@host:port/#fingerprint\"${NC}"
    exit 1
fi

INVITE_URL="$1"

echo -e "${CYAN}[TEST-REGISTER]${NC} Testing registration with invite URL"
echo -e "${CYAN}[TEST-REGISTER]${NC} URL: $INVITE_URL"

# Check if agent container is running
if ! docker ps | grep -q lumenmon-agent; then
    echo -e "${RED}[ERROR]${NC} Agent container is not running. Run: _dev/dev.sh agent"
    exit 1
fi

# Check what keys exist in agent
echo -e "${CYAN}[TEST-REGISTER]${NC} Checking agent's SSH keys..."
docker exec lumenmon-agent ls -la /home/metrics/.ssh/*.pub 2>/dev/null || echo "No keys found in /home/metrics/.ssh/"

# Show which key will be used
KEY_FILE=$(docker exec lumenmon-agent sh -c "ls /home/metrics/.ssh/*.pub 2>/dev/null | head -1")
if [ -n "$KEY_FILE" ]; then
    echo -e "${CYAN}[TEST-REGISTER]${NC} Using key: $KEY_FILE"
    KEY_TYPE=$(docker exec lumenmon-agent sh -c "cat $KEY_FILE | awk '{print \$1}'")
    echo -e "${CYAN}[TEST-REGISTER]${NC} Key type: $KEY_TYPE"
fi

# Execute registration in the agent container
echo -e "${CYAN}[TEST-REGISTER]${NC} Calling agent registration script..."
if docker exec lumenmon-agent /app/core/setup/register.sh "$INVITE_URL"; then
    echo -e "${GREEN}✓ Registration completed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Check TUI for new agent: _dev/dev.sh tui"
    echo "2. Agent should connect within 30 seconds"
    echo "3. Check logs: docker logs lumenmon-agent"
else
    echo -e "${RED}✗ Registration failed${NC}"
    echo "Check logs: docker logs lumenmon-agent"
    exit 1
fi