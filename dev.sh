#!/bin/bash
# Lumenmon Dev Helper - Ultra KISS
set -e

case "${1:-}" in
    clean)
        echo "Cleaning data directories..."
        find agent/data -type f ! -name '.gitkeep' -delete 2>/dev/null || true
        find console/data -type f ! -name '.gitkeep' -delete 2>/dev/null || true
        echo "Done"
        ;;

    console)
        echo "Starting console..."
        cd console && docker compose up -d --build
        ;;

    agent)
        echo "Starting agent..."
        cd agent && CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose up -d --build
        ;;

    tui)
        docker exec -it lumenmon-console python3 /app/tui/tui.py
        ;;

    stop)
        echo "Stopping containers..."
        docker stop lumenmon-console lumenmon-agent 2>/dev/null || true
        ;;

    logs)
        docker logs -f lumenmon-${2:-console}
        ;;

    ssh-test)
        echo "Testing SSH connection..."
        docker exec lumenmon-console sh -c "ps aux | grep sshd"
        echo ""
        echo "SSH config test:"
        docker exec lumenmon-console /usr/sbin/sshd -T | grep -E "^(port|forcecommand|match)" | head -20
        echo ""
        echo "Testing gateway.sh:"
        docker exec lumenmon-console ls -la /app/gateway.sh 2>&1 || echo "gateway.sh not found"
        ;;

    rebuild)
        echo "Rebuilding everything..."
        # Stop containers
        docker stop lumenmon-console lumenmon-agent 2>/dev/null || true
        docker rm lumenmon-console lumenmon-agent 2>/dev/null || true
        # Clean data
        find agent/data -type f ! -name '.gitkeep' -delete 2>/dev/null || true
        find console/data -type f ! -name '.gitkeep' -delete 2>/dev/null || true
        # Start fresh
        cd console && docker compose up -d --build && cd ..
        cd agent && CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose up -d --build && cd ..
        echo "Rebuilt! Use './dev.sh tui' to register agents"
        ;;

    *)
        echo "Usage: ./dev.sh [command]"
        echo ""
        echo "Commands:"
        echo "  clean    - Clean data directories"
        echo "  console  - Start console container"
        echo "  agent    - Start agent container"
        echo "  rebuild  - Stop, clean, and restart everything"
        echo "  tui      - Open TUI (use to register agents)"
        echo "  stop     - Stop all containers"
        echo "  logs [console|agent] - Show logs"
        ;;
esac