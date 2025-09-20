#!/bin/bash
# Lumenmon Development Helper
set -e

# Get the directory of this script
DEV_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$DEV_DIR/lib"

# Source the appropriate library script based on command
case "${1:-}" in
    clean)    source "$LIB_DIR/clean.sh" ;;
    console)  source "$LIB_DIR/console.sh" ;;
    agent)    source "$LIB_DIR/agent.sh" ;;
    rebuild)  source "$LIB_DIR/rebuild.sh" ;;
    tui)      source "$LIB_DIR/tui.sh" ;;
    stop)     source "$LIB_DIR/stop.sh" ;;
    logs)     source "$LIB_DIR/logs.sh" "${2:-console}" ;;
    ssh-debug) source "$LIB_DIR/ssh-debug.sh" ;;
    ssh-test) source "$LIB_DIR/ssh-test.sh" ;;
    test-register) source "$LIB_DIR/test-register.sh" "$2" ;;
    keys) source "$LIB_DIR/keys.sh" ;;
    *)
        echo "Usage: ./dev.sh [command]"
        echo ""
        echo "Commands:"
        echo "  clean         - Clean data directories"
        echo "  console       - Start console container"
        echo "  agent         - Start agent container"
        echo "  rebuild       - Stop, clean, and restart everything"
        echo "  tui           - Open TUI (use to register agents)"
        echo "  stop          - Stop all containers"
        echo "  logs [console|agent] - Show logs"
        echo "  ssh-debug     - Debug SSH connection for agents"
        echo "  ssh-test      - Test SSH daemon and config"
        echo "  test-register - Test agent registration with invite URL"
        echo "  keys          - Check SSH keys exist"
        ;;
esac