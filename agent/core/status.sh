#!/bin/sh
# Agent status - detailed with colors

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Agent:"

# Container
echo -e "  Container    ${GREEN}✓${NC} Running"

# Configuration
if [ -n "$CONSOLE_HOST" ]; then
    echo -e "  Config       ${GREEN}✓${NC} $CONSOLE_HOST:${CONSOLE_PORT:-22}"
else
    echo -e "  Config       ${RED}✗${NC} Not configured"
    exit
fi

# Network test
if nc -zw1 "$CONSOLE_HOST" "${CONSOLE_PORT:-22}" 2>/dev/null; then
    echo -e "  Network      ${GREEN}✓${NC} Console reachable"
else
    echo -e "  Network      ${RED}✗${NC} Cannot reach console"
fi

# SSH tunnel
SSH_COUNT=$(pgrep -f "ssh.*$CONSOLE_HOST" | wc -l)
if [ $SSH_COUNT -gt 0 ]; then
    echo -e "  SSH Tunnel   ${GREEN}✓${NC} Established"
else
    echo -e "  SSH Tunnel   ${RED}✗${NC} Not connected"
fi

# Collector processes
COLLECTORS=$(pgrep -f "collector" | wc -l)
if [ $COLLECTORS -gt 0 ]; then
    echo -e "  Collectors   ${GREEN}✓${NC} $COLLECTORS running"
else
    echo -e "  Collectors   ${YELLOW}⚠${NC} None running"
fi

# Metrics
if [ -f /tmp/last_metric ]; then
    TIME=$(tail -1 /tmp/last_metric 2>/dev/null | cut -d' ' -f1 | cut -dT -f2 | cut -d. -f1)
    if [ -n "$TIME" ]; then
        echo -e "  Metrics      ${GREEN}✓${NC} Last sent: $TIME"
    else
        echo -e "  Metrics      ${YELLOW}⚠${NC} No timestamp"
    fi
elif ls /tmp/*.tsv 2>/dev/null | head -1 >/dev/null; then
    COUNT=$(ls /tmp/*.tsv 2>/dev/null | wc -l)
    echo -e "  Metrics      ${YELLOW}⚠${NC} $COUNT files buffered"
else
    echo -e "  Metrics      ${RED}✗${NC} No data"
fi