#!/bin/bash
# Agent installer with invite

source installer/logo.sh
source installer/status.sh

clear
show_logo
echo -e "  \033[1mAgent Installation\033[0m"
echo ""

# Parse invite URL: ssh://reg_123:pass@host:port/#key
status_progress "Parsing invite URL..."
URL="$LUMENMON_INVITE"
HOST_PORT="${URL#*@}"
HOST_PORT="${HOST_PORT%%/#*}"
HOST="${HOST_PORT%%:*}"
PORT="${HOST_PORT##*:}"
USER="${URL#ssh://}"
USER="${USER%%:*}"
status_ok "Found invite for $USER@$HOST:$PORT"

# Test connection
status_progress "Testing console connection..."
if timeout 2 bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
    status_ok "Console reachable at $HOST:$PORT"
else
    status_warn "Cannot verify console at $HOST:$PORT"
fi

echo ""
status_prompt "Install agent and connect? [Y/n]: "
read -r -n 1 REPLY
echo ""

[[ $REPLY =~ ^[Nn]$ ]] && exit 0

echo ""
status_progress "Configuring agent..."
cd "$DIR/agent"
echo "CONSOLE_HOST=$HOST" > .env
echo "CONSOLE_PORT=$PORT" >> .env
status_ok "Configuration saved"

status_progress "Starting container..."
docker compose down 2>/dev/null
if [ -n "$IMAGE" ]; then
    LUMENMON_IMAGE="$IMAGE" docker compose up -d
else
    docker compose up -d --build
fi
status_ok "Container started"

status_progress "Registering with console..."
docker exec lumenmon-agent /app/core/setup/register.sh "$URL" || die "Registration failed"
status_ok "Registration successful"

status_progress "Verifying connection..."
sleep 3

if docker ps | grep -q lumenmon-agent; then
    status_ok "Agent connected and sending metrics"
    echo ""
    echo -e "  \033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "  \033[1;32m✓ Agent successfully installed!\033[0m"
    echo -e "  \033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
else
    status_error "Agent not running - check: docker logs lumenmon-agent"
fi

echo ""