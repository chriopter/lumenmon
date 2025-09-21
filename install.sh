#!/bin/bash
# Lumenmon Installer
set -e

REPO="https://github.com/chriopter/lumenmon.git"
DEFAULT_DIR="$HOME/.lumenmon"

# Output helpers
log() { echo "$1"; }
err() {
    echo "Error: $1" >&2
    echo "Press Enter to exit..." >&2
    read -r < /dev/tty 2>/dev/null || sleep 2
    exit 1
}

# Title
echo ""
echo -e "\033[1;32mLUMENMON\033[0m"
echo ""

# Check prerequisites (using log since status.sh isn't loaded yet)
log "Checking requirements..."
command -v git >/dev/null 2>&1 && log "✓ Git installed" || err "Git not found - please install git"
command -v docker >/dev/null 2>&1 && log "✓ Docker installed" || err "Docker not found - please install docker"
docker compose version >/dev/null 2>&1 && log "✓ Docker Compose installed" || err "'docker compose' not available - please install Docker Compose v2"

echo ""

# For agent install with invite - skip prompts
if [ -n "$LUMENMON_INVITE" ]; then
    if [ -d "$DEFAULT_DIR/.git" ]; then
        cd "$DEFAULT_DIR" && git pull --quiet
    else
        git clone --quiet "$REPO" "$DEFAULT_DIR"
    fi
else
    # Console install - show prompts
    if [ -d "$DEFAULT_DIR/.git" ]; then
        echo "Press Enter to launch installer at $DEFAULT_DIR..."
        read -r < /dev/tty
        echo ""
        cd "$DEFAULT_DIR" && git pull --quiet
        log "✓ Updated"
    else
        echo "Press Enter to clone to $DEFAULT_DIR and launch installer..."
        read -r < /dev/tty
        echo ""
        log "Cloning repository..."
        git clone --quiet "$REPO" "$DEFAULT_DIR"
        log "✓ Ready to launch"
    fi
fi

# Setup environment
DIR="$DEFAULT_DIR"
export DIR
source "$DIR/installer/status.sh"
cd "$DIR"

# Launch installer
if [ -n "$LUMENMON_INVITE" ]; then
    status_progress "Launching agent installer..."
    IMAGE="ghcr.io/chriopter/lumenmon-agent:latest"
    export IMAGE
    source installer/agent.sh
else
    status_progress "Launching installer menu..."
    source installer/menu.sh
    show_menu
fi