#!/bin/bash
# Agent installer

source installer/logo.sh
source installer/status.sh

clear
show_logo
echo -e "  \033[1mAgent Installation\033[0m"
echo ""

# Check for invite
if [ -n "$LUMENMON_INVITE" ]; then
    URL="$LUMENMON_INVITE"
    HOST="${URL#*@}"; HOST="${HOST%%:*}"
    PORT="${URL##*:}"; PORT="${PORT%%/*}"
    status_ok "Found invite for $HOST:$PORT"
else
    status_warn "Manual setup mode"
fi

echo ""
status_prompt "Continue? [Y/n]: "
read -r -n 1 REPLY
echo ""
[[ $REPLY =~ ^[Nn]$ ]] && exit 0

# Install
echo ""
cd "$DIR/agent"

# Write config
echo "CONSOLE_HOST=${HOST:-localhost}" > .env
echo "CONSOLE_PORT=${PORT:-2345}" >> .env

# Start container
status_progress "Starting container..."
docker compose down 2>/dev/null

if [ -n "$IMAGE" ]; then
    LUMENMON_IMAGE="$IMAGE" docker compose up -d
else
    docker compose up -d --build
fi
status_ok "Container started"

# Register if we have invite
if [ -n "$LUMENMON_INVITE" ]; then
    status_progress "Connecting to console..."
    docker exec lumenmon-agent /app/core/setup/register.sh "$URL"
    status_ok "Connected!"
else
    echo ""
    echo "To connect:"
    echo "• docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
    echo "• docker exec lumenmon-agent /app/core/setup/register.sh <invite>"
fi

# Setup CLI command
source "$DIR/installer/cli.sh"

echo ""