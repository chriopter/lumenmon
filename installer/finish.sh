#!/bin/bash
# Finish console setup

echo ""
echo ""
echo -e "  \033[1;32m✨ Success!\033[0m Console is up and running."
echo ""

# Generate invite (suppress debug output)
INVITE=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh 2>&1 | grep "ssh://" | head -1)

if [ -n "$INVITE" ]; then
    echo -e "  \033[1mYour first invite:\033[0m"
    echo ""
    echo -e "  \033[0;33m$INVITE\033[0m"
    echo ""
    echo -e "  \033[0;90mExpires in 5 minutes • Use this to register your first agent\033[0m"
    echo ""
fi

echo -e "  \033[1mNext steps:\033[0m"
echo ""
echo -e "  Open dashboard:  \033[0;36mdocker exec -it lumenmon-console python3 /app/tui/main.py\033[0m"
echo -e "  Create invite:   \033[0;36mdocker exec lumenmon-console /app/core/enrollment/invite_create.sh\033[0m"
echo ""