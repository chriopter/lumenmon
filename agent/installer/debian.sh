#!/bin/bash
# Debian/Ubuntu agent installer - clones repo, creates systemd service.
# Usage: debian.sh [invite-url]
set -e

INSTALL_DIR="${LUMENMON_INSTALL_DIR:-/opt/lumenmon}"
GITHUB_REPO="https://github.com/chriopter/lumenmon.git"
INVITE_URL="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Use sudo if not root
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Check all requirements upfront
echo "Checking requirements..."
echo ""
has_error=0
missing_pkgs=""

for cmd in bash git openssl systemctl mosquitto_pub; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  $cmd ${GREEN}found${NC}"
    else
        echo -e "  $cmd ${RED}missing${NC}"
        has_error=1
        if [ "$cmd" = "mosquitto_pub" ]; then
            missing_pkgs="$missing_pkgs mosquitto-clients"
        else
            missing_pkgs="$missing_pkgs $cmd"
        fi
    fi
done

# Check sudo only if not root
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        echo -e "  sudo ${GREEN}found${NC}"
    else
        echo -e "  sudo ${RED}missing${NC} (required when not running as root)"
        has_error=1
    fi
fi

echo ""
if [ $has_error -eq 1 ]; then
    echo "Missing requirements. Install with:"
    echo "  apt-get install$missing_pkgs"
    exit 1
fi

# Show what will be installed
echo ""
echo "This will:"
echo "  - Clone agent to $INSTALL_DIR"
echo "  - Create systemd service: lumenmon-agent"
echo "  - Create CLI: /usr/local/bin/lumenmon-agent"
if [ -n "$INVITE_URL" ]; then
    echo "  - Register with provided invite URL"
    echo "  - Start the agent service"
fi
echo -n "Continue? [y/N] "
read -n 1 -r REPLY < /dev/tty
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Installing..."

# Clone repo (agent directory only)
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation..."
    $SUDO git -C "$INSTALL_DIR" pull --ff-only
else
    $SUDO git clone --depth 1 --filter=blob:none --sparse "$GITHUB_REPO" "$INSTALL_DIR"
    $SUDO git -C "$INSTALL_DIR" sparse-checkout set agent
fi

# Agent dir after sparse checkout
AGENT_DIR="$INSTALL_DIR/agent"

# Create systemd service
$SUDO tee /etc/systemd/system/lumenmon-agent.service > /dev/null << EOF
[Unit]
Description=Lumenmon Monitoring Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$AGENT_DIR/agent.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

$SUDO systemctl daemon-reload

# CLI symlink
$SUDO ln -sf "$AGENT_DIR/lumenmon-agent" /usr/local/bin/lumenmon-agent

echo ""
echo "Installation complete!"

# If invite URL provided, register and start
if [ -n "$INVITE_URL" ]; then
    echo ""
    echo "Registering agent..."
    "$AGENT_DIR/core/setup/register.sh" "$INVITE_URL"

    echo ""
    echo "Starting agent..."
    $SUDO systemctl start lumenmon-agent
    $SUDO systemctl enable lumenmon-agent
    echo "Agent is running."
else
    echo ""
    echo "Next steps:"
    echo "  1. lumenmon-agent register '<invite-url>'"
    echo "  2. lumenmon-agent start"
fi
