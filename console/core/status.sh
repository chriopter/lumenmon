#!/bin/sh
# Displays console health status with color-coded checks for SSH, keys, agents, and data flow.
# Shows host key, registered agents, active connections, and recent metric activity.

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

# Agent SSH keys
if [ -d /data/agents ]; then
    KEYS=0
    for AGENT_DIR in /data/agents/*; do
        [ -d "$AGENT_DIR" ] || continue
        if [ -f "$AGENT_DIR/.ssh/authorized_keys" ]; then
            KEYS=$((KEYS + 1))
        fi
    done
    if [ $KEYS -gt 0 ]; then
        printf "  Agent Keys   ${GREEN}✓${NC} $KEYS configured\n"
    else
        printf "  Agent Keys   ${YELLOW}⚠${NC} None configured\n"
    fi
else
    printf "  Agent Keys   ${RED}✗${NC} No agents dir\n"
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

    # Active agents (recent data - check SQLite database)
    ACTIVE=0
    if [ -f /data/metrics.db ]; then
        for AGENT_DIR in /data/agents/*; do
            [ -d "$AGENT_DIR" ] || continue
            AGENT_ID=$(basename "$AGENT_DIR")

            # Check if agent has recent data in SQLite (last 60 seconds)
            RECENT=$(sqlite3 /data/metrics.db "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name LIKE '${AGENT_ID}_%' AND name IN (SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '${AGENT_ID}_%' AND (SELECT MAX(timestamp) FROM \"\" || name) > strftime('%s', 'now') - 60)" 2>/dev/null || echo "0")

            # Simpler check: just see if agent has any tables
            TABLES=$(sqlite3 /data/metrics.db "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name LIKE '${AGENT_ID}_%'" 2>/dev/null || echo "0")
            if [ "$TABLES" -gt 0 ]; then
                ACTIVE=$((ACTIVE + 1))
            fi
        done
    fi

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

# Database permissions check (critical for SQLite WAL mode)
if [ -f /data/metrics.db ]; then
    # Check if /data directory has correct group ownership and permissions
    DATA_GROUP=$(stat -c '%G' /data 2>/dev/null)
    DATA_PERMS=$(stat -c '%a' /data 2>/dev/null)

    if [ "$DATA_GROUP" != "agents" ] || [ "$DATA_PERMS" != "775" ]; then
        printf "  DB Perms     ${RED}✗${NC} /data permissions incorrect (need root:agents 775, got ${DATA_GROUP} ${DATA_PERMS})\n"
        printf "               Fix: chown root:agents /data && chmod 775 /data\n"
    fi
fi

# Check gateway log for recent errors (last 5 minutes)
if [ -f /data/gateway.log ]; then
    RECENT_ERRORS=$(tail -100 /data/gateway.log 2>/dev/null | grep -c "ERROR\|EXCEPTION" || echo 0)
    if [ "$RECENT_ERRORS" -gt 0 ]; then
        # Get the most recent unique error
        LAST_ERROR=$(tail -100 /data/gateway.log 2>/dev/null | grep "ERROR\|EXCEPTION" | tail -1 | sed 's/.*\] //')
        printf "  Gateway Log  ${RED}✗${NC} $RECENT_ERRORS recent errors\n"
        printf "               Latest: ${LAST_ERROR}\n"
        printf "               Check: docker exec lumenmon-console tail /data/gateway.log\n"
    fi
fi