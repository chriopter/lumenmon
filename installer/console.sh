#!/bin/bash
# Installs console container and generates first agent invite for easy enrollment.
# Deploys Docker container, creates invite URL, and sets up lumenmon CLI command.
source installer/status.sh

echo ""
status_progress "Installing console..."

cd "$DIR/console"

# Pre-create data directories with secure permissions
mkdir -p data/ssh data/agents
chmod -R 755 data

# Save configuration
if [ -n "$CONSOLE_HOST" ]; then
    echo "CONSOLE_HOST=$CONSOLE_HOST" > .env
    status_ok "Configuration saved"
fi

# Create override file for remote images
if [ -n "$IMAGE" ]; then
    # Remote image - create override to disable build
    cat > docker-compose.override.yml <<EOF
services:
  console:
    image: $IMAGE
EOF
    status_ok "Remote image configured"
else
    # Local build - remove any override file
    rm -f docker-compose.override.yml
fi

# Deploy container
status_progress "Restarting container..."
docker compose down 2>/dev/null
docker compose up -d --build
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
echo -e "\033[1mNext steps:\033[0m"
echo ""

if [ -n "$FULL_CMD" ]; then
    echo -e "1. Install agent on server \033[2m(expires in 5 minutes)\033[0m:"
    echo ""
    echo -e "   \033[1;36m$FULL_CMD\033[0m"
    echo ""
    echo "2. Open dashboard at \033[1;36mhttp://localhost:8080\033[0m"
    echo ""
    echo -e "   \033[1;36mlumenmon\033[0m"
else
    echo "1. Generate invite for agent:"
    echo -e "   \033[1;36mdocker exec lumenmon-console /app/core/enrollment/invite_create.sh\033[0m"
    echo ""
    echo "2. Open dashboard at \033[1;36mhttp://localhost:8080\033[0m"
    echo ""
    echo -e "   \033[1;36mlumenmon\033[0m"
fi

echo ""
