#!/bin/bash
# Lumenmon Installer
set -e

REPO="https://github.com/chriopter/lumenmon.git"
DEFAULT_DIR="$HOME/.lumenmon"

# Minimal output helpers
log() { echo "$1"; }
err() { echo "Error: $1" >&2; exit 1; }

# Update existing installation
if [ -d "$DEFAULT_DIR/.git" ]; then
    DIR="$DEFAULT_DIR"
    log "Updating existing installation at $DIR..."
    cd "$DIR" && git pull --quiet
    log "✓ Repository updated"
else
    # Fresh installation
    echo ""
    echo "Lumenmon System Monitor"
    echo ""
    echo "This will:"
    echo "• Install to $DEFAULT_DIR"
    echo "• Set up monitoring containers"
    echo ""
    echo -n "Continue? [Y/n]: "
    read -r -n 1 CONFIRM
    echo ""

    [[ $CONFIRM =~ ^[Nn]$ ]] && exit 0

    # Check requirements
    echo ""
    log "Checking requirements..."
    command -v git >/dev/null 2>&1 || err "Git not found - please install git"
    command -v docker >/dev/null 2>&1 || err "Docker not found - please install docker"
    log "✓ Requirements met"

    # Clone repository
    DIR="$DEFAULT_DIR"
    log "Installing to $DIR..."
    git clone --quiet "$REPO" "$DIR"
    log "✓ Installation ready"
fi

export DIR

# Load status helpers
source "$DIR/installer/status.sh"

cd "$DIR"

# Route to component installer
if [ -n "$LUMENMON_INVITE" ]; then
    status_progress "Starting agent installer..."
    source installer/agent.sh
else
    status_progress "Starting console installer..."
    source installer/menu.sh
    show_menu
fi