#!/bin/bash
# Agent installer with invite

source installer/deploy.sh

echo ""
echo "Found invite: $LUMENMON_INVITE"

# Parse host and port from invite
INVITE_HOST_PORT="${LUMENMON_INVITE#*@}"
INVITE_HOST_PORT="${INVITE_HOST_PORT%%/#*}"

echo "Console host: $INVITE_HOST_PORT"
echo ""
echo -n "Continue with agent installation? [Y/n]: "
read -n 1 -r REPLY < /dev/tty 2>/dev/null || read -n 1 -r REPLY
echo ""

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # Install agent
    COMPONENT="agent"
    IMAGE=""
    deploy_component

    # Register with invite
    echo ""
    echo "Registering agent..."
    docker exec lumenmon-agent /app/core/setup/register.sh "$LUMENMON_INVITE"
else
    echo "Installation cancelled"
    exit 0
fi