#!/bin/bash
# Console installer

source installer/status.sh

echo ""
status_progress "Installing console..."

cd "$DIR/console"

# Save console host
if [ -n "$CONSOLE_HOST" ]; then
    echo "CONSOLE_HOST=$CONSOLE_HOST" > "$DIR/console/.env"
    status_ok "Configuration saved"
fi

# Stop existing container
status_progress "Stopping existing container..."
docker compose down 2>/dev/null
status_ok "Container stopped"

# Deploy container
status_progress "Building and starting console..."
if [ -n "$IMAGE" ]; then
    export LUMENMON_IMAGE="$IMAGE"
    docker compose up -d
else
    docker compose up -d --build
fi
status_ok "Console started"

# Wait for initialization
status_progress "Waiting for console to initialize..."
sleep 3

# Generate invite
status_progress "Generating first invite..."
FULL_CMD=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh --full 2>/dev/null)

if [ -n "$FULL_CMD" ]; then
    status_ok "Invite generated"
else
    status_warn "Could not generate invite automatically"
fi

echo ""
echo "  Commands:"
echo "  • View dashboard: docker exec -it lumenmon-console python3 /app/tui/main.py"
echo "  • Create invite:  docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
echo ""

status_ok "Console ready at ${CONSOLE_HOST:-localhost}:2345"

if [ -n "$FULL_CMD" ]; then
    echo ""
    echo -e "  \033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "  \033[1;33mAgent install command (expires in 5 minutes):\033[0m"
    echo ""
    echo -e "  \033[1;36m$FULL_CMD\033[0m"
    echo -e "  \033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
fi

echo ""