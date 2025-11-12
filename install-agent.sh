#!/bin/bash
# Lumenmon Client Installer - configures Glances to connect to Lumenmon console.
# Installs Glances (nicolargo/glances) via system package manager and sets up MQTT connection.

set -e

# ============================================================================
# WELCOME
# ============================================================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

ok() { echo -e "[${GREEN}✓${RESET}] $1"; }
err() { echo -e "[${RED}✗${RESET}] $1"; exit 1; }
info() { echo -e "[${CYAN}→${RESET}] $1"; }

# Logo
clear 2>/dev/null || true
echo -e "${CYAN}"
echo "  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗"
echo "  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║"
echo "  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║"
echo "  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║"
echo "  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
echo "  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
echo -e "${RESET}"
echo "  Glances → Lumenmon Connector"
echo ""

# Check root
[ "$EUID" -ne 0 ] && err "Run as root: sudo bash install-agent.sh"

# Check if already installed
if [ -f /etc/lumenmon/glances.conf ] || [ -f /etc/systemd/system/lumenmon-agent.service ]; then
    echo ""
    echo -e "${RED}⚠ WARNING: Lumenmon client already installed!${RESET}"
    echo ""
    echo "Existing installation detected:"
    [ -f /etc/lumenmon/glances.conf ] && echo "  • Config: /etc/lumenmon/glances.conf"
    [ -f /etc/systemd/system/lumenmon-agent.service ] && echo "  • Service: lumenmon-agent.service"
    echo ""
    echo "Re-running this installer will:"
    echo "  • Replace configuration (disconnect from current console)"
    echo "  • Update MQTT credentials (old invite will stop working)"
    echo "  • Restart the service"
    echo ""
    echo -n "Continue anyway? [y/N]: "
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    echo ""
fi

# Get invite URL
INVITE="${LUMENMON_INVITE:-}"
if [ -z "$INVITE" ]; then
    echo -n "Enter invite URL: "
    read -r INVITE
fi

# Parse invite: lumenmon://USER:PASS@HOST:PORT#FINGERPRINT
if [[ "$INVITE" =~ ^lumenmon://([^:]+):([^@]+)@([^:#]+):([0-9]+)#(.+)$ ]]; then
    USER="${BASH_REMATCH[1]}"
    PASS="${BASH_REMATCH[2]}"
    HOST="${BASH_REMATCH[3]}"
    PORT="${BASH_REMATCH[4]}"
    FP="${BASH_REMATCH[5]}"
else
    err "Invalid invite URL"
fi

echo ""
ok "Invite: $USER@$HOST:$PORT"
echo ""

# ============================================================================
# DETECT OS
# ============================================================================

info "Detecting operating system..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION="$VERSION_ID"
    ok "Detected: $OS_ID $OS_VERSION"
else
    err "Cannot detect OS - /etc/os-release not found"
fi

echo ""

# ============================================================================
# INSTALL (by OS)
# ============================================================================

case "$OS_ID" in
    ubuntu|debian)
        info "Installing Glances via apt..."
        apt-get update -qq
        apt-get install -y glances python-paho-mqtt >/dev/null 2>&1
        ok "Glances installed: $(glances --version | head -1)"
        ;;

    arch|manjaro)
        info "Installing Glances via pacman..."
        pacman -Sy --noconfirm glances python-paho-mqtt >/dev/null 2>&1
        ok "Glances installed: $(glances --version | head -1)"
        ;;

    *)
        err "Unsupported OS: $OS_ID (supported: Ubuntu, Debian, Arch, Manjaro)"
        ;;
esac

echo ""

# Download & verify certificate
info "Downloading server certificate..."
mkdir -p /etc/lumenmon
timeout 5 openssl s_client -connect "$HOST:$PORT" </dev/null 2>/dev/null | \
    sed -n '/BEGIN CERT/,/END CERT/p' > /etc/lumenmon/server.crt

DOWNLOADED_FP=$(openssl x509 -in /etc/lumenmon/server.crt -noout -fingerprint -sha256 | cut -d= -f2)
[ "$DOWNLOADED_FP" = "$FP" ] || err "Certificate fingerprint mismatch!"

# Add to system trust store (OS-specific)
case "$OS_ID" in
    ubuntu|debian)
        cp /etc/lumenmon/server.crt /usr/local/share/ca-certificates/lumenmon.crt
        update-ca-certificates >/dev/null 2>&1
        ;;
    arch|manjaro)
        cp /etc/lumenmon/server.crt /etc/ca-certificates/trust-source/anchors/lumenmon.crt
        trust extract-compat >/dev/null 2>&1
        ;;
esac
ok "Certificate verified & trusted"

# Create config
info "Creating Glances configuration..."
cat > /etc/lumenmon/glances.conf <<EOF
[global]
check_update=false
refresh=3

[outputs]
# Disable all output modules (web server, API, etc.)
curse=false
webserver=false

[mqtt]
host=$HOST
port=$PORT
user=$USER
password=$PASS
topic=metrics/$USER
topic_structure=per-metric
tls=true
callback_api_version=2
EOF
chmod 600 /etc/lumenmon/glances.conf
ok "Configuration saved"

# Create systemd service
info "Creating systemd service..."
cat > /etc/systemd/system/lumenmon-agent.service <<EOF
[Unit]
Description=Lumenmon Agent (Glances MQTT Export)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
# Runs in standalone export mode (no ports opened, push-only to MQTT broker)
ExecStart=/usr/bin/glances --quiet --export mqtt --conf /etc/lumenmon/glances.conf
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable lumenmon-agent >/dev/null 2>&1
systemctl start lumenmon-agent
ok "Service started"

# ============================================================================
# COMPLETE
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Glances connected to Lumenmon!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Agent ID:  $USER"
echo "  Console:   $HOST:$PORT"
echo "  Glances:   $(glances --version | head -1)"
echo ""
echo "  Status:    systemctl status lumenmon-agent"
echo "  Logs:      journalctl -u lumenmon-agent -f"
echo ""
