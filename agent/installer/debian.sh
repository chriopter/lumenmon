#!/bin/bash
# Debian/Ubuntu agent installer - installs deps, downloads files, creates systemd service.
# Usage: debian.sh [invite-url]
set -e

INSTALL_DIR="${LUMENMON_INSTALL_DIR:-/opt/lumenmon}"
GITHUB_RAW="https://raw.githubusercontent.com/chriopter/lumenmon/main/agent"
INVITE_URL="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check all requirements upfront
echo "Checking requirements..."
echo ""
has_error=0

for cmd in bash curl openssl systemctl sudo apt-get; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  $cmd ${GREEN}found${NC}"
    else
        echo -e "  $cmd ${RED}missing${NC}"
        has_error=1
    fi
done

echo ""
if [ $has_error -eq 1 ]; then
    echo "Please install missing commands and try again."
    exit 1
fi

# Show what will be installed
echo ""
echo "This will:"
echo "  - Install mosquitto-clients (apt-get)"
echo "  - Download agent to $INSTALL_DIR"
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

# Install mosquitto-clients
if ! command -v mosquitto_pub >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq mosquitto-clients
fi

# Create directories
sudo mkdir -p "$INSTALL_DIR/core/mqtt" "$INSTALL_DIR/core/setup" "$INSTALL_DIR/core/connection"
sudo mkdir -p "$INSTALL_DIR/collectors/generic"
sudo mkdir -p "$INSTALL_DIR/data/mqtt"

# Download files
sudo curl -fsSL "$GITHUB_RAW/agent.sh" -o "$INSTALL_DIR/agent.sh"
sudo curl -fsSL "$GITHUB_RAW/lumenmon-agent" -o "$INSTALL_DIR/lumenmon-agent"
sudo curl -fsSL "$GITHUB_RAW/core/mqtt/publish.sh" -o "$INSTALL_DIR/core/mqtt/publish.sh"
sudo curl -fsSL "$GITHUB_RAW/core/setup/register.sh" -o "$INSTALL_DIR/core/setup/register.sh"
sudo curl -fsSL "$GITHUB_RAW/core/connection/collectors.sh" -o "$INSTALL_DIR/core/connection/collectors.sh"
sudo curl -fsSL "$GITHUB_RAW/core/status.sh" -o "$INSTALL_DIR/core/status.sh"

for c in cpu disk heartbeat hostname lumenmon memory; do
    sudo curl -fsSL "$GITHUB_RAW/collectors/generic/${c}.sh" -o "$INSTALL_DIR/collectors/generic/${c}.sh"
done

# Set permissions
sudo chmod +x "$INSTALL_DIR/agent.sh" "$INSTALL_DIR/lumenmon-agent"
sudo chmod +x "$INSTALL_DIR/core/status.sh" "$INSTALL_DIR/core/mqtt/publish.sh"
sudo chmod +x "$INSTALL_DIR/core/setup/register.sh" "$INSTALL_DIR/core/connection/collectors.sh"
sudo chmod +x "$INSTALL_DIR/collectors/generic/"*.sh
sudo chmod 755 "$INSTALL_DIR/data"

# Create systemd service
sudo tee /etc/systemd/system/lumenmon-agent.service > /dev/null << EOF
[Unit]
Description=Lumenmon Monitoring Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/agent.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

# CLI symlink
sudo ln -sf "$INSTALL_DIR/lumenmon-agent" /usr/local/bin/lumenmon-agent

echo ""
echo "Installation complete!"

# If invite URL provided, register and start
if [ -n "$INVITE_URL" ]; then
    echo ""
    echo "Registering agent..."
    export LUMENMON_HOME="$INSTALL_DIR"
    export LUMENMON_DATA="$INSTALL_DIR/data"
    "$INSTALL_DIR/core/setup/register.sh" "$INVITE_URL"

    echo ""
    echo "Starting agent..."
    sudo systemctl start lumenmon-agent
    sudo systemctl enable lumenmon-agent
    echo "Agent is running."
else
    echo ""
    echo "Next steps:"
    echo "  1. lumenmon-agent register '<invite-url>'"
    echo "  2. lumenmon-agent start"
fi
