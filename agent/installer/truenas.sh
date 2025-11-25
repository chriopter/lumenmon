#!/bin/bash
# TrueNAS SCALE agent installer - installs to pool, uses Init Script.
# Usage: truenas.sh [invite-url]
# NOTE: Must be run as root. Install path must be on a pool (/mnt/yourpool/).
set -e

GITHUB_REPO="https://github.com/chriopter/lumenmon.git"
INVITE_URL="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}TrueNAS SCALE Detected${NC}"
echo ""
echo "IMPORTANT: On TrueNAS, scripts must be stored on a pool to survive updates."
echo "The boot partition is wiped on each TrueNAS update."
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root on TrueNAS${NC}"
    exit 1
fi

# Get available pools
pools=($(zpool list -H -o name 2>/dev/null))
if [ ${#pools[@]} -eq 0 ]; then
    echo -e "${RED}Error: No ZFS pools found${NC}"
    exit 1
fi

# Get install path from user
if [ -z "${LUMENMON_INSTALL_DIR:-}" ]; then
    echo "Select pool:"
    for i in "${!pools[@]}"; do
        echo "  $((i+1))) ${pools[$i]}"
    done
    echo "  c) Custom path"
    echo ""
    echo -n "Choice [1]: "
    read -r choice < /dev/tty
    choice="${choice:-1}"

    if [ "$choice" = "c" ] || [ "$choice" = "C" ]; then
        echo -n "Enter full path: "
        read -r INSTALL_DIR < /dev/tty
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#pools[@]} ]; then
        selected_pool="${pools[$((choice-1))]}"
        INSTALL_DIR="/mnt/$selected_pool/lumenmon"
    else
        echo -e "${RED}Invalid choice${NC}"
        exit 1
    fi
else
    INSTALL_DIR="$LUMENMON_INSTALL_DIR"
fi

# Validate path is on a pool
if [[ ! "$INSTALL_DIR" =~ ^/mnt/ ]]; then
    echo -e "${RED}Error: Install path must be under /mnt/ (on a pool)${NC}"
    exit 1
fi

echo ""
echo "Install path: $INSTALL_DIR"

# Check requirements
echo ""
echo "Checking requirements..."
has_error=0

for cmd in bash git openssl mosquitto_pub; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  $cmd ${GREEN}found${NC}"
    else
        echo -e "  $cmd ${RED}missing${NC}"
        has_error=1
    fi
done

if [ $has_error -eq 1 ]; then
    echo ""
    echo -e "${RED}Missing requirements.${NC}"
    echo "On TrueNAS SCALE, install with: apt install mosquitto-clients git"
    echo "(Note: apt packages don't survive updates, but mosquitto-clients is usually pre-installed)"
    exit 1
fi

# Show what will be installed
echo ""
echo "This will:"
echo "  - Clone agent to $INSTALL_DIR"
echo "  - Create startup script for Init/Shutdown Scripts"
echo "  - Create CLI: /usr/local/bin/lumenmon-agent"
echo ""
echo -e "${YELLOW}After install, add Init Script in TrueNAS WebUI:${NC}"
echo "  System Settings → Advanced → Init/Shutdown Scripts"
echo "  Type: Script, When: Post Init"
echo "  Script: $INSTALL_DIR/agent/agent.sh &"
echo ""

if [ -n "$INVITE_URL" ]; then
    echo "  - Register with provided invite URL"
    echo "  - Start the agent"
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
    git -C "$INSTALL_DIR" pull --ff-only
else
    git clone --depth 1 --filter=blob:none --sparse "$GITHUB_REPO" "$INSTALL_DIR"
    git -C "$INSTALL_DIR" sparse-checkout set agent
fi

# Agent dir after sparse checkout
AGENT_DIR="$INSTALL_DIR/agent"

# Ensure scripts are executable
chmod +x "$AGENT_DIR"/*.sh "$AGENT_DIR"/lumenmon-agent
chmod +x "$AGENT_DIR"/core/*.sh "$AGENT_DIR"/core/*/*.sh
chmod +x "$AGENT_DIR"/collectors/*/*.sh 2>/dev/null || true

# Set LUMENMON_HOME in agent.sh (so it finds the right path)
if ! grep -q "^export LUMENMON_HOME=" "$AGENT_DIR/agent.sh"; then
    sed -i "2i export LUMENMON_HOME=\"$AGENT_DIR\"" "$AGENT_DIR/agent.sh"
fi

# CLI symlink (will be lost on update, but convenient)
mkdir -p /usr/local/bin
ln -sf "$AGENT_DIR/lumenmon-agent" /usr/local/bin/lumenmon-agent

# Create a wrapper script for Init Script
cat > "$INSTALL_DIR/start-agent.sh" << EOF
#!/bin/bash
# Lumenmon agent startup script for TrueNAS Init Scripts
# Add this as Post Init Script in TrueNAS WebUI
cd "$AGENT_DIR"
export LUMENMON_HOME="$AGENT_DIR"
nohup ./agent.sh > /tmp/lumenmon-agent.log 2>&1 &
echo "Lumenmon agent started (PID: \$!)"
EOF
chmod +x "$INSTALL_DIR/start-agent.sh"

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Files installed to: $INSTALL_DIR"

# If invite URL provided, register and start
if [ -n "$INVITE_URL" ]; then
    echo ""
    echo "Registering agent..."
    export LUMENMON_HOME="$AGENT_DIR"
    LUMENMON_AUTO_ACCEPT=1 "$AGENT_DIR/core/setup/register.sh" "$INVITE_URL"

    echo ""
    echo "Starting agent..."
    cd "$AGENT_DIR"
    nohup ./agent.sh > /tmp/lumenmon-agent.log 2>&1 &
    echo "Agent started (PID: $!)"
fi

echo ""
echo -e "${YELLOW}IMPORTANT: To start agent on boot:${NC}"
echo "  1. Go to TrueNAS WebUI → System Settings → Advanced"
echo "  2. Add Init/Shutdown Script:"
echo "     - Type: Script"
echo "     - When: Post Init"
echo "     - Script: $INSTALL_DIR/start-agent.sh"
echo ""
echo "CLI commands (may need to re-run after TrueNAS updates):"
echo "  lumenmon-agent status"
echo "  lumenmon-agent logs"
