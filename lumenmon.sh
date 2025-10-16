#!/bin/bash
# Main CLI command that provides shortcuts for common operations (status, logs, invite, update).
# Detects container state and runs appropriate commands. Supports single-letter aliases (s, l, i, u, h).
DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR"

# Check if container is running
is_running() { docker ps | grep -q "lumenmon-$1"; }

case "$1" in
    # Default: open WebTUI or show status
    "")
        if is_running console; then
            echo "Opening WebTUI at http://localhost:8080"
            if command -v xdg-open > /dev/null; then
                xdg-open http://localhost:8080
            elif command -v open > /dev/null; then
                open http://localhost:8080
            else
                echo "Web interface available at: http://localhost:8080"
            fi
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

        # Update console if installed
        if [ -d "$DIR/console/data" ]; then
            cd "$DIR/console"

            # Determine update method
            if [ -f docker-compose.override.yml ]; then
                IMAGE=$(grep "image:" docker-compose.override.yml | awk '{print $2}')
                echo "Console: Using remote image"
                echo "  Image: $IMAGE"
                echo "  → Pulling from registry..."
                docker compose pull
            else
                echo "Console: Building locally from source"
                echo "  → Building new image..."
                docker compose build
            fi
            echo "  ✓ Console updated"
            echo ""
        fi

        # Update agent if installed
        if [ -d "$DIR/agent/data" ]; then
            cd "$DIR/agent"

            # Determine update method
            if [ -f docker-compose.override.yml ]; then
                IMAGE=$(grep "image:" docker-compose.override.yml | awk '{print $2}')
                echo "Agent: Using remote image"
                echo "  Image: $IMAGE"
                echo "  → Pulling from registry..."
                docker compose pull
            else
                echo "Agent: Building locally from source"
                echo "  → Building new image..."
                docker compose build
            fi
            echo "  ✓ Agent updated"
            echo ""
        fi

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✓ Update complete"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Start updated containers
        "$0" start
        ;;

    start)
        echo "Starting Lumenmon..."
        # Start console if installed (has data directory)
        if [ -d "$DIR/console/data" ]; then
            cd "$DIR/console"
            if ! is_running console; then
                echo "→ Starting console..."
                docker compose up -d
                echo "  ✓ Console started"
            else
                echo "  Console already running"
            fi
        fi
        # Start agent if installed (has data directory)
        if [ -d "$DIR/agent/data" ]; then
            cd "$DIR/agent"
            if ! is_running agent; then
                echo "→ Starting agent..."
                docker compose up -d
                echo "  ✓ Agent started"
            else
                echo "  Agent already running"
            fi
        fi
        ;;

    uninstall)
        source installer/uninstall.sh
        ;;

    help|h)
        echo "lumenmon           - Open WebTUI (or status if not running)"
        echo "lumenmon start     - Start console and/or agent"
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