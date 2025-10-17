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

    # Update: downloads latest compose files and pulls new images
    update|u)
        GITHUB_RAW="https://raw.githubusercontent.com/chriopter/lumenmon/main"

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Updating Lumenmon"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Update console if installed
        if [ -d "$DIR/console/data" ]; then
            echo "Console:"

            # Download latest compose file
            echo "  → Downloading latest docker-compose.yml..."
            TEMP_COMPOSE=$(mktemp)
            if curl -fsSL "$GITHUB_RAW/console/docker-compose.yml" -o "$TEMP_COMPOSE" 2>/dev/null; then
                # Check if changed
                if ! diff -q "$DIR/console/docker-compose.yml" "$TEMP_COMPOSE" >/dev/null 2>&1; then
                    echo "  ⚠ Compose file changed"
                    cp "$DIR/console/docker-compose.yml" "$DIR/console/docker-compose.yml.backup"
                    cp "$TEMP_COMPOSE" "$DIR/console/docker-compose.yml"
                    echo "  ✓ Compose updated (backup saved)"
                else
                    echo "  ✓ Compose up to date"
                fi
            fi
            rm -f "$TEMP_COMPOSE"

            # Pull latest image
            cd "$DIR/console"
            echo "  → Pulling latest image..."
            docker compose pull
            echo "  ✓ Console updated"
            echo ""
        fi

        # Update agent if installed
        if [ -d "$DIR/agent/data" ]; then
            echo "Agent:"

            # Download latest compose file
            echo "  → Downloading latest docker-compose.yml..."
            TEMP_COMPOSE=$(mktemp)
            if curl -fsSL "$GITHUB_RAW/agent/docker-compose.yml" -o "$TEMP_COMPOSE" 2>/dev/null; then
                # Check if changed
                if ! diff -q "$DIR/agent/docker-compose.yml" "$TEMP_COMPOSE" >/dev/null 2>&1; then
                    echo "  ⚠ Compose file changed"
                    cp "$DIR/agent/docker-compose.yml" "$DIR/agent/docker-compose.yml.backup"
                    cp "$TEMP_COMPOSE" "$DIR/agent/docker-compose.yml"
                    echo "  ✓ Compose updated (backup saved)"
                else
                    echo "  ✓ Compose up to date"
                fi
            fi
            rm -f "$TEMP_COMPOSE"

            # Pull latest image
            cd "$DIR/agent"
            echo "  → Pulling latest image..."
            docker compose pull
            echo "  ✓ Agent updated"
            echo ""
        fi

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✓ Update complete"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Restart updated containers
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
        echo ""
        read -r -p "Uninstall Lumenmon? [y/N]: " -n 1 CONFIRM
        echo ""

        [[ ! $CONFIRM =~ ^[Yy]$ ]] && exit 0

        echo ""

        # Stop containers
        if [ -d "$DIR/console" ]; then
            cd "$DIR/console"
            docker compose down -v 2>/dev/null && echo "[✓] Console stopped"
        fi

        if [ -d "$DIR/agent" ]; then
            cd "$DIR/agent"
            docker compose down -v 2>/dev/null && echo "[✓] Agent stopped"
        fi

        # Remove network
        docker network rm lumenmon-net 2>/dev/null && echo "[✓] Network removed"

        # Remove CLI symlinks
        [ -L /usr/local/bin/lumenmon ] && rm /usr/local/bin/lumenmon 2>/dev/null && echo "[✓] CLI removed"
        [ -L ~/.local/bin/lumenmon ] && rm ~/.local/bin/lumenmon 2>/dev/null && echo "[✓] CLI removed"

        # Remove installation directory
        cd "$HOME"
        if rm -rf "$DIR" 2>/dev/null; then
            echo "[✓] $DIR removed"
        else
            echo "[✗] Failed to remove $DIR (try: sudo rm -rf $DIR)"
        fi

        echo ""
        echo "✓ Uninstall complete"
        echo ""
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