#!/bin/bash
# Finish console setup

echo ""
echo -e "\033[0;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[0;32m✓ Console installed successfully!\033[0m"
echo -e "\033[0;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""

# Generate invite (suppress debug output)
INVITE=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh 2>&1 | grep "ssh://" | head -1)

if [ -n "$INVITE" ]; then
    echo -e "\033[1;36m📋 Your first agent invite URL:\033[0m"
    echo ""
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;33m$INVITE\033[0m"
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo -e "\033[0;90mThis invite expires in 5 minutes. Use it to register your first agent.\033[0m"
    echo ""
fi

echo -e "\033[1m🚀 Quick Start:\033[0m"
echo ""
echo -e "  \033[0;36m• View dashboard:\033[0m  docker exec -it lumenmon-console python3 /app/tui/main.py"
echo -e "  \033[0;36m• Create invite:\033[0m   docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
echo -e "  \033[0;36m• Check status:\033[0m    docker ps | grep lumenmon"
echo ""
echo -e "\033[0;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""