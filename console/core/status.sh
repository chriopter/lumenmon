#!/bin/sh
# Console status - detailed with colors

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Console:"

# Container
printf "  Container    ${GREEN}✓${NC} Running\n"

# SSH daemon
if pgrep -f sshd >/dev/null; then
    printf "  SSH Server   ${GREEN}✓${NC} Port ${CONSOLE_PORT:-2345}\n"
else
    printf "  SSH Server   ${RED}✗${NC} Not running\n"
fi

# Host key
if [ -f /data/ssh/ssh_host_ed25519_key ]; then
    printf "  Host Key     ${GREEN}✓${NC} Configured\n"
else
    printf "  Host Key     ${RED}✗${NC} Missing\n"
fi

# Authorized keys
if [ -f /data/ssh/authorized_keys ]; then
    KEYS=$(grep -c "^ssh-" /data/ssh/authorized_keys 2>/dev/null || echo 0)
    if [ $KEYS -gt 0 ]; then
        printf "  Auth Keys    ${GREEN}✓${NC} $KEYS keys\n"
    else
        printf "  Auth Keys    ${YELLOW}⚠${NC} No keys\n"
    fi
else
    printf "  Auth Keys    ${YELLOW}⚠${NC} No file\n"
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

    printf "  Agents       ${GREEN}✓${NC} $TOTAL registered\n"

    if [ $CONNECTED -gt 0 ]; then
        printf "  Connections  ${GREEN}✓${NC} $CONNECTED active\n"
    else
        printf "  Connections  ${YELLOW}⚠${NC} None active\n"
    fi

    if [ $ACTIVE -gt 0 ]; then
        printf "  Data Flow    ${GREEN}✓${NC} $ACTIVE sending\n"
    else
        printf "  Data Flow    ${YELLOW}⚠${NC} No recent data\n"
    fi
else
    printf "  Agents       ${RED}✗${NC} Directory missing\n"
fi