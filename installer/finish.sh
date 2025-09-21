#!/bin/bash
# Finish console setup

sleep 3

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Console installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Try to generate invite
echo "Generating first invite..."
INVITE_OUTPUT=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh 2>&1)

if [ $? -eq 0 ]; then
    INVITE=$(echo "$INVITE_OUTPUT" | grep -o 'lumenmon://[^[:space:]]*')
    if [ -n "$INVITE" ]; then
        echo ""
        echo "First invite (expires in 5 minutes):"
        echo ""
        echo -e "  \033[0;33m$INVITE\033[0m"  # Yellow
        echo ""
    fi
else
    echo "Invite generation pending (console still starting)"
fi

echo ""
echo "Commands:"
echo "  View dashboard: docker exec -it lumenmon-console python3 /app/tui/main.py"
echo "  Create invite:  docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
echo ""