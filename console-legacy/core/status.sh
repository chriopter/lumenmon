#!/bin/sh
# Displays console health status with color-coded checks for MQTT, certificates, agents, and data flow.
# Shows MQTT broker status, registered agents, and recent metric activity.

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Console:"

# Container
printf "  Container    ${GREEN}✓${NC} Running\n"

# MQTT certificate
if [ -f /data/mqtt/server.crt ]; then
    printf "  TLS Cert     ${GREEN}✓${NC} Configured\n"
else
    printf "  TLS Cert     ${RED}✗${NC} Missing\n"
fi

# MQTT broker (check if mosquitto is running and listening on 8884)
if pgrep mosquitto >/dev/null 2>&1; then
    printf "  MQTT Broker  ${GREEN}✓${NC} Port 8884 (TLS)\n"
else
    printf "  MQTT Broker  ${RED}✗${NC} Not running\n"
fi

# MQTT password file
if [ -f /data/mqtt/passwd ]; then
    PASSWD_COUNT=$(wc -l < /data/mqtt/passwd 2>/dev/null || echo 0)
    if [ "$PASSWD_COUNT" -gt 0 ]; then
        printf "  MQTT Users   ${GREEN}✓${NC} $PASSWD_COUNT configured\n"
    else
        printf "  MQTT Users   ${YELLOW}⚠${NC} None configured\n"
    fi
else
    printf "  MQTT Users   ${RED}✗${NC} No passwd file\n"
fi

# Agents (count unique agent IDs from database tables)
if [ -f /data/metrics.db ]; then
    TOTAL=$(sqlite3 /data/metrics.db "SELECT COUNT(DISTINCT SUBSTR(name, 1, 11)) FROM sqlite_master WHERE type='table' AND name LIKE 'id_%'" 2>/dev/null || echo "0")

    # Active agents from unified RAM API (online + degraded), with DB fallback.
    ACTIVE=0
    if command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
        ACTIVE=$(curl -fsS http://localhost:5000/api/entities 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    entities = data.get("entities", [])
    active = [e for e in entities if str(e.get("id", "")).startswith("id_") and e.get("status") in ("online", "degraded")]
    print(len(active))
except Exception:
    print(0)
' 2>/dev/null || echo 0)
    fi

    # Fallback when API is unavailable: infer activity from heartbeat tables in SQLite.
    if [ "$ACTIVE" = "0" ]; then
        NOW=$(date +%s)
        AGENT_IDS=$(sqlite3 /data/metrics.db "SELECT DISTINCT SUBSTR(name, 1, 11) FROM sqlite_master WHERE type='table' AND name LIKE 'id_%_generic_heartbeat'" 2>/dev/null)

        for AGENT_ID in $AGENT_IDS; do
            LAST_TS=$(sqlite3 /data/metrics.db "SELECT MAX(timestamp) FROM ${AGENT_ID}_generic_heartbeat" 2>/dev/null || echo "0")
            AGE=$((NOW - LAST_TS))
            if [ "$AGE" -lt 10 ]; then
                ACTIVE=$((ACTIVE + 1))
            fi
        done
    fi

    if [ "$TOTAL" -gt 0 ]; then
        printf "  Agents       ${GREEN}✓${NC} $TOTAL registered\n"
    else
        printf "  Agents       ${YELLOW}⚠${NC} None registered\n"
    fi

    if [ "$ACTIVE" -gt 0 ]; then
        printf "  Online Now   ${GREEN}✓${NC} $ACTIVE active\n"
    else
        printf "  Online Now   ${YELLOW}⚠${NC} None active\n"
    fi
else
    printf "  Agents       ${RED}✗${NC} Database missing\n"
fi

# Database permissions check (critical for SQLite WAL mode)
if [ -f /data/metrics.db ]; then
    # Check if /data directory has correct group ownership and permissions
    DATA_GROUP=$(stat -c '%G' /data 2>/dev/null)
    DATA_PERMS=$(stat -c '%a' /data 2>/dev/null)

    if [ "$DATA_GROUP" = "agents" ] && [ "$DATA_PERMS" = "775" ]; then
        printf "  DB Perms     ${GREEN}✓${NC} Configured\n"
    else
        printf "  DB Perms     ${RED}✗${NC} Incorrect (need root:agents 775, got ${DATA_GROUP} ${DATA_PERMS})\n"
        printf "               Fix: chown root:agents /data && chmod 775 /data\n"
    fi
fi

# Check gateway log for recent errors
if [ -f /data/gateway.log ]; then
    RECENT_ERRORS=$(tail -100 /data/gateway.log 2>/dev/null | grep -c "ERROR\|EXCEPTION" || echo 0)
    if [ "$RECENT_ERRORS" -gt 0 ]; then
        # Get the most recent unique error
        LAST_ERROR=$(tail -100 /data/gateway.log 2>/dev/null | grep "ERROR\|EXCEPTION" | tail -1 | sed 's/.*\] //')
        printf "  Gateway Log  ${RED}✗${NC} $RECENT_ERRORS recent errors\n"
        printf "               Latest: ${LAST_ERROR}\n"
        printf "               Check: docker exec lumenmon-console tail /data/gateway.log\n"
    else
        printf "  Gateway Log  ${GREEN}✓${NC} No errors\n"
    fi
fi
