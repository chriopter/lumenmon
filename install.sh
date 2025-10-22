#!/bin/bash
# Self-contained Lumenmon installer - downloads only what's needed (no repo clone).
# Installs console, agent, or both with minimal configuration and auto-registration.

set -e

# Version
INSTALLER_VERSION="0.12.0"

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
    chmod 755 "$INSTALL_DIR/console/data"
    chmod 700 "$INSTALL_DIR/console/data/ssh"

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

    # Pull latest image and show version
    status_progress "Pulling latest agent image..."
    cd "$INSTALL_DIR/agent"
    docker compose pull 2>&1 | grep -E "(Pulling|Downloaded|Status:|digest:)" || true

    # Show pulled image version for verification
    IMAGE=$(docker compose config 2>/dev/null | grep "image:" | head -1 | awk '{print $2}')
    if [ -n "$IMAGE" ]; then
        IMAGE_INFO=$(docker images --format "{{.Repository}}:{{.Tag}} ({{.ID}} created {{.CreatedAt}})" "$IMAGE" 2>/dev/null | head -1)
        echo "[i] Pulled: $IMAGE_INFO" >&2
    fi

    # Start agent
    status_progress "Starting agent..."
    docker compose up -d 2>&1 | grep -v "Pulling" || true

    status_ok "Agent installed at $INSTALL_DIR/agent/"
}

# Generate invite
generate_invite() {
    sleep 3  # Wait for console to be ready
    docker exec lumenmon-console /app/core/enrollment/invite_create.sh --full 2>/dev/null || echo ""
}

# Register agent with console using provided invite URL
# The invite URL must already contain the correct Docker network address (lumenmon-console:22)
# for same-host installations, generated by invite_create.sh lumenmon-console 22
register_agent() {
    local invite_url="$1"

    status_progress "Auto-registering local agent..."

    # Wait for agent container to be fully ready (SSH key generated)
    for i in $(seq 1 20); do
        if docker exec lumenmon-agent test -f /home/metrics/.ssh/id_ed25519.pub 2>/dev/null; then
            break
        fi
        sleep 1
    done

    # Try registration
    REGISTER_OUTPUT=$(docker exec lumenmon-agent /app/core/setup/register.sh "$invite_url" 2>&1)

    if echo "$REGISTER_OUTPUT" | grep -qE "Success|ENROLL"; then
        return 0
    else
        # Show error if registration failed
        echo "$REGISTER_OUTPUT" | grep -E "\[REGISTER\]" >&2
        return 1
    fi
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
        echo -e "\033[1mInvite URL for remote agents\033[0m (expires in 60 minutes):"
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
    # Use lumenmon's own help output (DRY - don't duplicate command list)
    if command -v lumenmon >/dev/null 2>&1; then
        lumenmon help | sed 's/^/  /'
    fi
    echo ""
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
    status_progress "Checking latest versions..."
    CONSOLE_VERSION=$(get_image_version "$GITHUB_IMAGE_CONSOLE")
    AGENT_VERSION=$(get_image_version "$GITHUB_IMAGE_AGENT")

    echo ""
    echo "  Installer version: v${INSTALLER_VERSION}"
    if [ -n "$CONSOLE_VERSION" ]; then
        echo "  Latest console:    ${CONSOLE_VERSION}"
    fi
    if [ -n "$AGENT_VERSION" ]; then
        echo "  Latest agent:      ${AGENT_VERSION}"
    fi

    echo ""
    echo "  Installation path: $INSTALL_DIR"
    echo ""
    echo "  What would you like to install?"
    echo "  1) Console with Agent (recommended)"
    echo "  2) Console only"
    echo "  3) Agent only"
    echo "  4) Exit"
    echo ""
    echo -n "  Select [1-4] (default 1): "
    read -r choice < /dev/tty 2>/dev/null || status_error "Failed to read input. Please run installer directly: bash install.sh"

    # Default to option 1 if empty or whitespace-only
    choice=$(echo "$choice" | tr -d '[:space:]')
    choice="${choice:-1}"

    case $choice in
        1)
            # Console with Agent
            echo ""
            DETECTED_HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
            [ -z "$DETECTED_HOST" ] && DETECTED_HOST="localhost"

            echo "  Enter hostname for agent connections"
            echo "  (This will be in invite URLs for remote agents to connect)"
            echo -n "  Hostname [$DETECTED_HOST]: "
            read -r USER_HOST < /dev/tty 2>/dev/null || true
            CONSOLE_HOST="${USER_HOST:-$DETECTED_HOST}"

            echo ""
            install_console "$CONSOLE_HOST"

            # Install agent with Docker network connection settings
            # Console container name: lumenmon-console (DNS-resolved by Docker)
            # Console SSH port inside container: 22 (not the mapped host port 2345!)
            # Agent and console communicate via shared "lumenmon-net" Docker network
            # External port mapping 2345:22 is only for connections from outside Docker
            install_agent "lumenmon-console" "22"

            # Wait for console SSH to be ready and accepting connections
            status_progress "Waiting for console SSH server..."
            for i in $(seq 1 30); do
                # Test SSH protocol handshake, not just port availability
                if docker exec lumenmon-console timeout 2 ssh -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=no localhost 2>&1 | grep -qE "Permission denied|publickey"; then
                    break
                fi
                sleep 1
            done
            sleep 1  # Small buffer for enrollment script to be ready

            # Generate invite for LOCAL agent using Docker network address
            # This invite contains: ssh://reg_xxx:pass@lumenmon-console:22/#hostkey
            # Why lumenmon-console:22? Because agent will connect via Docker network
            # - Agent runtime config: CONSOLE_HOST=lumenmon-console CONSOLE_PORT=22
            # - Registration saves known_hosts: [lumenmon-console]:22 ssh-ed25519 AAAA...
            # - Runtime connection: ssh lumenmon-console:22 → matches known_hosts ✓
            status_progress "Generating invite for local agent..."
            INVITE_URL=$(docker exec lumenmon-console /app/core/enrollment/invite_create.sh lumenmon-console 22 2>&1 | grep '^ssh://')

            if [ -n "$INVITE_URL" ]; then
                if register_agent "$INVITE_URL"; then
                    status_ok "Local agent connected!"
                else
                    status_warn "Auto-registration failed - use 'lumenmon invite' and 'lumenmon register' to connect manually"
                fi

                # Generate SECOND invite for REMOTE agents (with full install command)
                # This one uses external address from $CONSOLE_HOST for remote connectivity
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
            echo -n "  Hostname [$DETECTED_HOST]: "
            read -r USER_HOST < /dev/tty 2>/dev/null || true
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
            echo -n "  Enter console hostname: "
            read -r CONSOLE_HOST < /dev/tty 2>/dev/null || status_error "Failed to read input"
            echo -n "  Enter invite URL: "
            read -r INVITE_URL < /dev/tty 2>/dev/null || status_error "Failed to read input"

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
