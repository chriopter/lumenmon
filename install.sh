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

# Check prerequisites
log "Checking requirements..."
command -v git >/dev/null 2>&1 && log "✓ Git installed" || err "Git not found - please install git"
command -v docker >/dev/null 2>&1 && log "✓ Docker installed" || err "Docker not found - please install docker"
docker compose version >/dev/null 2>&1 && log "✓ Docker Compose installed" || err "'docker compose' not available - please install Docker Compose v2"

echo ""

# Install or update
if [ -d "$DEFAULT_DIR/.git" ]; then
    echo "Press Enter to update existing installation at $DEFAULT_DIR..."
    read -r < /dev/tty
    echo ""
    cd "$DEFAULT_DIR" && git pull --quiet
    log "✓ Updated"
else
    echo "Press Enter to install to $DEFAULT_DIR..."
    read -r < /dev/tty
    echo ""
    log "Installing..."
    git clone --quiet "$REPO" "$DEFAULT_DIR"
    log "✓ Installed"
fi

# Setup environment
DIR="$DEFAULT_DIR"
export DIR
source "$DIR/installer/status.sh"
cd "$DIR"

# Launch appropriate installer
if [ -n "$LUMENMON_INVITE" ]; then
    status_progress "Starting agent installer..."
    source installer/agent.sh
else
    status_progress "Starting console installer..."
    source installer/menu.sh
    show_menu
fi