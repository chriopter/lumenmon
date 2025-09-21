#!/bin/sh
# Console status - detailed with colors

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Console:"

# Container
echo -e "  Container    ${GREEN}✓${NC} Running"

# SSH daemon
if pgrep -f sshd >/dev/null; then
    echo -e "  SSH Server   ${GREEN}✓${NC} Port ${CONSOLE_PORT:-2345}"
else
    echo -e "  SSH Server   ${RED}✗${NC} Not running"
fi

# Host key
if [ -f /data/ssh/ssh_host_ed25519_key ]; then
    echo -e "  Host Key     ${GREEN}✓${NC} Configured"
else
    echo -e "  Host Key     ${RED}✗${NC} Missing"
fi

# Authorized keys
if [ -f /data/ssh/authorized_keys ]; then
    KEYS=$(grep -c "^ssh-" /data/ssh/authorized_keys 2>/dev/null || echo 0)
    if [ $KEYS -gt 0 ]; then
        echo -e "  Auth Keys    ${GREEN}✓${NC} $KEYS keys"
    else
        echo -e "  Auth Keys    ${YELLOW}⚠${NC} No keys"
    fi
else
    echo -e "  Auth Keys    ${YELLOW}⚠${NC} No file"
fi

# Agents
if [ -d /data/agents ]; then
    TOTAL=$(ls /data/agents 2>/dev/null | wc -l)

    # Connected agents (have active processes)
    CONNECTED=0
    for AGENT_DIR in /data/agents/*; do
        [ -d "$AGENT_DIR" ] || continue
        AGENT_ID=$(basename "$AGENT_DIR")
        if pgrep -u "$AGENT_ID" >/dev/null 2>&1; then
            CONNECTED=$((CONNECTED + 1))
        fi
    done

    # Active agents (recent data - check multiple locations)
    ACTIVE=0
    for AGENT_DIR in /data/agents/*; do
        [ -d "$AGENT_DIR" ] || continue
        AGENT_ID=$(basename "$AGENT_DIR")

        # Check hot data directory
        HOT="/var/lib/lumenmon/hot/$AGENT_ID"
        if [ -d "$HOT" ]; then
            # Check if any TSV file was modified in last 5 minutes
            if find "$HOT" -name "*.tsv" -mmin -5 2>/dev/null | grep -q .; then
                ACTIVE=$((ACTIVE + 1))
                continue
            fi
        fi

        # Also check agent's data directory
        if find "$AGENT_DIR" -name "*.tsv" -mmin -5 2>/dev/null | grep -q .; then
            ACTIVE=$((ACTIVE + 1))
        fi
    done

    echo -e "  Agents       ${GREEN}✓${NC} $TOTAL registered"

    if [ $CONNECTED -gt 0 ]; then
        echo -e "  Connections  ${GREEN}✓${NC} $CONNECTED active"
    else
        echo -e "  Connections  ${YELLOW}⚠${NC} None active"
    fi

    if [ $ACTIVE -gt 0 ]; then
        echo -e "  Data Flow    ${GREEN}✓${NC} $ACTIVE sending"
    else
        echo -e "  Data Flow    ${YELLOW}⚠${NC} No recent data"
    fi
else
    echo -e "  Agents       ${RED}✗${NC} Directory missing"
fi