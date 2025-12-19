#!/bin/bash
# Displays agent health status with color-coded checks.
# Shows MQTT credentials, certificate, connection test, and collectors.

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LUMENMON_HOME="${LUMENMON_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LUMENMON_DATA="${LUMENMON_DATA:-$LUMENMON_HOME/data}"
MQTT_DATA_DIR="$LUMENMON_DATA/mqtt"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "Agent:"
if [ -f "$MQTT_DATA_DIR/username" ] && [ -f "$MQTT_DATA_DIR/password" ] && [ -f "$MQTT_DATA_DIR/host" ]; then
    AGENT_ID=$(cat "$MQTT_DATA_DIR/username")
    MQTT_HOST=$(cat "$MQTT_DATA_DIR/host")
    printf "  Agent ID     ${GREEN}✓${NC} $AGENT_ID\n"
    printf "  MQTT Host    ${GREEN}✓${NC} $MQTT_HOST:8884\n"
else
    printf "  Credentials  ${RED}✗${NC} Not registered\n"
    exit 1
fi

# Server certificate
if [ -f "$MQTT_DATA_DIR/server.crt" ]; then
    printf "  Server Cert  ${GREEN}✓${NC} Saved (pinned)\n"
else
    printf "  Server Cert  ${RED}✗${NC} Missing\n"
fi

# Certificate fingerprint verification
if [ -f "$MQTT_DATA_DIR/fingerprint" ]; then
    EXPECTED_FP=$(cat "$MQTT_DATA_DIR/fingerprint")
    ACTUAL_FP=$(echo | openssl s_client -connect "$MQTT_HOST:8884" -servername "$MQTT_HOST" 2>/dev/null | \
        openssl x509 -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2 || echo "")

    if [ -n "$ACTUAL_FP" ]; then
        if [ "$ACTUAL_FP" = "$EXPECTED_FP" ]; then
            printf "  Fingerprint  ${GREEN}✓${NC} Match\n"
        else
            printf "  Fingerprint  ${RED}✗${NC} Mismatch\n"
        fi
    else
        printf "  Fingerprint  ${RED}✗${NC} Cannot connect\n"
    fi
fi

# MQTT connection test
MQTT_USERNAME=$(cat "$MQTT_DATA_DIR/username")
MQTT_PASSWORD=$(cat "$MQTT_DATA_DIR/password")

printf "  Connection   "
if mosquitto_pub \
    -h "$MQTT_HOST" -p 8884 \
    -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
    --cafile "$MQTT_DATA_DIR/server.crt" \
    -t "metrics/${MQTT_USERNAME}/status_test" \
    -m '{"value":1,"type":"INTEGER","interval":0}' \
    2>/dev/null; then
    printf "${GREEN}✓${NC} Connected\n"
else
    printf "${RED}✗${NC} Failed\n"
fi

# Check if collectors are running
COLLECTORS=$(pgrep -f "collectors/" 2>/dev/null | wc -l)
if [ "$COLLECTORS" -gt 0 ]; then
    printf "  Collectors   ${GREEN}✓${NC} $COLLECTORS running\n"
else
    printf "  Collectors   ${YELLOW}⚠${NC} None running\n"
fi

# Collector snapshot - runs each collector once in test mode
echo ""
echo "Collectors:"

export LUMENMON_TEST_MODE=1
export LUMENMON_HOME LUMENMON_DATA
export PULSE=1 BREATHE=60 CYCLE=300 REPORT=3600

# Override run_collector to run once (test mode exits after first publish)
run_collector() {
    local name="$1"
    local script="$2"
    timeout 5s "$script" 2>/dev/null || true
}

# Source collector init files (same as agent.sh)
for init in "$LUMENMON_HOME/collectors"/*/_init.sh; do
    [ -f "$init" ] && source "$init"
done
