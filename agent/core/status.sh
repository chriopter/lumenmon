#!/bin/sh
# Displays agent health status with color-coded checks for MQTT credentials, connection, and metrics flow.
# Shows certificate status, MQTT connection test, and data sending verification.

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Agent:"

# Container
printf "  Container    ${GREEN}✓${NC} Running\n"

# MQTT credentials
MQTT_DATA_DIR="/data/mqtt"
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
