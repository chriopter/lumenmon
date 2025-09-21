#!/bin/bash
# User interaction and menu selection

# Colors
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Global variables set by this module
COMPONENT=""
VERSION=""

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== Lumenmon Installer ===${NC}"
    echo ""
}

ask_what_to_install() {
    clear
    print_header

    # Redirect stdin to /dev/tty to read from terminal when piped
    exec < /dev/tty

    # Ask for component
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

    # Ask for version
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

    export COMPONENT VERSION
}