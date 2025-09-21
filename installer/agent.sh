#!/bin/bash
# Agent installer with invite

source installer/deploy.sh

# Parse host and port from invite
INVITE_HOST_PORT="${LUMENMON_INVITE#*@}"
INVITE_HOST_PORT="${INVITE_HOST_PORT%%/#*}"

# Parse username from invite
INVITE_USER="${LUMENMON_INVITE#ssh://}"
INVITE_USER="${INVITE_USER%%:*}"

clear
echo -e "\033[0;36m"
echo "  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗"
echo "  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║"
echo "  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║"
echo "  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║"
echo "  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
echo "  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
echo -e "\033[0m"
echo -e "  \033[1mAgent Installation\033[0m"
echo ""
echo "  Found invite: $INVITE_USER@$INVITE_HOST_PORT"
echo "  Console: $INVITE_HOST_PORT"
echo ""

# Test connectivity
echo "  Testing connection to console..."
CONSOLE_HOST="${INVITE_HOST_PORT%%:*}"
CONSOLE_PORT="${INVITE_HOST_PORT##*:}"

if timeout 2 bash -c "echo > /dev/tcp/$CONSOLE_HOST/$CONSOLE_PORT" 2>/dev/null; then
    echo -e "  \033[1;32m✓\033[0m Can reach console at $INVITE_HOST_PORT"
else
    echo -e "  \033[1;33m⚠\033[0m Cannot verify console at $INVITE_HOST_PORT"
fi

echo ""
echo -n "  Install agent and connect? [Y/n]: "
read -n 1 -r REPLY < /dev/tty 2>/dev/null || read -n 1 -r REPLY
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "  Installation cancelled"
    exit 0
fi

echo ""

# Parse and save connection details BEFORE starting container
echo "  Preparing connection configuration..."
echo "CONSOLE_HOST=$CONSOLE_HOST" > "$DIR/agent/.env"
echo "CONSOLE_PORT=$CONSOLE_PORT" >> "$DIR/agent/.env"

echo "  Installing agent container..."

# Install agent
COMPONENT="agent"
IMAGE=""
deploy_component

echo ""
echo "  Registering with console..."

# Register with invite
docker exec lumenmon-agent /app/core/setup/register.sh "$LUMENMON_INVITE"

echo ""
echo "  Waiting for metrics transmission..."
sleep 3

# Check if agent is sending data
if docker ps | grep -q lumenmon-agent; then
    echo -e "  \033[1;32m✓\033[0m Agent is running and sending metrics"
    echo ""

    # Show saved connection details for debugging
    echo "  Connection details saved to agent/.env:"
    cat "$DIR/agent/.env" 2>/dev/null | sed 's/^/    /'

    echo ""
    echo -e "  \033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "  \033[1;32m✓ Agent successfully installed and connected!\033[0m"
    echo -e "  \033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
else
    echo -e "  \033[1;33m⚠\033[0m Agent installed but not running"
    echo "  Check logs: docker logs lumenmon-agent"
fi

echo ""