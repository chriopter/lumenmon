#!/bin/bash
# Uninstall Lumenmon

source installer/status.sh

echo ""
status_warn "This will remove all Lumenmon containers and data"
status_prompt "Continue uninstall? [y/N]: "
read -r -n 1 CONFIRM < /dev/tty
echo ""

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""

# Stop containers
[ -d "$DIR/console" ] && cd "$DIR/console" && docker compose down -v 2>/dev/null && status_ok "Console removed"
[ -d "$DIR/agent" ] && cd "$DIR/agent" && docker compose down -v 2>/dev/null && status_ok "Agent removed"

# Remove network
docker network rm lumenmon-net 2>/dev/null && status_ok "Network removed"

# Remove directory
status_progress "Removing $DIR..."
cd "$HOME"

# Try normal remove first
if rm -rf "$DIR" 2>/dev/null; then
    status_ok "Lumenmon uninstalled"
else
    # Need elevated permissions for Docker-created files
    status_warn "Need sudo to remove Docker-created files"
    echo ""
    status_prompt "Use sudo to remove $DIR? [y/N]: "
    read -r -n 1 CONFIRM < /dev/tty
    echo ""

    if [[ $CONFIRM =~ ^[Yy]$ ]]; then
        sudo rm -rf "$DIR" && status_ok "Lumenmon uninstalled" || status_error "Failed to remove $DIR"
    else
        status_warn "Directory not removed: $DIR"
        echo "Remove manually with: sudo rm -rf $DIR"
    fi
fi

echo ""