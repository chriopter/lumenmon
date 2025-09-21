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

show_menu() {
    clear
    show_logo
    echo ""

    echo "  1) Install Console"
    echo "  2) Advanced"
    echo "  3) Uninstall"
    echo "  4) Exit"
    echo ""

    read -r -p "  Select [1-4]: " choice < /dev/tty

    case $choice in
        1)
            ask_console_host
            IMAGE=""
            export CONSOLE_HOST IMAGE
            source installer/console.sh
            ;;
        2)
            show_advanced
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

show_advanced() {
    clear
    show_logo
    echo ""
    echo -e "  \033[1mAdvanced Options:\033[0m"
    echo ""
    echo "  Console versions:"
    echo "  1) Latest release"
    echo "  2) Development version"
    echo "  3) Build from source"
    echo ""
    echo "  4) Back"
    echo ""

    read -r -p "  Select [1-4]: " choice < /dev/tty

    case $choice in
        1)
            ask_console_host
            IMAGE="ghcr.io/chriopter/lumenmon-console:latest"
            export CONSOLE_HOST IMAGE
            source installer/console.sh
            ;;
        2)
            ask_console_host
            IMAGE="ghcr.io/chriopter/lumenmon-console:main"
            export CONSOLE_HOST IMAGE
            source installer/console.sh
            ;;
        3)
            ask_console_host
            IMAGE=""
            export CONSOLE_HOST IMAGE
            source installer/console.sh
            ;;
        4)
            show_menu
            ;;
        *)
            status_error "Invalid choice"
            sleep 1
            show_advanced
            ;;
    esac
}