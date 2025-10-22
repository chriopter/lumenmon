#!/bin/bash
# Main CLI command that provides shortcuts for common operations (status, logs, invite, update).
# Detects container state and runs appropriate commands. Supports single-letter aliases (s, l, i, u, h).
DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR"

# Check if container is running
is_running() { docker ps | grep -q "lumenmon-$1"; }

case "$1" in
    # Default: show status and CLI commands
    "")
        echo "Lumenmon Status"
        echo "━━━━━━━━━━━━━━━"
        is_running console && docker exec lumenmon-console /app/core/status.sh 2>/dev/null || echo "Console: ✗ Container stopped"
        is_running agent && docker exec lumenmon-agent /app/core/status.sh 2>/dev/null || echo "Agent: ✗ Container stopped"
        echo ""
        echo "CLI commands:"
        echo "  lumenmon start     # Start containers"
        echo "  lumenmon logs      # Stream container logs"
        echo "  lumenmon invite    # Generate new invite"
        echo "  lumenmon register  # Register agent with invite"
        echo "  lumenmon update    # Update to latest version"
        echo "  lumenmon uninstall # Remove Lumenmon"
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
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Agent Invite (expires in 60 minutes)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        INVITE_URL=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh 2>/dev/null)
        echo "Invite URL:"
        echo "$INVITE_URL"
        echo ""
        echo "One-line install:"
        docker exec lumenmon-console /app/core/enrollment/invite_create.sh --full 2>/dev/null
        echo ""
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
        GITHUB_RAW="https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main"

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Updating Lumenmon"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Update CLI script itself
        echo "CLI:"
        echo "  → Downloading latest lumenmon CLI..."
        TEMP_CLI=$(mktemp)
        if curl -fsSL "$GITHUB_RAW/lumenmon.sh" -o "$TEMP_CLI" 2>/dev/null; then
            if ! diff -q "$DIR/lumenmon" "$TEMP_CLI" >/dev/null 2>&1; then
                cp "$DIR/lumenmon" "$DIR/lumenmon.backup"
                cp "$TEMP_CLI" "$DIR/lumenmon"
                chmod +x "$DIR/lumenmon"
                echo "  ✓ CLI updated (backup saved)"
            else
                echo "  ✓ CLI up to date"
            fi
        fi
        rm -f "$TEMP_CLI"
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

        # Restart containers to apply new configuration
        echo "Restarting containers..."
        if [ -d "$DIR/console/data" ]; then
            echo "  → Restarting console..."
            cd "$DIR/console"
            docker compose up -d --force-recreate
            echo "  ✓ Console restarted"
        fi
        if [ -d "$DIR/agent/data" ]; then
            echo "  → Restarting agent..."
            cd "$DIR/agent"
            docker compose up -d --force-recreate
            echo "  ✓ Agent restarted"
        fi
        echo ""
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
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠  WARNING: Complete Uninstall"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "This will remove:"
        echo "  • All containers (console and agent)"
        echo "  • All data (metrics database, MQTT credentials, configs)"
        echo "  • All network configurations"
        echo "  • CLI installation"
        echo ""
        echo "ALL DATA WILL BE PERMANENTLY LOST!"
        echo ""
        read -r -p "Continue with uninstall? [y/N]: " -n 1 CONFIRM
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