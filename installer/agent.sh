#!/bin/bash
# Agent installer with invite

source installer/logo.sh
source installer/status.sh

# Parse invite URL components
parse_invite() {
    local url="$1"
    # ssh://reg_123:pass@host:port/#key
    HOST_PORT="${url#*@}"
    HOST_PORT="${HOST_PORT%%/#*}"
    HOST="${HOST_PORT%%:*}"
    PORT="${HOST_PORT##*:}"
    USER="${url#ssh://}"
    USER="${USER%%:*}"
}

# Main installation
clear
show_logo
echo -e "  \033[1mAgent Installation\033[0m"
echo ""

status_progress "Parsing invite URL..."
parse_invite "$LUMENMON_INVITE"
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

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    status_warn "Installation cancelled"
    exit 0
fi

echo ""
status_progress "Preparing configuration..."
echo "CONSOLE_HOST=$HOST" > "$DIR/agent/.env"
echo "CONSOLE_PORT=$PORT" >> "$DIR/agent/.env"
status_ok "Configuration saved"

status_progress "Installing agent container..."
cd "$DIR/agent"

# Stop existing container
docker compose down 2>/dev/null

# Deploy container
if [ -n "$IMAGE" ]; then
    export LUMENMON_IMAGE="$IMAGE"
    docker compose up -d
else
    docker compose up -d --build
fi
status_ok "Container started"

status_progress "Registering with console..."
if docker exec lumenmon-agent /app/core/setup/register.sh "$LUMENMON_INVITE"; then
    status_ok "Registration successful"
else
    die "Registration failed - check invite URL"
fi

status_progress "Verifying metrics transmission..."
sleep 3

if docker ps | grep -q lumenmon-agent; then
    status_ok "Agent connected and sending metrics"
    echo ""
    echo -e "  \033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "  \033[1;32m✓ Agent successfully installed!\033[0m"
    echo -e "  \033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
else
    status_error "Agent not running"
    echo "  Debug with: docker logs lumenmon-agent"
fi

echo ""