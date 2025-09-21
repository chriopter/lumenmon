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

# Save image choice for future updates
# This tells 'lumenmon update' how to update this installation
if [ -n "$IMAGE" ]; then
    # Remote image - save it so updates know to pull from registry
    echo "LUMENMON_IMAGE=$IMAGE" >> .env
else
    # Local build - save empty value so updates know to build from source
    echo "LUMENMON_IMAGE=" >> .env
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

# Setup CLI command
source "$DIR/installer/cli.sh"

echo ""
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;32m✓ LUMENMON Console installed!\033[0m"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
echo "Next steps:"
echo ""
echo "1. Install agent on your first server (expires in 5 minutes):"

if [ -n "$FULL_CMD" ]; then
    echo ""
    echo -e "   \033[1;36m$FULL_CMD\033[0m"
else
    echo "   docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
    echo "   Then use the command it generates on your server"
fi

echo ""
echo "2. View console dashboard:"
echo "   lumenmon"

echo ""
