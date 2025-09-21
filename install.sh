#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_OWNER="${GITHUB_OWNER:-chriopter}"  # Replace with actual owner
REGISTRY="ghcr.io"

# Functions
print_header() {
    echo -e "${BLUE}=== Lumenmon Installer ===${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}→${NC} $1"
}

select_component() {
    echo "What to install?"
    echo "1) Console (monitoring dashboard)"
    echo "2) Agent (metrics collector)"
    echo "3) Exit"
    echo ""
    read -p "> " choice

    case $choice in
        1) COMPONENT="console" ;;
        2) COMPONENT="agent" ;;
        3) exit 0 ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
}

select_version() {
    echo ""
    echo "Which version?"
    echo "1) Stable (latest release)"
    echo "2) Dev (latest development)"
    echo "3) Local (build from source)"
    echo ""
    read -p "> " choice

    case $choice in
        1) VERSION="latest" ;;
        2) VERSION="dev" ;;
        3) VERSION="local" ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
}

install_component() {
    echo ""
    print_info "Installing ${COMPONENT} (${VERSION})..."

    cd $(dirname "$0")/${COMPONENT}

    if [ "$VERSION" = "local" ]; then
        print_info "Building from local source..."
        docker compose down 2>/dev/null || true
        docker compose up -d --build
    else
        print_info "Pulling from GHCR..."
        IMAGE="${REGISTRY}/${GITHUB_OWNER}/lumenmon-${COMPONENT}:${VERSION}"

        docker pull "$IMAGE"

        # Update docker-compose to use the pulled image
        export LUMENMON_IMAGE="$IMAGE"
        docker compose down 2>/dev/null || true
        docker compose up -d
    fi

    if [ $? -eq 0 ]; then
        print_success "Installation complete!"

        if [ "$COMPONENT" = "console" ]; then
            echo ""
            print_info "Console is running on port 2345"
            print_info "Create an invite: docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
            print_info "Access TUI: docker exec -it lumenmon-console python3 /app/tui/main.py"
        else
            echo ""
            print_info "Agent is running"
            print_info "Register with console using an invite URL"
            print_info "Check logs: docker logs lumenmon-agent"
        fi
    else
        print_error "Installation failed"
        exit 1
    fi
}

# Main
clear
print_header

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

# Check if we're in the right directory
if [ ! -d "console" ] || [ ! -d "agent" ]; then
    print_error "Please run this script from the lumenmon repository root"
    exit 1
fi

select_component
select_version
install_component

echo ""
print_success "Done!"