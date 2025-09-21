#!/bin/bash
# Agent installer with invite

source installer/deploy.sh

# Parse host and port from invite
INVITE_HOST_PORT="${LUMENMON_INVITE#*@}"
INVITE_HOST_PORT="${INVITE_HOST_PORT%%/#*}"

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
echo "  Console: $INVITE_HOST_PORT"
echo ""
echo -n "  Continue? [Y/n]: "
read -n 1 -r REPLY < /dev/tty 2>/dev/null || read -n 1 -r REPLY
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "  Installation cancelled"
    exit 0
fi

echo ""
echo "  Installing agent..."

# Install agent
COMPONENT="agent"
IMAGE=""
deploy_component > /dev/null 2>&1

echo -e "  \033[1;32m✓\033[0m Agent installed"
echo ""
echo "  Registering with console..."

# Register with invite (suppress verbose output)
if docker exec lumenmon-agent /app/core/setup/register.sh "$LUMENMON_INVITE" > /dev/null 2>&1; then
    echo -e "  \033[1;32m✓\033[0m Registered successfully"
    echo ""
    echo "  Testing connection..."

    # Wait a moment for connection
    sleep 2

    # Check if agent is sending data (simple check if container is running)
    if docker ps | grep -q lumenmon-agent; then
        echo -e "  \033[1;32m✓\033[0m Agent connected and sending metrics"
        echo ""
        echo -e "  \033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "  \033[1;32m✓ Agent successfully installed and connected!\033[0m"
        echo -e "  \033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    else
        echo -e "  \033[1;33m⚠\033[0m Agent installed but not sending data yet"
    fi
else
    echo -e "  \033[1;31m✗\033[0m Registration failed"
    echo "  Check invite validity and console accessibility"
    exit 1
fi

echo ""