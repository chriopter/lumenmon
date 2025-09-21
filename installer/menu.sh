#!/bin/bash
# Simple interactive menu

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
            ;;
        2)
            COMPONENT="console"
            IMAGE="ghcr.io/chriopter/lumenmon-console:main"
            ;;
        3)
            COMPONENT="console"
            IMAGE=""
            ;;
        4)
            COMPONENT="agent"
            IMAGE="ghcr.io/chriopter/lumenmon-agent:latest"
            ;;
        5)
            COMPONENT="agent"
            IMAGE="ghcr.io/chriopter/lumenmon-agent:main"
            ;;
        6)
            COMPONENT="agent"
            IMAGE=""
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

# Export variables for deploy script
export COMPONENT IMAGE