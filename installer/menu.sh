#!/bin/bash
# Interactive installer

show_menu() {
    clear

    # Show logo in cyan
    echo -e "\033[0;36m"
    echo "  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗"
    echo "  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║"
    echo "  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║"
    echo "  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║"
    echo "  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
    echo "  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "\033[0m"
    echo -e "  \033[1mLightweight System Monitoring Solution\033[0m"
    echo ""
    echo -e "\033[0;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""

    # Check if console is already installed
    if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^lumenmon-console$"; then
        # Console exists
        if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^lumenmon-console$"; then
            echo -e "  \033[0;32m✓ Console is installed and running!\033[0m"
            echo ""
            echo -e "  Would you like to:"
            echo -e "    \033[1mr\033[0m) Reinstall console"
            echo -e "    \033[1mt\033[0m) View TUI dashboard"
            echo -e "    \033[1mi\033[0m) Create new invite"
            echo -e "    \033[1ma\033[0m) Advanced options"
            echo -e "    \033[1mx\033[0m) Exit"
            echo ""
            echo -n "  Enter choice [t]: "
            read -r choice < /dev/tty 2>/dev/null || read -r choice

            case "${choice:-t}" in
                r|R)
                    echo ""
                    echo -n "  This will stop the current console. Continue? [y/N]: "
                    read -r confirm < /dev/tty 2>/dev/null || read -r confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        COMPONENT="console"
                    else
                        exit 0
                    fi
                    ;;
                t|T|"")
                    docker exec -it lumenmon-console python3 /app/tui/main.py
                    exit 0
                    ;;
                i|I)
                    docker exec lumenmon-console /app/core/enrollment/invite_create.sh
                    exit 0
                    ;;
                a|A)
                    show_advanced
                    ;;
                x|X)
                    exit 0
                    ;;
                *)
                    echo "  Invalid choice"
                    exit 1
                    ;;
            esac
        else
            echo -e "  \033[0;33m⚠ Console is installed but stopped\033[0m"
            echo ""
            echo -n "  Start console? [Y/n]: "
            read -r choice < /dev/tty 2>/dev/null || read -r choice

            if [[ ! "$choice" =~ ^[Nn]$ ]]; then
                docker start lumenmon-console
                echo -e "\n  \033[0;32m✓ Console started!\033[0m"
                sleep 2
                source "$DIR/installer/finish.sh"
            fi
            exit 0
        fi
    else
        # Console not installed
        echo -e "  Welcome! Ready to install Lumenmon Console?"
        echo ""
        echo -e "  The console is your central monitoring dashboard that:"
        echo -e "    • Manages agent connections"
        echo -e "    • Displays real-time metrics"
        echo -e "    • Provides a beautiful TUI interface"
        echo ""
        echo -n "  Install console now? [Y/n]: "
        read -r choice < /dev/tty 2>/dev/null || read -r choice

        if [[ "$choice" =~ ^[Nn]$ ]]; then
            echo ""
            echo -n "  Show advanced options? [y/N]: "
            read -r adv < /dev/tty 2>/dev/null || read -r adv
            if [[ "$adv" =~ ^[Yy]$ ]]; then
                show_advanced
            else
                echo ""
                echo "  Installation cancelled."
                exit 0
            fi
        else
            COMPONENT="console"
        fi
    fi

    export COMPONENT
}

show_advanced() {
    clear
    echo ""
    echo "  Advanced Options:"
    echo ""
    echo "  1) Agent - Latest"
    echo "  2) Agent - Dev"
    echo "  3) Agent - Build from source"
    echo ""
    echo "  4) Console - Latest"
    echo "  5) Console - Dev"
    echo "  6) Console - Build from source"
    echo ""
    echo "  7) Back"
    echo ""
    read -p "  > " choice

    case $choice in
        1) COMPONENT="agent"; IMAGE="ghcr.io/chriopter/lumenmon-agent:latest" ;;
        2) COMPONENT="agent"; IMAGE="ghcr.io/chriopter/lumenmon-agent:main" ;;
        3) COMPONENT="agent"; IMAGE="" ;;
        4) COMPONENT="console"; IMAGE="ghcr.io/chriopter/lumenmon-console:latest" ;;
        5) COMPONENT="console"; IMAGE="ghcr.io/chriopter/lumenmon-console:main" ;;
        6) COMPONENT="console"; IMAGE="" ;;
        7) show_menu; return ;;
        *) echo "Invalid"; exit 1 ;;
    esac

    export COMPONENT IMAGE
}