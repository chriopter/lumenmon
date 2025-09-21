#!/bin/bash
# Finish console setup

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Console installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Wait for container to be ready
echo "Waiting for console to start..."
sleep 5

# Try to generate invite with timeout
echo "Generating first invite..."
INVITE_OUTPUT=$(timeout 5 docker exec lumenmon-console /app/core/enrollment/invite_create.sh 2>&1)

if [ $? -eq 0 ]; then
    INVITE=$(echo "$INVITE_OUTPUT" | grep -o 'lumenmon://[^[:space:]]*' | head -1)
    if [ -n "$INVITE" ]; then
        echo ""
        echo "First invite (expires in 5 minutes):"
        echo ""
        echo -e "  \033[0;33m$INVITE\033[0m"  # Yellow
        echo ""
    fi
else
    echo "Console is starting up. Create invite manually in a moment."
fi

echo ""
echo "Commands:"
echo "  View dashboard: docker exec -it lumenmon-console python3 /app/tui/main.py"
echo "  Create invite:  docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
echo ""