#!/bin/bash
# Agent installer with invite

source installer/deploy.sh

echo ""
echo "Found invite: $LUMENMON_INVITE"

# Parse host and port from invite
INVITE_HOST_PORT="${LUMENMON_INVITE#*@}"
INVITE_HOST_PORT="${INVITE_HOST_PORT%%/*}"

echo "Console host: $INVITE_HOST_PORT"
echo ""
read -p "Continue with agent installation? [Y/n]: " -n 1 -r
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