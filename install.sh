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

# Run installer
cd "$DIR"
source installer/menu.sh
source installer/deploy.sh

# Start
show_menu
deploy_component