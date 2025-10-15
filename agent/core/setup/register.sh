#!/bin/sh
# Registers agent with console using invite URL (ssh://user:pass@host:port/#hostkey).
# Parses invite, sends agent's public key to console, saves host key for future connections.
[ $# -ne 1 ] && echo "Usage: $0 URL" && exit 1

echo "[REGISTER] Processing invite" >&2

# Parse URL: ssh://user:pass@host:port/#hostkey
URL="$1"
URL="${URL#ssh://}"  # Remove scheme
USER_PASS="${URL%%@*}"
HOST_PORT="${URL#*@}"
HOST_PORT="${HOST_PORT%%/*}"
HOSTKEY="${URL#*#}"

USERNAME="${USER_PASS%%:*}"
PASSWORD="${USER_PASS#*:}"
HOST="${HOST_PORT%%:*}"
PORT="${HOST_PORT#*:}"

echo "[REGISTER] Connecting to ${HOST}:${PORT} as ${USERNAME}" >&2

# No host rewriting needed - agent uses network_mode: host

# Get our key
PUBLIC_KEY=$(cat /home/metrics/.ssh/id_*.pub 2>/dev/null | head -1)
[ -z "$PUBLIC_KEY" ] && echo "[REGISTER] ERROR: No SSH key found" >&2 && exit 1

echo "[REGISTER] Found key: $(echo "$PUBLIC_KEY" | cut -c1-50)..." >&2

# Save ED25519 host key
KNOWN_HOSTS="/tmp/known_hosts_$$"
echo "[$HOST]:$PORT ${HOSTKEY//_/ }" > "$KNOWN_HOSTS"

echo "[REGISTER] Sending key to console..." >&2
if echo "$PUBLIC_KEY" | sshpass -p "$PASSWORD" \
    ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS" \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    -p "$PORT" "${USERNAME}@${HOST}" 2>&1; then
    mkdir -p /home/metrics/.ssh
    mv "$KNOWN_HOSTS" /home/metrics/.ssh/known_hosts

    echo "[REGISTER] Success! Host key saved." >&2
else
    ERROR=$?
    rm -f "$KNOWN_HOSTS"
    echo "[REGISTER] Failed with exit code: $ERROR" >&2
    exit 1
fi