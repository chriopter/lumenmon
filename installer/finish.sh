#!/bin/bash
# Finish console setup

sleep 3

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Console installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get invite
INVITE=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh 2>/dev/null | grep -o 'lumenmon://[^[:space:]]*')

if [ -n "$INVITE" ]; then
    echo "First invite:"
    echo ""
    echo "  $INVITE"
    echo ""
fi

echo "View dashboard: docker exec -it lumenmon-console python3 /app/tui/main.py"
echo "Create invite:  docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
echo ""