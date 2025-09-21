#!/bin/bash
# Interactive menu

source installer/logo.sh
source installer/status.sh

ask_console_host() {
    DETECTED_HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$DETECTED_HOST" ] && DETECTED_HOST="localhost"

    echo ""
    echo "  Enter the URL where agents can reach this console."
    echo -n "  Console host [$DETECTED_HOST]: "
    read -r USER_HOST < /dev/tty
    CONSOLE_HOST="${USER_HOST:-$DETECTED_HOST}"
}

ask_version() {
    echo ""
    echo "  Select Docker image:"
    echo "  1) Stable (recommended)"
    echo "  2) Latest builds"
    echo "  3) Build locally"
    echo -n "  Version [1]: "
    read -r VERSION_CHOICE < /dev/tty
    VERSION_CHOICE="${VERSION_CHOICE:-1}"

    case $VERSION_CHOICE in
        2)
            IMAGE="ghcr.io/chriopter/lumenmon-$1:dev"
            ;;
        3)
            IMAGE=""
            ;;
        *)
            IMAGE="ghcr.io/chriopter/lumenmon-$1:latest"
            ;;
    esac
}

show_menu() {
    clear
    show_logo
    echo ""

    echo "  1) Install Console"
    echo "  2) Install Agent"
    echo "  3) Uninstall"
    echo "  4) Exit"
    echo ""

    read -r -p "  Select [1-4]: " choice < /dev/tty

    case $choice in
        1)
            ask_console_host
            ask_version "console"
            export CONSOLE_HOST IMAGE
            source installer/console.sh
            ;;
        2)
            ask_version "agent"
            export IMAGE
            source installer/agent.sh
            ;;
        3)
            source installer/uninstall.sh
            ;;
        4)
            exit 0
            ;;
        *)
            status_error "Invalid choice"
            sleep 1
            show_menu
            ;;
    esac
}

