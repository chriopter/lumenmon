#!/bin/bash
# Lumenmon Installer
set -e

REPO="https://github.com/chriopter/lumenmon.git"
DEFAULT_DIR="$HOME/.lumenmon"

# Minimal status output before repo is cloned
log() { echo "$1"; }
err() {
    echo "Error: $1" >&2
    echo "Press Enter to exit..." >&2
    read -r < /dev/tty 2>/dev/null || sleep 2
    exit 1
}

# Check requirements first
log "Checking requirements..."
command -v git >/dev/null 2>&1 || err "Git not found - please install git"
command -v docker >/dev/null 2>&1 || err "Docker not found - please install docker"
docker compose version >/dev/null 2>&1 || err "'docker compose' not available - please install Docker Compose v2"
log "✓ Requirements met"

# Update existing or install new
if [ -d "$DEFAULT_DIR/.git" ]; then
    DIR="$DEFAULT_DIR"
    log "Updating existing installation at $DIR..."
    cd "$DIR" && git pull --quiet
    log "✓ Repository updated"
else
    # First time install - explain and confirm
    echo ""
    echo -e "\033[1;32mLUMENMON\033[0m"
    echo ""
    echo "Press Enter to clone installer to $DEFAULT_DIR and start setup..."
    read -r < /dev/tty

    DIR="$DEFAULT_DIR"
    echo ""
    log "Installing to $DIR..."
    git clone --quiet "$REPO" "$DIR"
    log "✓ Installation ready"
fi

export DIR

# Load proper status helpers
source "$DIR/installer/status.sh"

cd "$DIR"

# Route to appropriate installer
if [ -n "$LUMENMON_INVITE" ]; then
    status_progress "Starting agent installer..."
    source installer/agent.sh
else
    status_progress "Starting console installer..."
    source installer/menu.sh
    show_menu
fi