#!/bin/bash
# Console installer

source installer/status.sh

echo ""
status_progress "Installing console..."

cd "$DIR/console"

# Save configuration
if [ -n "$CONSOLE_HOST" ]; then
    echo "CONSOLE_HOST=$CONSOLE_HOST" > .env
    status_ok "Configuration saved"
fi

# Deploy container
status_progress "Restarting container..."
docker compose down 2>/dev/null

if [ -n "$IMAGE" ]; then
    LUMENMON_IMAGE="$IMAGE" docker compose up -d
else
    docker compose up -d --build
fi
status_ok "Console started"

# Initialize and generate invite
status_progress "Initializing console..."
sleep 3

if FULL_CMD=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh --full 2>/dev/null); then
    [ -n "$FULL_CMD" ] && status_ok "Invite generated" || status_warn "Manual invite creation required"
else
    FULL_CMD=""
    status_warn "Manual invite creation required"
fi

# Show usage commands
echo ""
echo "Commands:"
echo "• View dashboard: docker exec -it lumenmon-console python3 /app/tui/main.py"
echo "• Create invite:  docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
echo ""

status_ok "Console ready at ${CONSOLE_HOST:-localhost}:2345"

# Display first invite if generated
if [ -n "$FULL_CMD" ]; then
    echo ""
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;33mAgent install command (expires in 5 minutes):\033[0m"
    echo ""
    echo -e "\033[1;36m$FULL_CMD\033[0m"
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
fi

echo ""
