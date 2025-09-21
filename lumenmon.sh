#!/bin/bash
# Lumenmon CLI

DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR"

# Check if container is running
is_running() { docker ps | grep -q "lumenmon-$1"; }

case "$1" in
    # Default without args - open TUI or show status
    "")
        if is_running console; then
            docker exec -it lumenmon-console python3 /app/tui/main.py
        else
            "$0" status
        fi
        ;;

    status|s)
        echo "Lumenmon Status"
        echo "━━━━━━━━━━━━━━━"
        if is_running console; then
            docker exec lumenmon-console /app/core/status.sh 2>/dev/null
        else
            echo "Console: ✗ Container stopped"
        fi
        if is_running agent; then
            docker exec lumenmon-agent /app/core/status.sh 2>/dev/null
        else
            echo "Agent: ✗ Container stopped"
        fi
        ;;

    logs|l)
        docker logs -f lumenmon-console 2>&1 | sed 's/^/[console] /' &
        docker logs -f lumenmon-agent 2>&1 | sed 's/^/[agent] /' &
        wait
        ;;

    invite|i)
        docker exec lumenmon-console /app/core/enrollment/invite_create.sh
        ;;

    update|u)
        git pull && echo "✓ Updated"
        ;;

    uninstall)
        source installer/uninstall.sh
        ;;

    help|h)
        echo "lumenmon           - Open TUI (or status if not running)"
        echo "lumenmon status    - Show system status"
        echo "lumenmon logs     - View logs"
        echo "lumenmon invite   - Generate agent invite"
        echo "lumenmon update   - Update from git"
        echo "lumenmon uninstall - Remove everything"
        ;;

    *)
        echo "Unknown: $1 (try 'lumenmon help')"
        ;;
esac