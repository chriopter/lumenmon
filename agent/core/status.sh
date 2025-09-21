#!/bin/sh
# Agent status - detailed with colors

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Agent:"

# Container
printf "  Container    ${GREEN}✓${NC} Running\n"

# Configuration
if [ -n "$CONSOLE_HOST" ]; then
    printf "  Config       ${GREEN}✓${NC} $CONSOLE_HOST:${CONSOLE_PORT:-22}\n"
else
    printf "  Config       ${RED}✗${NC} Not configured\n"
    exit
fi

# Network test
if nc -zw1 "$CONSOLE_HOST" "${CONSOLE_PORT:-22}" 2>/dev/null; then
    printf "  Network      ${GREEN}✓${NC} Console reachable\n"
else
    printf "  Network      ${RED}✗${NC} Cannot reach console\n"
fi

# SSH tunnel
SSH_COUNT=$(pgrep -f "ssh.*$CONSOLE_HOST" | wc -l)
if [ $SSH_COUNT -gt 0 ]; then
    printf "  SSH Tunnel   ${GREEN}✓${NC} Established\n"
else
    printf "  SSH Tunnel   ${RED}✗${NC} Not connected\n"
fi

# Collector processes
COLLECTORS=$(pgrep -f "collector" | wc -l)
if [ $COLLECTORS -gt 0 ]; then
    printf "  Collectors   ${GREEN}✓${NC} $COLLECTORS running\n"
else
    printf "  Collectors   ${YELLOW}⚠${NC} None running\n"
fi

# Metrics flow check removed - /tmp is flushed too fast for reliable tracking