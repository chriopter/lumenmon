#!/bin/bash
# Creates temporary registration account and generates invite URL with credentials and host key.
# The invite URL tells agents WHERE to connect and HOW to authenticate during registration.
#
# IMPORTANT: Hostname/port in invite must match where agent will connect at runtime!
# - Same-host Docker setups: Use internal network address (console:22 or lumenmon-console:22)
# - Remote agents: Use external address (public IP or hostname:2345)
# - This prevents SSH known_hosts mismatches (invite saves the host key for that specific address)
#
# Usage: invite_create.sh [--full] [hostname] [port]
#   --full: Output full install command instead of URL only
#   hostname: Where agents will connect (default: $CONSOLE_HOST or localhost)
#   port: SSH port agents will use (default: 2345 for external, 22 for Docker internal)
#
# Examples:
#   invite_create.sh                          # Remote agents: ssh://reg@localhost:2345/...
#   invite_create.sh --full                   # Remote agents with install command
#   invite_create.sh console 22               # Local Docker agent (dev/auto)
#   invite_create.sh lumenmon-console 22      # Local Docker agent (installer)
#   invite_create.sh --full 192.168.1.10 2345 # Remote with custom host

echo "[INVITE] Creating registration invite" >&2

# Parse --full flag (optional first parameter)
FULL_MODE=false
if [ "$1" = "--full" ]; then
    FULL_MODE=true
    shift  # Remove --full from $1, so hostname becomes $1, port becomes $2
fi

# Get invite hostname and port from parameters or sensible defaults
# For same-host Docker: caller passes "console 22" or "lumenmon-console 22"
# For remote agents: no params uses localhost:2345 (or $CONSOLE_HOST:2345 if set)
INVITE_HOST="${1:-${CONSOLE_HOST:-localhost}}"
INVITE_PORT="${2:-2345}"

USERNAME="reg_$(date +%s%3N)"
PASSWORD=$(openssl rand -hex 6)

# Create user (groups already exist from Docker build)
useradd -m -s /bin/sh -G registration "$USERNAME"
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "$PASSWORD" > "/tmp/.invite_${USERNAME}"

# Get ED25519 host key only
HOSTKEY=$(awk '{print $1"_"$2}' /data/ssh/ssh_host_ed25519_key.pub)

# Build URL with specified or default hostname:port
INVITE_URL="ssh://${USERNAME}:${PASSWORD}@${INVITE_HOST}:${INVITE_PORT}/#${HOSTKEY}"

# Output based on mode
if [ "$FULL_MODE" = true ]; then
    echo "curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install.sh | LUMENMON_INVITE='$INVITE_URL' bash"
else
    echo "$INVITE_URL"
fi

# Cleanup after 5 minutes (properly detached)
nohup sh -c "sleep 300 && userdel -r $USERNAME 2>/dev/null && rm -f /tmp/.invite_${USERNAME}" </dev/null >/dev/null 2>&1 &