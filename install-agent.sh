#!/bin/bash
# Lumenmon Agent Installer - installs Glances with MQTT export for system monitoring.
# Detects OS, installs Glances natively, configures TLS certificate pinning, and starts systemd service.

set -e

# Version
AGENT_INSTALLER_VERSION="1.0.0"

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
    echo "  Agent Installer v${AGENT_INSTALLER_VERSION}"
    echo ""
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
    else
        status_error "Cannot detect OS - /etc/os-release not found"
    fi

    status_progress "Detected OS: $OS_ID $OS_VERSION"

    case "$OS_ID" in
        ubuntu|debian)
            PKG_MANAGER="apt"
            ;;
        *)
            status_error "Unsupported OS: $OS_ID (only Ubuntu/Debian supported for now)"
            ;;
    esac
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        status_error "This installer must be run as root (use sudo)"
    fi
}

# Parse invite URL
parse_invite() {
    local invite_url="$1"

    # Format: lumenmon://USERNAME:PASSWORD@HOST:PORT#FINGERPRINT
    if [[ "$invite_url" =~ ^lumenmon://([^:]+):([^@]+)@([^:#]+):([0-9]+)#(.+)$ ]]; then
        USERNAME="${BASH_REMATCH[1]}"
        PASSWORD="${BASH_REMATCH[2]}"
        MQTT_HOST="${BASH_REMATCH[3]}"
        MQTT_PORT="${BASH_REMATCH[4]}"
        FINGERPRINT="${BASH_REMATCH[5]}"
        status_ok "Parsed invite: $USERNAME@$MQTT_HOST:$MQTT_PORT"
    else
        status_error "Invalid invite URL format"
    fi
}

# Install Glances
install_glances() {
    status_progress "Installing Glances..."

    if command -v glances >/dev/null 2>&1; then
        status_ok "Glances already installed ($(glances --version | head -1))"
        return
    fi

    case "$PKG_MANAGER" in
        apt)
            apt-get update -qq
            apt-get install -y glances python3-paho-mqtt >/dev/null 2>&1
            ;;
    esac

    if command -v glances >/dev/null 2>&1; then
        status_ok "Glances installed: $(glances --version | head -1)"
    else
        status_error "Glances installation failed"
    fi
}

# Download and install server certificate
install_certificate() {
    status_progress "Downloading server certificate..."

    # Create config directory
    mkdir -p /etc/lumenmon

    # Download certificate from console
    if ! curl -fsSL -k "https://${MQTT_HOST}:${MQTT_PORT}/" --connect-timeout 5 2>&1 | \
         openssl s_client -connect "${MQTT_HOST}:${MQTT_PORT}" -showcerts 2>/dev/null | \
         openssl x509 -outform PEM > /etc/lumenmon/server.crt 2>/dev/null; then
        status_warn "Could not auto-download certificate, trying alternative method..."

        # Try with openssl directly
        timeout 5 openssl s_client -connect "${MQTT_HOST}:${MQTT_PORT}" -showcerts </dev/null 2>/dev/null | \
            sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' | head -n $(grep -n "END CERTIFICATE" | head -1 | cut -d: -f1) > /etc/lumenmon/server.crt
    fi

    if [ ! -s /etc/lumenmon/server.crt ]; then
        status_error "Failed to download server certificate from ${MQTT_HOST}:${MQTT_PORT}"
    fi

    # Verify certificate fingerprint
    DOWNLOADED_FP=$(openssl x509 -in /etc/lumenmon/server.crt -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)

    if [ "$DOWNLOADED_FP" = "$FINGERPRINT" ]; then
        status_ok "Certificate verified: $FINGERPRINT"
    else
        status_error "Certificate fingerprint mismatch!\n  Expected: $FINGERPRINT\n  Got: $DOWNLOADED_FP"
    fi

    # Add certificate to system trust store
    case "$PKG_MANAGER" in
        apt)
            cp /etc/lumenmon/server.crt /usr/local/share/ca-certificates/lumenmon-console.crt
            update-ca-certificates --fresh >/dev/null 2>&1
            ;;
    esac

    status_ok "Certificate installed and trusted"
}

# Create Glances configuration
create_glances_config() {
    status_progress "Creating Glances configuration..."

    cat > /etc/lumenmon/glances.conf <<EOF
[global]
check_update=false
refresh=3

[mqtt]
host=$MQTT_HOST
port=$MQTT_PORT
user=$USERNAME
password=$PASSWORD
topic=metrics/$USERNAME
topic_structure=per-metric
tls=true
callback_api_version=2
EOF

    chmod 600 /etc/lumenmon/glances.conf
    status_ok "Configuration saved to /etc/lumenmon/glances.conf"
}

# Create systemd service
create_systemd_service() {
    status_progress "Creating systemd service..."

    cat > /etc/systemd/system/lumenmon-agent.service <<EOF
[Unit]
Description=Lumenmon Agent (Glances MQTT Export)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/glances --quiet --export mqtt --conf /etc/lumenmon/glances.conf
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    status_ok "Systemd service created"
}

# Start and enable service
start_service() {
    status_progress "Starting lumenmon-agent service..."

    systemctl enable lumenmon-agent >/dev/null 2>&1
    systemctl start lumenmon-agent

    sleep 2

    if systemctl is-active --quiet lumenmon-agent; then
        status_ok "Service started and enabled"
    else
        status_error "Service failed to start - check: journalctl -u lumenmon-agent -n 50"
    fi
}

# Show completion message
show_completion() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ Lumenmon Agent installed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Agent ID: $USERNAME"
    echo "Console:  $MQTT_HOST:$MQTT_PORT"
    echo ""
    echo "Status:   systemctl status lumenmon-agent"
    echo "Logs:     journalctl -u lumenmon-agent -f"
    echo ""
    echo "The agent is now sending metrics to the console dashboard."
    echo ""
}

# Main installation flow
main() {
    show_logo
    check_root
    detect_os

    # Get invite URL
    if [ -z "$LUMENMON_INVITE" ]; then
        echo "  Enter invite URL from console (run 'lumenmon invite' on console):"
        echo -n "  Invite: "
        read -r INVITE_URL < /dev/tty 2>/dev/null || status_error "Failed to read input"
    else
        INVITE_URL="$LUMENMON_INVITE"
        status_ok "Using invite from environment"
    fi

    echo ""
    parse_invite "$INVITE_URL"

    echo ""
    install_glances
    install_certificate
    create_glances_config
    create_systemd_service
    start_service

    show_completion
}

# Run main installer
main
