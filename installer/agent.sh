#!/bin/bash
# Installs agent container with optional invite-based auto-registration.
# Configures Docker container, sets console host/port, and connects to console if invite provided.
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
    # Auto-continue with invite
else
    status_warn "Manual setup mode"
    echo ""
    status_prompt "Continue? [Y/n]: "
    read -r -n 1 REPLY < /dev/tty
    echo ""
    [[ $REPLY =~ ^[Nn]$ ]] && exit 0
fi

# Install
echo ""
cd "$DIR/agent"

# Pre-create SSH directory with write permissions for container
mkdir -p data/ssh
chmod 777 data/ssh  # Allow container to write SSH keys

# Write config
echo "CONSOLE_HOST=${HOST:-localhost}" > .env
echo "CONSOLE_PORT=${PORT:-2345}" >> .env

# Create override file for remote images
if [ -n "$IMAGE" ]; then
    # Remote image - create override to disable build
    cat > docker-compose.override.yml <<EOF
services:
  agent:
    image: $IMAGE
EOF
    status_ok "Remote image configured"
else
    # Local build - remove any override file
    rm -f docker-compose.override.yml
fi

# Start container
status_progress "Starting container..."
docker compose down 2>/dev/null
docker compose up -d --build
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