#!/bin/bash
# Lumenmon Console installer (Docker) - for the central monitoring dashboard.
set -e

INSTALL_DIR="$HOME/.lumenmon"
GITHUB_RAW="https://raw.githubusercontent.com/chriopter/lumenmon/main"

# Colors
C_RESET='\033[0m'
C_CYAN='\033[0;36m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_DIM='\033[2m'

ok() { echo -e "  ${C_GREEN}✓${C_RESET} $1"; }
err() { echo -e "  ${C_RED}✗${C_RESET} $1"; exit 1; }
info() { echo -e "  ${C_DIM}$1${C_RESET}"; }
line() { echo -e "${C_DIM}────────────────────────────────────────────────────────────${C_RESET}"; }

show_logo() {
    clear
    echo -e "${C_CYAN}"
    echo "  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗"
    echo "  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║"
    echo "  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║"
    echo "  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║"
    echo "  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
    echo "  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "${C_RESET}"
    echo ""
}

check_requirements() {
    echo "  Checking requirements..."
    command -v docker >/dev/null 2>&1 || err "Docker not found"
    docker compose version >/dev/null 2>&1 || err "Docker Compose v2 not found"
    command -v curl >/dev/null 2>&1 || err "curl not found"
    ok "All requirements met"
}

install_console() {
    local hostname="$1"

    echo ""
    echo "  Installing console..."
    mkdir -p "$INSTALL_DIR/console/data"

    # Download docker-compose.yml
    curl -fsSL "$GITHUB_RAW/console/docker-compose.yml" -o "$INSTALL_DIR/console/docker-compose.yml"
    echo "CONSOLE_HOST=$hostname" > "$INSTALL_DIR/console/.env"

    # Pull and start
    cd "$INSTALL_DIR/console"
    docker compose pull -q 2>/dev/null || true
    docker compose up -d 2>&1 | grep -v "Pulling" || true
    ok "Console started"
}

install_cli() {
    curl -fsSL "$GITHUB_RAW/console/lumenmon" -o "$INSTALL_DIR/console/lumenmon"
    chmod +x "$INSTALL_DIR/console/lumenmon"

    if ln -sf "$INSTALL_DIR/console/lumenmon" /usr/local/bin/lumenmon 2>/dev/null; then
        ok "CLI installed: lumenmon"
    elif mkdir -p ~/.local/bin && ln -sf "$INSTALL_DIR/console/lumenmon" ~/.local/bin/lumenmon 2>/dev/null; then
        ok "CLI installed: ~/.local/bin/lumenmon"
    else
        info "CLI at: $INSTALL_DIR/console/lumenmon"
    fi
}

wait_for_console() {
    echo ""
    echo "  Waiting for services..."
    for i in $(seq 1 30); do
        if docker exec lumenmon-console pgrep -x mosquitto >/dev/null 2>&1; then
            ok "MQTT broker ready"
            return 0
        fi
        sleep 1
    done
    err "Console failed to start"
}

generate_invite() {
    sleep 2
    docker exec lumenmon-console /app/core/enrollment/invite_create.sh 2>/dev/null | head -1
}

show_completion() {
    local invite_url="$1"
    local console_host="$2"

    echo ""
    line
    echo -e "  ${C_GREEN}✓ Installation complete!${C_RESET}"
    line
    echo ""

    # Parse invite
    local agent_id=""
    if [[ "$invite_url" =~ lumenmon://([^:]+): ]]; then
        agent_id="${BASH_REMATCH[1]}"
    fi

    # Summary table
    echo -e "  ${C_CYAN}Console${C_RESET}"
    echo "  ├─ Dashboard    http://${console_host}:8080"
    echo "  ├─ MQTT         ${console_host}:8884 (TLS)"
    echo "  └─ Data         $INSTALL_DIR/console/data/"
    echo ""

    echo -e "  ${C_CYAN}Commands${C_RESET}"
    echo "  ├─ lumenmon invite     Generate agent invite"
    echo "  ├─ lumenmon logs       View logs"
    echo "  ├─ lumenmon update     Update console"
    echo "  └─ lumenmon uninstall  Remove everything"
    echo ""

    if [ -n "$invite_url" ]; then
        line
        echo -e "  ${C_CYAN}Add Your First Agent${C_RESET}"
        line
        echo ""
        echo "  Run this on the machine you want to monitor:"
        echo ""
        echo -e "  ${C_YELLOW}curl -sSL $GITHUB_RAW/agent/install.sh | bash -s '${invite_url}'${C_RESET}"
        echo ""
        info "Generate more invites anytime: lumenmon invite"
        echo ""
    fi
}

main() {
    show_logo
    check_requirements

    # Get hostname
    DETECTED_HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$DETECTED_HOST" ] && DETECTED_HOST="localhost"

    echo ""
    echo "  Hostname for agent connections (used in invite URLs)"
    echo -n "  [$DETECTED_HOST]: "
    read -r USER_HOST < /dev/tty 2>/dev/null || true
    CONSOLE_HOST="${USER_HOST:-$DETECTED_HOST}"

    install_console "$CONSOLE_HOST"
    wait_for_console
    install_cli

    INVITE_URL=$(generate_invite)
    show_completion "$INVITE_URL" "$CONSOLE_HOST"
}

main "$@"
