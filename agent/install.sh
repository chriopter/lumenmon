#!/bin/bash
# Lumenmon agent installer - detects OS and runs appropriate installer.
# Supports: Debian, Ubuntu, Proxmox VE
# Usage: install.sh [invite-url]
set -e

GITHUB_RAW="https://raw.githubusercontent.com/chriopter/lumenmon/main/agent/installer"
INVITE_URL="${1:-}"

echo ""
echo "Lumenmon Agent Installer"
echo "========================"

# Detect OS
if [ ! -f /etc/os-release ]; then
    echo "Error: Cannot detect OS (no /etc/os-release)"
    exit 1
fi

. /etc/os-release

case "$ID" in
    debian|ubuntu)
        echo "Detected: $NAME"
        echo ""
        ;;
    *)
        echo "Error: Unsupported OS: $NAME ($ID)"
        echo "Supported: Debian, Ubuntu, Proxmox VE"
        exit 1
        ;;
esac

# Download and run OS-specific installer
curl -fsSL "$GITHUB_RAW/debian.sh" -o /tmp/lumenmon-install.sh
chmod +x /tmp/lumenmon-install.sh
/tmp/lumenmon-install.sh "$INVITE_URL"
rm -f /tmp/lumenmon-install.sh
