#!/bin/bash
# Lumenmon Installer
set -e

# Setup
REPO="https://github.com/chriopter/lumenmon.git"
DIR="$HOME/.lumenmon"
export DIR

# Check requirements
command -v git >/dev/null 2>&1 || { echo "Need git"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Need docker"; exit 1; }

# Clone or update
if [ -d "$DIR/.git" ]; then
    cd "$DIR" && git pull --quiet
else
    git clone --quiet "$REPO" "$DIR"
fi

# Dispatch to appropriate installer
cd "$DIR"

if [ -n "$LUMENMON_INVITE" ]; then
    # Agent installation with invite
    source installer/agent.sh
else
    # Interactive menu
    source installer/menu.sh
    source installer/deploy.sh
    show_menu
    deploy_component
fi