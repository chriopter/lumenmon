#!/bin/bash
# Simple interactive menu

ask_console_host() {
    # Auto-detect and ask for console host
    DETECTED_HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$DETECTED_HOST" ] && DETECTED_HOST="localhost"

    echo ""
    echo "  Auto-detected: $DETECTED_HOST"
    echo "  Enter the URL where agents can reach this console."
    read -p "  Console host [$DETECTED_HOST]: " USER_HOST
    CONSOLE_HOST="${USER_HOST:-$DETECTED_HOST}"
    export CONSOLE_HOST
}

show_menu() {
    clear

    # Logo
    echo -e "\033[0;36m"
    echo "  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗"
    echo "  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║"
    echo "  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║"
    echo "  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║"
    echo "  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
    echo "  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "\033[0m"
    echo ""

    echo "  1) Install Console"
    echo "  2) Advanced"
    echo "  3) Exit"
    echo ""

    read -p "  Select [1-3]: " choice < /dev/tty 2>/dev/null || read -p "  Select [1-3]: " choice

    case $choice in
        1)
            COMPONENT="console"
            IMAGE=""
            ask_console_host
            export COMPONENT IMAGE
            ;;
        2)
            show_advanced
            ;;
        3)
            exit 0
            ;;
        *)
            echo "  Invalid choice"
            sleep 1
            show_menu
            ;;
    esac
}

show_advanced() {
    clear

    # Logo
    echo -e "\033[0;36m"
    echo "  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗"
    echo "  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║"
    echo "  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║"
    echo "  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║"
    echo "  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
    echo "  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "\033[0m"
    echo ""

    echo -e "  \033[1mAdvanced Options:\033[0m"
    echo ""
    echo "  1) Console - Latest"
    echo "  2) Console - Dev"
    echo "  3) Console - Build local"
    echo ""
    echo "  4) Agent - Latest"
    echo "  5) Agent - Dev"
    echo "  6) Agent - Build local"
    echo ""
    echo "  7) Back"
    echo ""

    read -p "  Select [1-7]: " choice < /dev/tty 2>/dev/null || read -p "  Select [1-7]: " choice

    case $choice in
        1)
            COMPONENT="console"
            IMAGE="ghcr.io/chriopter/lumenmon-console:latest"
            ask_console_host
            export COMPONENT IMAGE
            ;;
        2)
            COMPONENT="console"
            IMAGE="ghcr.io/chriopter/lumenmon-console:main"
            ask_console_host
            export COMPONENT IMAGE
            ;;
        3)
            COMPONENT="console"
            IMAGE=""
            ask_console_host
            export COMPONENT IMAGE
            ;;
        4)
            COMPONENT="agent"
            IMAGE="ghcr.io/chriopter/lumenmon-agent:latest"
            export COMPONENT IMAGE
            ;;
        5)
            COMPONENT="agent"
            IMAGE="ghcr.io/chriopter/lumenmon-agent:main"
            export COMPONENT IMAGE
            ;;
        6)
            COMPONENT="agent"
            IMAGE=""
            export COMPONENT IMAGE
            ;;
        7)
            show_menu
            ;;
        *)
            echo "  Invalid choice"
            sleep 1
            show_advanced
            ;;
    esac
}