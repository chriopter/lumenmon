#!/bin/bash
# Lumenmon Console installer (Docker) - installs the Rails console runtime.
# Downloads compose/CLI files and starts the published console image.
set -e

INSTALL_DIR="$HOME/.lumenmon"
GITHUB_RAW="https://raw.githubusercontent.com/chriopter/lumenmon/main"

C_RESET='\033[0m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'

ok() { echo -e "  ${C_GREEN}✓${C_RESET} $1"; }
err() { echo -e "  ${C_RED}✗${C_RESET} $1"; exit 1; }

check_requirements() {
    command -v docker >/dev/null 2>&1 || err "Docker not found"
    docker compose version >/dev/null 2>&1 || err "Docker Compose v2 not found"
    command -v curl >/dev/null 2>&1 || err "curl not found"
    ok "All requirements met"
}

install_console() {
    local hostname="$1"

    mkdir -p "$INSTALL_DIR/console/data"
    curl -fsSL "$GITHUB_RAW/console/docker-compose.yml" -o "$INSTALL_DIR/console/docker-compose.yml"
    curl -fsSL "$GITHUB_RAW/console/lumenmon" -o "$INSTALL_DIR/console/lumenmon"
    chmod +x "$INSTALL_DIR/console/lumenmon"
    echo "CONSOLE_HOST=$hostname" > "$INSTALL_DIR/console/.env"

    cd "$INSTALL_DIR/console"
    docker compose up -d --pull always

    if ln -sf "$INSTALL_DIR/console/lumenmon" /usr/local/bin/lumenmon 2>/dev/null; then
        ok "CLI installed: lumenmon"
    elif mkdir -p ~/.local/bin && ln -sf "$INSTALL_DIR/console/lumenmon" ~/.local/bin/lumenmon 2>/dev/null; then
        ok "CLI installed: ~/.local/bin/lumenmon"
    else
        ok "CLI installed at $INSTALL_DIR/console/lumenmon"
    fi
}

wait_for_console() {
    for _ in $(seq 1 30); do
        if docker exec lumenmon-console /app/core/status.sh >/dev/null 2>&1; then
            ok "Console ready"
            return 0
        fi
        sleep 1
    done
    err "Console failed to start"
}

main() {
    check_requirements

    DETECTED_HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$DETECTED_HOST" ] && DETECTED_HOST="localhost"

    echo "Hostname for agent connections [$DETECTED_HOST]: "
    read -r USER_HOST < /dev/tty 2>/dev/null || true
    CONSOLE_HOST="${USER_HOST:-$DETECTED_HOST}"

    install_console "$CONSOLE_HOST"
    wait_for_console

    INVITE_URL=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh 2>/dev/null | head -1)

    echo ""
    echo "Dashboard: http://${CONSOLE_HOST}:8080"
    echo "Invite:"
    echo -e "${C_YELLOW}curl -sSL $GITHUB_RAW/agent/install.sh | bash -s '${INVITE_URL}'${C_RESET}"
}

main "$@"
