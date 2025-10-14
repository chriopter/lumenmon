#!/bin/bash
# Main CLI command that provides shortcuts for common operations (status, logs, invite, update).
# Detects container state and runs appropriate commands. Supports single-letter aliases (s, l, i, u, h).
DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR"

# Check if container is running
is_running() { docker ps | grep -q "lumenmon-$1"; }

case "$1" in
    # Default: open TUI or show status
    "")
        if is_running console; then
            docker exec -it lumenmon-console /app/tui.sh
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
        docker logs -f lumenmon-console 2>&1 &
        docker logs -f lumenmon-agent 2>&1 &
        wait
        ;;

    invite|i)
        docker exec lumenmon-console /app/core/enrollment/invite_create.sh
        ;;

    register|r)
        if [ -z "$2" ]; then
            echo "Usage: lumenmon register <invite-url>"
            echo "Get an invite with: lumenmon invite"
        else
            if is_running agent; then
                docker exec lumenmon-agent /app/core/setup/register.sh "$2"
            else
                echo "Agent not running. Install agent first."
            fi
        fi
        ;;

    # Update: respects installation method via docker-compose.override.yml
    update|u)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Updating Lumenmon"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Pull latest code
        echo "→ Pulling latest code from git..."
        git pull
        echo ""

        # Update console if running
        if is_running console; then
            cd "$DIR/console"

            # Determine update method
            if [ -f docker-compose.override.yml ]; then
                IMAGE=$(grep "image:" docker-compose.override.yml | awk '{print $2}')
                echo "Console: Using remote image"
                echo "  Image: $IMAGE"
                echo "  → Pulling from registry..."
                docker compose pull
                echo "  → Restarting container..."
                docker compose down && docker compose up -d
            else
                echo "Console: Building locally from source"
                echo "  → Building new image..."
                docker compose build
                echo "  → Restarting container..."
                docker compose down && docker compose up -d
            fi
            echo "  ✓ Console updated"
            echo ""
        fi

        # Update agent if running
        if is_running agent; then
            cd "$DIR/agent"

            # Determine update method
            if [ -f docker-compose.override.yml ]; then
                IMAGE=$(grep "image:" docker-compose.override.yml | awk '{print $2}')
                echo "Agent: Using remote image"
                echo "  Image: $IMAGE"
                echo "  → Pulling from registry..."
                docker compose pull
                echo "  → Restarting container..."
                docker compose down && docker compose up -d
            else
                echo "Agent: Building locally from source"
                echo "  → Building new image..."
                docker compose build
                echo "  → Restarting container..."
                docker compose down && docker compose up -d
            fi
            echo "  ✓ Agent updated"
            echo ""
        fi

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✓ Update complete"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;

    uninstall)
        source installer/uninstall.sh
        ;;

    help|h)
        echo "lumenmon           - Open TUI (or status if not running)"
        echo "lumenmon status    - Show system status"
        echo "lumenmon logs     - View logs"
        echo "lumenmon invite   - Generate agent invite"
        echo "lumenmon register - Register agent with invite"
        echo "lumenmon update   - Pull latest containers and restart"
        echo "lumenmon uninstall - Remove everything"
        ;;

    *)
        echo "Unknown: $1 (try 'lumenmon help')"
        ;;
esac