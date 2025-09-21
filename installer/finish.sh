#!/bin/bash
# Finish console setup

# Wait for container to be ready
echo "Waiting for console to initialize..."
sleep 3

# Generate full install command
FULL_CMD=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh --full 2>/dev/null)

echo ""
echo "• View dashboard: docker exec -it lumenmon-console python3 /app/tui/main.py"
echo "• Create invite: docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
echo ""
echo -e "\033[1;32m✓ Console installed successfully\033[0m"

if [ -n "$FULL_CMD" ]; then
    echo ""
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;33mAgent install command (expires in 5 minutes):\033[0m"
    echo ""
    echo -e "\033[1;36m$FULL_CMD\033[0m"
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
fi

echo ""