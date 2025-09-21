#!/bin/bash
# Finish console setup

# Generate invite (suppress debug output)
INVITE=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh 2>&1 | grep "ssh://" | head -1)

echo ""
echo -e "\033[1;32m✓ Console installed successfully\033[0m"

if [ -n "$INVITE" ]; then
    echo ""
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;33mFirst invite (expires in 5 minutes):\033[0m"
    echo ""
    echo -e "\033[1;33m$INVITE\033[0m"
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
fi

echo ""
echo "Next steps:"
echo "• View dashboard: docker exec -it lumenmon-console python3 /app/tui/main.py"
echo "• Create invite: docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
echo ""