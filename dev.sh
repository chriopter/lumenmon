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

    *)
        echo "Usage: ./dev.sh [command]"
        echo ""
        echo "Commands:"
        echo "  clean    - Clean data directories"
        echo "  console  - Start console container"
        echo "  agent    - Start agent container"
        echo "  tui      - Open TUI"
        echo "  stop     - Stop all containers"
        echo "  logs [console|agent] - Show logs"
        ;;
esac