#!/bin/bash
# Lumenmon agent installer - detects OS and runs appropriate installer.
# Supports: Debian, Ubuntu, TrueNAS SCALE
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

# Check for TrueNAS SCALE (Debian-based but needs special handling)
IS_TRUENAS=false
if [ -f /etc/version ] && grep -qi "truenas" /etc/version 2>/dev/null; then
    IS_TRUENAS=true
elif command -v midclt &>/dev/null; then
    IS_TRUENAS=true
fi

if [ "$IS_TRUENAS" = true ]; then
    echo "Detected: TrueNAS SCALE"
    echo ""
    # TrueNAS restricts execution everywhere, pipe directly to bash
    curl -fsSL "$GITHUB_RAW/truenas.sh" | bash -s "$INVITE_URL"
    exit 0
fi

case "$ID" in
    debian|ubuntu)
        echo "Detected: $NAME"
        echo ""
        ;;
    *)
        echo "Error: Unsupported OS: $NAME ($ID)"
        echo "Supported: Debian, Ubuntu, TrueNAS SCALE"
        exit 1
        ;;
esac

# Download and run OS-specific installer
curl -fsSL "$GITHUB_RAW/debian.sh" -o /tmp/lumenmon-install.sh
chmod +x /tmp/lumenmon-install.sh
/tmp/lumenmon-install.sh "$INVITE_URL"
rm -f /tmp/lumenmon-install.sh
