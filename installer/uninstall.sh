#!/bin/bash
# Uninstall Lumenmon

source installer/status.sh

echo ""
status_prompt "Uninstall Lumenmon? [y/N]: "
read -r -n 1 CONFIRM < /dev/tty
echo ""

[[ ! $CONFIRM =~ ^[Yy]$ ]] && exit 0

echo ""

# Stop containers
[ -d "$DIR/console" ] && cd "$DIR/console" && docker compose down -v 2>/dev/null && status_ok "console stopped"
[ -d "$DIR/agent" ] && cd "$DIR/agent" && docker compose down -v 2>/dev/null && status_ok "agent stopped"

# Remove network
docker network rm lumenmon-net 2>/dev/null && status_ok "network removed"

# Remove lumenmon command
[ -L /usr/local/bin/lumenmon ] && rm /usr/local/bin/lumenmon 2>/dev/null && status_ok "command removed"
[ -L ~/.local/bin/lumenmon ] && rm ~/.local/bin/lumenmon 2>/dev/null && status_ok "command removed"

# Remove directory
cd "$HOME"
rm -rf "$DIR" 2>/dev/null && status_ok "$DIR removed" || {
    sudo rm -rf "$DIR" && status_ok "$DIR removed (sudo)" || status_error "failed: $DIR"
}

echo ""