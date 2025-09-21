#!/bin/bash
# Lumenmon CLI

DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR"

# Check if container is running
is_running() { docker ps | grep -q "lumenmon-$1"; }

case "$1" in
    # Default: open TUI or show status
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
        is_running console && docker exec lumenmon-console /app/core/status.sh 2>/dev/null || echo "Console: ✗ Container stopped"
        is_running agent && docker exec lumenmon-agent /app/core/status.sh 2>/dev/null || echo "Agent: ✗ Container stopped"
        ;;

    logs|l)
        docker logs -f lumenmon-console 2>&1 | sed 's/^/[console] /' &
        docker logs -f lumenmon-agent 2>&1 | sed 's/^/[agent] /' &
        wait
        ;;

    invite|i)
        docker exec lumenmon-console /app/core/enrollment/invite_create.sh
        ;;

    # Update: respects installation method (local build vs remote image)
    update|u)
        echo "Updating Lumenmon..."
        git pull

        # Update console if running
        if is_running console; then
            echo "Updating console..."
            cd "$DIR/console"

            # Check if remote image in .env
            if [ -f .env ] && grep -q "^LUMENMON_IMAGE=." .env 2>/dev/null; then
                IMAGE=$(grep "^LUMENMON_IMAGE=" .env | cut -d= -f2)
                echo "Pulling $IMAGE..."
                docker pull "$IMAGE"
                docker compose down && docker compose up -d
            else
                echo "Building from source..."
                docker compose down && docker compose up -d --build
            fi

            echo "✓ Console updated"
        fi

        # Update agent if running
        if is_running agent; then
            echo "Updating agent..."
            cd "$DIR/agent"

            if [ -f .env ] && grep -q "^LUMENMON_IMAGE=." .env 2>/dev/null; then
                IMAGE=$(grep "^LUMENMON_IMAGE=" .env | cut -d= -f2)
                echo "Pulling $IMAGE..."
                docker pull "$IMAGE"
                docker compose down && docker compose up -d
            else
                echo "Building from source..."
                docker compose down && docker compose up -d --build
            fi

            echo "✓ Agent updated"
        fi

        echo "✓ Update complete"
        ;;

    uninstall)
        source installer/uninstall.sh
        ;;

    help|h)
        echo "lumenmon           - Open TUI (or status if not running)"
        echo "lumenmon status    - Show system status"
        echo "lumenmon logs     - View logs"
        echo "lumenmon invite   - Generate agent invite"
        echo "lumenmon update   - Pull latest containers and restart"
        echo "lumenmon uninstall - Remove everything"
        ;;

    *)
        echo "Unknown: $1 (try 'lumenmon help')"
        ;;
esac