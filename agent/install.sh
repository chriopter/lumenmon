#!/bin/bash
# Lumenmon agent installer - installs dependencies and sets up systemd service.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${LUMENMON_INSTALL_DIR:-/opt/lumenmon}"

echo "Installing Lumenmon Agent..."

# Install mosquitto-clients
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq mosquitto-clients openssl
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y -q mosquitto openssl
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm mosquitto openssl
elif command -v apk >/dev/null 2>&1; then
    sudo apk add mosquitto-clients openssl
else
    echo "Please install mosquitto-clients manually"
    exit 1
fi

# Copy files
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/lumenmon-agent
sudo chmod +x "$INSTALL_DIR"/core/*.sh "$INSTALL_DIR"/core/*/*.sh
sudo chmod +x "$INSTALL_DIR"/collectors/generic/*.sh

# Create data directory
sudo mkdir -p "$INSTALL_DIR/data/mqtt"
sudo chmod 755 "$INSTALL_DIR/data"

# Create systemd service
sudo tee /etc/systemd/system/lumenmon-agent.service > /dev/null << EOF
[Unit]
Description=Lumenmon Monitoring Agent
After=network-online.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/agent.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

# Symlink CLI
sudo ln -sf "$INSTALL_DIR/lumenmon-agent" /usr/local/bin/lumenmon-agent

echo ""
echo "Installed to $INSTALL_DIR"
echo ""
echo "Next: lumenmon-agent register '<invite-url>'"
echo "Then: lumenmon-agent start"
