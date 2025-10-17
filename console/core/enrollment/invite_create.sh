#!/bin/bash
# Creates temporary registration account and generates invite URL with credentials and host key.
# Outputs ssh:// URL or full install command. User auto-expires after 5 minutes.

echo "[INVITE] Creating registration invite" >&2

USERNAME="reg_$(date +%s%3N)"
PASSWORD=$(openssl rand -hex 6)

# Create user (groups already exist from Docker build)
useradd -m -s /bin/sh -G registration "$USERNAME"
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "$PASSWORD" > "/tmp/.invite_${USERNAME}"

# Get ED25519 host key only
HOSTKEY=$(awk '{print $1"_"$2}' /data/ssh/ssh_host_ed25519_key.pub)

# Get console host from environment (set by docker-compose from .env)
CONSOLE_HOST="${CONSOLE_HOST:-localhost}"

# Build URL
INVITE_URL="ssh://${USERNAME}:${PASSWORD}@${CONSOLE_HOST}:2345/#${HOSTKEY}"

# Output based on mode
if [ "$1" = "--full" ]; then
    echo "curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install.sh | LUMENMON_INVITE='$INVITE_URL' bash"
else
    echo "$INVITE_URL"
fi

# Cleanup after 5 minutes (properly detached)
nohup sh -c "sleep 300 && userdel -r $USERNAME 2>/dev/null && rm -f /tmp/.invite_${USERNAME}" </dev/null >/dev/null 2>&1 &