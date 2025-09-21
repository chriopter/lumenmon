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
    echo ""

    # Check if console is already installed
    if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^lumenmon-console$"; then
        if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^lumenmon-console$"; then
            echo -e "  \033[0;32m✓ Console is running\033[0m"
        else
            echo -e "  \033[0;33m⚠ Console is stopped\033[0m"
        fi
        echo ""
        echo -n "  Reinstall console? [y/N]: "
    else
        echo "  Welcome to Lumenmon installer!"
        echo ""
        echo -n "  Install console? [Y/n]: "
    fi

    read -r choice < /dev/tty 2>/dev/null || read -r choice

    # Check the response based on context
    if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^lumenmon-console$"; then
        # Already installed - default is NO
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            COMPONENT="console"
        else
            exit 0
        fi
    else
        # Not installed - default is YES
        if [[ "$choice" =~ ^[Nn]$ ]]; then
            exit 0
        else
            COMPONENT="console"
        fi
    fi

    export COMPONENT
}