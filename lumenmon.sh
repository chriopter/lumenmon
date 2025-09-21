#!/bin/bash
# Lumenmon CLI

DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR"

case "$1" in
    console|tui|dashboard)
        docker exec -it lumenmon-console python3 /app/tui/main.py
        ;;
    logs)
        docker logs -f lumenmon-console
        ;;
    agent-logs)
        docker logs -f lumenmon-agent
        ;;
    invite)
        docker exec lumenmon-console /app/core/enrollment/invite_create.sh
        ;;
    update)
        git pull && echo "✓ Updated"
        ;;
    uninstall)
        source installer/uninstall.sh
        ;;
    help|"")
        echo "Usage: lumenmon {console|logs|agent-logs|invite|update|uninstall}"
        echo ""
        echo "Commands:"
        echo "  console     Open the TUI dashboard"
        echo "  logs        View console container logs"
        echo "  agent-logs  View agent container logs"
        echo "  invite      Generate agent installation invite"
        echo "  update      Update Lumenmon from git"
        echo "  uninstall   Remove Lumenmon completely"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Usage: lumenmon {console|logs|agent-logs|invite|update|uninstall}"
        ;;
esac