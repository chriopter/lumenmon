#!/bin/bash
# Self-contained Lumenmon installer - downloads only what's needed (no repo clone).
# Installs console, agent, or both with minimal configuration and auto-registration.

set -e

# Configuration
INSTALL_DIR="$HOME/.lumenmon"
GITHUB_RAW="https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main"
GITHUB_IMAGE_CONSOLE="ghcr.io/chriopter/lumenmon-console:latest"
GITHUB_IMAGE_AGENT="ghcr.io/chriopter/lumenmon-agent:latest"

# Output helpers
status_ok() { echo -e "[\033[1;32m✓\033[0m] $1"; }
status_error() { echo -e "[\033[1;31m✗\033[0m] $1"; exit 1; }
status_warn() { echo -e "[\033[1;33m⚠\033[0m] $1"; }
status_progress() { echo -e "[\033[1;36m→\033[0m] $1"; }

# Show logo
show_logo() {
    clear
    echo -e "\033[0;36m"
    echo "  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗"
    echo "  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║"
    echo "  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║"
    echo "  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║"
    echo "  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
    echo "  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "\033[0m"
}

# Check prerequisites
check_requirements() {
    status_progress "Checking requirements..."
    command -v docker >/dev/null 2>&1 || status_error "Docker not found - please install docker"
    docker compose version >/dev/null 2>&1 || status_error "'docker compose' not available - please install Docker Compose v2"
    command -v curl >/dev/null 2>&1 || status_error "curl not found - please install curl"
    status_ok "All requirements met"
}

# Download file from GitHub raw
download_file() {
    local url="$1"
    local dest="$2"
    status_progress "Downloading $(basename $dest)..."
    curl -fsSL "$url" -o "$dest" || status_error "Failed to download $url"
}

# Install console
install_console() {
    local hostname="$1"

    status_progress "Installing Console to $INSTALL_DIR/console/"
    mkdir -p "$INSTALL_DIR/console"

    # Download docker-compose.yml
    download_file "$GITHUB_RAW/console/docker-compose.yml" "$INSTALL_DIR/console/docker-compose.yml"

    # Generate .env
    echo "CONSOLE_HOST=$hostname" > "$INSTALL_DIR/console/.env"

    # Pre-create data directories
    mkdir -p "$INSTALL_DIR/console/data/ssh" "$INSTALL_DIR/console/data/agents"
    chmod -R 755 "$INSTALL_DIR/console/data"

    # Start console
    status_progress "Starting console..."
    cd "$INSTALL_DIR/console"
    docker compose up -d --quiet-pull 2>&1 | grep -v "Pulling" || true

    status_ok "Console installed at $INSTALL_DIR/console/"
}

# Install agent
install_agent() {
    local console_host="$1"
    local console_port="${2:-2345}"

    status_progress "Installing Agent to $INSTALL_DIR/agent/"
    mkdir -p "$INSTALL_DIR/agent"

    # Download docker-compose.yml
    download_file "$GITHUB_RAW/agent/docker-compose.yml" "$INSTALL_DIR/agent/docker-compose.yml"

    # Generate .env
    echo "CONSOLE_HOST=$console_host" > "$INSTALL_DIR/agent/.env"
    echo "CONSOLE_PORT=$console_port" >> "$INSTALL_DIR/agent/.env"

    # Pre-create data directories
    mkdir -p "$INSTALL_DIR/agent/data/ssh"
    chmod 777 "$INSTALL_DIR/agent/data/ssh"

    # Start agent
    status_progress "Starting agent..."
    cd "$INSTALL_DIR/agent"
    docker compose up -d --quiet-pull 2>&1 | grep -v "Pulling" || true

    status_ok "Agent installed at $INSTALL_DIR/agent/"
}

# Generate invite
generate_invite() {
    sleep 3  # Wait for console to be ready
    docker exec lumenmon-console /app/core/enrollment/invite_create.sh --full 2>/dev/null || echo ""
}

# Register agent with console
register_agent() {
    local invite_url="$1"
    status_progress "Auto-registering local agent..."
    sleep 2  # Wait for agent to be ready
    docker exec lumenmon-agent /app/core/setup/register.sh "$invite_url" 2>&1 | grep -E "\[REGISTER\]|SUCCESS|ERROR" || true
}

# Install CLI command
install_cli() {
    status_progress "Installing lumenmon CLI..."

    # Download CLI script
    download_file "$GITHUB_RAW/lumenmon.sh" "$INSTALL_DIR/lumenmon"
    chmod +x "$INSTALL_DIR/lumenmon"

    # Create symlink
    if ln -sf "$INSTALL_DIR/lumenmon" /usr/local/bin/lumenmon 2>/dev/null; then
        status_ok "CLI installed: lumenmon"
    elif mkdir -p ~/.local/bin && ln -sf "$INSTALL_DIR/lumenmon" ~/.local/bin/lumenmon 2>/dev/null; then
        status_ok "CLI installed: ~/.local/bin/lumenmon"
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            status_warn "Add ~/.local/bin to your PATH to use 'lumenmon' command"
        fi
    else
        status_warn "Could not create symlink. Use: $INSTALL_DIR/lumenmon"
    fi
}

# Show completion message
show_completion() {
    local mode="$1"
    local invite_url="$2"
    local console_host="$3"

    echo ""
    echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;32m✓ Lumenmon installed!\033[0m"
    echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""

    if [ "$mode" != "agent" ] && [ -n "$invite_url" ]; then
        echo -e "\033[1mInvite URL for remote agents\033[0m (expires in 5 minutes):"
        echo ""
        echo -e "\033[1;36m$invite_url\033[0m"
        echo ""
    fi

    if [ "$mode" != "agent" ]; then
        # Use configured hostname, fallback to localhost
        local dashboard_host="${console_host:-localhost}"
        echo -e "Dashboard: \033[1;36mhttp://${dashboard_host}:8080\033[0m"
        echo ""
    fi

    echo "CLI commands:"
    echo -e "  \033[1;36mlumenmon\033[0m          # Open dashboard"
    echo -e "  \033[1;36mlumenmon status\033[0m   # Show system status"
    echo -e "  \033[1;36mlumenmon invite\033[0m   # Generate new invite"
    echo -e "  \033[1;36mlumenmon update\033[0m   # Update to latest version"
    echo ""
}

# Main installation flow
main() {
    show_logo
    check_requirements

    echo ""
    echo "  Installation path: $INSTALL_DIR"
    echo ""
    echo "  What would you like to install?"
    echo "  1) Console with Agent (recommended)"
    echo "  2) Console only"
    echo "  3) Agent only"
    echo "  4) Exit"
    echo ""
    read -r -p "  Select [1-4]: " choice

    case $choice in
        1)
            # Console with Agent
            echo ""
            DETECTED_HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
            [ -z "$DETECTED_HOST" ] && DETECTED_HOST="localhost"

            echo "  Enter hostname for agent connections"
            echo "  (This will be in invite URLs for remote agents to connect)"
            read -r -p "  Hostname [$DETECTED_HOST]: " USER_HOST
            CONSOLE_HOST="${USER_HOST:-$DETECTED_HOST}"

            echo ""
            install_console "$CONSOLE_HOST"
            install_agent "lumenmon-console" "2345"

            # Generate invite and auto-register
            INVITE_URL=$(generate_invite)
            if [ -n "$INVITE_URL" ]; then
                register_agent "$INVITE_URL"
                status_ok "Local agent connected!"

                # Generate second invite for remote agents
                sleep 1
                REMOTE_INVITE=$(generate_invite)
            fi

            install_cli
            show_completion "both" "$REMOTE_INVITE" "$CONSOLE_HOST"
            ;;

        2)
            # Console only
            echo ""
            DETECTED_HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
            [ -z "$DETECTED_HOST" ] && DETECTED_HOST="localhost"

            echo "  Enter hostname for agent connections"
            echo "  (This will be in invite URLs for remote agents to connect)"
            read -r -p "  Hostname [$DETECTED_HOST]: " USER_HOST
            CONSOLE_HOST="${USER_HOST:-$DETECTED_HOST}"

            echo ""
            install_console "$CONSOLE_HOST"

            INVITE_URL=$(generate_invite)
            install_cli
            show_completion "console" "$INVITE_URL" "$CONSOLE_HOST"
            ;;

        3)
            # Agent only
            echo ""
            read -r -p "  Enter console hostname: " CONSOLE_HOST
            read -r -p "  Enter invite URL: " INVITE_URL

            echo ""
            install_agent "$CONSOLE_HOST" "2345"

            if [ -n "$INVITE_URL" ]; then
                register_agent "$INVITE_URL"
                status_ok "Agent connected!"
            fi

            install_cli
            show_completion "agent" "" ""
            ;;

        4)
            exit 0
            ;;

        *)
            status_error "Invalid choice"
            ;;
    esac
}

# Handle LUMENMON_INVITE environment variable (one-line agent install)
if [ -n "$LUMENMON_INVITE" ]; then
    show_logo
    check_requirements

    URL="$LUMENMON_INVITE"
    HOST="${URL#*@}"; HOST="${HOST%%:*}"
    PORT="${URL##*:}"; PORT="${PORT%%/*}"

    echo ""
    status_ok "Found invite for $HOST:$PORT"
    echo ""

    install_agent "$HOST" "$PORT"
    register_agent "$URL"
    status_ok "Agent connected!"
    install_cli

    echo ""
    echo -e "\033[1;32m✓ Agent installation complete!\033[0m"
    echo ""
else
    main
fi
