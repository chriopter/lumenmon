#!/bin/bash
# Lumenmon Installer
set -e

REPO="https://github.com/chriopter/lumenmon.git"
DEFAULT_DIR="$HOME/.lumenmon"

# Minimal status functions before repo is cloned
status_progress() { echo -e "[\033[1;36m→\033[0m] $1"; }
status_ok() { echo -e "[\033[1;32m✓\033[0m] $1"; }
status_prompt() { echo -en "[\033[1;35m?\033[0m] $1"; }
die() { echo -e "[\033[1;31m✗\033[0m] $1"; exit 1; }

# Check requirements first
status_progress "Checking requirements..."
command -v git >/dev/null 2>&1 || die "Git not found - please install git"
status_ok "Git found"
command -v docker >/dev/null 2>&1 || die "Docker not found - please install docker"
status_ok "Docker found"

# Ask for installation directory if not updating
if [ -d "$DEFAULT_DIR/.git" ]; then
    DIR="$DEFAULT_DIR"
    status_progress "Updating existing installation at $DIR..."
    cd "$DIR" && git pull --quiet
    status_ok "Repository updated"
else
    echo ""
    echo "Lumenmon will clone the repository to set up the monitoring system."
    status_prompt "Install location [$DEFAULT_DIR]: "
    read -r USER_DIR
    DIR="${USER_DIR:-$DEFAULT_DIR}"

    # Confirm if directory exists and is not empty
    if [ -d "$DIR" ] && [ "$(ls -A "$DIR" 2>/dev/null)" ]; then
        status_prompt "Directory $DIR exists and is not empty. Continue? [y/N]: "
        read -r -n 1 CONFIRM
        echo ""
        if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
            die "Installation cancelled"
        fi
    fi

    status_progress "Cloning repository to $DIR..."
    git clone --quiet "$REPO" "$DIR"
    status_ok "Repository cloned"
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