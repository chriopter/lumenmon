#!/bin/bash
# Finish console setup

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Console installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate invite
INVITE=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh | grep "ssh://")

if [ -n "$INVITE" ]; then
    echo "First invite (expires in 5 minutes):"
    echo ""
    echo -e "  \033[0;33m$INVITE\033[0m"
    echo ""
fi

echo "Commands:"
echo "  View dashboard: docker exec -it lumenmon-console python3 /app/tui/main.py"
echo "  Create invite:  docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
echo ""