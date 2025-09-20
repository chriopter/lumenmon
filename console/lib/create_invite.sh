#!/bin/bash
# Create invite - user, password, URL
echo "[INVITE] Creating registration invite" >&2

USERNAME="reg_$(date +%s%3N)"
PASSWORD=$(openssl rand -hex 16)

# Create user (groups already exist from Docker build)
useradd -M -s /bin/sh -G registration "$USERNAME"
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "$PASSWORD" > "/tmp/.invite_${USERNAME}"

# Get ED25519 host key only
HOSTKEY=$(awk '{print $1"_"$2}' /data/ssh/ssh_host_ed25519_key.pub)

# Output URL
echo "ssh://${USERNAME}:${PASSWORD}@localhost:2345/#${HOSTKEY}"

# Cleanup after 5 minutes (properly detached)
nohup sh -c "sleep 300 && userdel -r $USERNAME 2>/dev/null && rm -f /tmp/.invite_${USERNAME}" </dev/null >/dev/null 2>&1 &