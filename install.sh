#!/bin/bash
# Self-contained Lumenmon Console installer - downloads only what's needed (no repo clone).
# Installs console with web dashboard and MQTT broker for receiving agent metrics.

set -e

# Version
INSTALLER_VERSION="1.0.0"

# Configuration
INSTALL_DIR="$HOME/.lumenmon"
GITHUB_RAW="https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main"
GITHUB_IMAGE_CONSOLE="ghcr.io/chriopter/lumenmon-console:latest"

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
    mkdir -p "$INSTALL_DIR/console/data"
    chmod 755 "$INSTALL_DIR/console/data"

    # Pull latest image and show version
    status_progress "Pulling latest console image..."
    cd "$INSTALL_DIR/console"
    docker compose pull 2>&1 | grep -E "(Pulling|Downloaded|Status:|digest:)" || true

    # Show pulled image version for verification
    IMAGE=$(docker compose config 2>/dev/null | grep "image:" | head -1 | awk '{print $2}')
    if [ -n "$IMAGE" ]; then
        IMAGE_INFO=$(docker images --format "{{.Repository}}:{{.Tag}} ({{.ID}} created {{.CreatedAt}})" "$IMAGE" 2>/dev/null | head -1)
        echo "[i] Pulled: $IMAGE_INFO" >&2
    fi

    # Start console
    status_progress "Starting console..."
    docker compose up -d 2>&1 | grep -v "Pulling" || true

    status_ok "Console installed at $INSTALL_DIR/console/"
}


# Generate invite
generate_invite() {
    sleep 3  # Wait for console to be ready
    docker exec lumenmon-console /app/core/enrollment/invite_create.sh --full 2>/dev/null || echo ""
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
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ Lumenmon installed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Show current status
    if command -v lumenmon >/dev/null 2>&1; then
        # Wait a moment for services to stabilize
        sleep 2
        lumenmon status
        echo ""
    fi

    # CLI commands section
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Use Lumenmon"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "CLI commands:"
    echo "  lumenmon           - Open WebTUI (or status if not running)"
    echo "  lumenmon start     - Start console and/or agent"
    echo "  lumenmon status    - Show system status"
    echo "  lumenmon logs      - View logs"
    echo "  lumenmon invite    - Generate agent invite"
    echo "  lumenmon register  - Register agent with invite"
    echo "  lumenmon update    - Pull latest containers and restart"
    echo "  lumenmon uninstall - Remove everything"
    echo ""

    # Invite section (for console installations)
    if [ -n "$invite_url" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Add Monitoring Agents"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Copy this command to each machine you want to monitor:"
        echo ""
        echo "  curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install-agent.sh | \\"
        echo "    LUMENMON_INVITE=\"$invite_url\" bash"
        echo ""
        echo "Or get a new invite anytime:"
        echo ""
        echo "  lumenmon invite"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    fi

    # Dashboard URL (for console installations)
    if [ "$mode" != "agent" ]; then
        local dashboard_host="${console_host:-localhost}"
        echo "Dashboard: http://${dashboard_host}:8080"
        echo ""
    fi
}

# Get image version info
get_image_version() {
    local image="$1"
    # Pull image quietly to get latest metadata
    docker pull -q "$image" >/dev/null 2>&1 || return
    # Get image creation date and short ID
    docker inspect "$image" --format '{{.Created}} {{.Id}}' 2>/dev/null | \
        awk '{split($1,d,"T"); split($2,id,":"); printf "%s %s", d[1], substr(id[2],1,12)}'
}

# Main installation flow
main() {
    show_logo
    check_requirements

    # Show version info
    status_progress "Checking latest version..."
    CONSOLE_VERSION=$(get_image_version "$GITHUB_IMAGE_CONSOLE")

    echo ""
    echo "  Installer version: v${INSTALLER_VERSION}"
    if [ -n "$CONSOLE_VERSION" ]; then
        echo "  Latest console:    ${CONSOLE_VERSION}"
    fi

    echo "  Installation path: $INSTALL_DIR"
    echo ""

    # Get hostname for agent connections
    DETECTED_HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$DETECTED_HOST" ] && DETECTED_HOST="localhost"

    echo "  Enter hostname for agent connections"
    echo "  (This will be in invite URLs for remote agents to connect)"
    echo -n "  Hostname [$DETECTED_HOST]: "
    read -r USER_HOST < /dev/tty 2>/dev/null || true
    CONSOLE_HOST="${USER_HOST:-$DETECTED_HOST}"

    echo ""
    install_console "$CONSOLE_HOST"

    # Generate invite for agents
    INVITE_URL=$(generate_invite)

    install_cli
    show_completion "console" "$INVITE_URL" "$CONSOLE_HOST"
}

# Run main installer
main
