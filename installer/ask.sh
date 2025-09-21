#!/bin/bash
# User interaction and menu selection

# Colors
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
DIM='\033[2m'
BOLD='\033[1m'
NC="${NC:-\033[0m}"

# Global variables set by this module
COMPONENT=""
VERSION=""

# Define print functions if not already available
if ! declare -f print_error &>/dev/null; then
    print_error() {
        echo -e "${RED}✗${NC} $1"
    }
fi

if ! declare -f print_info &>/dev/null; then
    print_info() {
        echo -e "${BLUE}→${NC} $1"
    }
fi

print_header() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
EOF
    echo -e "${NC}"
    echo -e "${BOLD}         LIGHTWEIGHT SYSTEM MONITORING SOLUTION${NC}"
    echo -e "${DIM}                    Version 1.0.0${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

ask_what_to_install() {
    print_header

    echo -e "${BOLD}Select an option:${NC}"
    echo ""
    echo "  1) Install Console (recommended)"
    echo "  2) Advanced options"
    echo "  3) Exit"
    echo ""

    # Read from terminal if we're piped
    if [ -t 0 ]; then
        read -p "> " choice
    else
        read -p "> " choice < /dev/tty
    fi

    case $choice in
        1)
            # Quick install console with latest version
            COMPONENT="console"
            VERSION="latest"
            ;;
        2)
            # Show advanced menu
            show_advanced_menu
            ;;
        3)
            echo ""
            echo "Installation cancelled."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    export COMPONENT VERSION
}

show_advanced_menu() {
    clear
    print_header

    echo -e "${BOLD}Advanced Installation Options:${NC}"
    echo ""
    echo -e "${YELLOW}Console:${NC}"
    echo "  1) Console - Latest release"
    echo "  2) Console - Development version"
    echo "  3) Console - Build from source"
    echo ""
    echo -e "${YELLOW}Agent:${NC}"
    echo "  4) Agent - Latest release"
    echo "  5) Agent - Development version"
    echo "  6) Agent - Build from source"
    echo ""
    echo "  7) Back to main menu"
    echo ""

    # Read from terminal if we're piped
    if [ -t 0 ]; then
        read -p "> " choice
    else
        read -p "> " choice < /dev/tty
    fi

    case $choice in
        1)
            COMPONENT="console"
            VERSION="latest"
            ;;
        2)
            COMPONENT="console"
            VERSION="dev"
            ;;
        3)
            COMPONENT="console"
            VERSION="local"
            ;;
        4)
            COMPONENT="agent"
            VERSION="latest"
            ;;
        5)
            COMPONENT="agent"
            VERSION="dev"
            ;;
        6)
            COMPONENT="agent"
            VERSION="local"
            ;;
        7)
            # Go back to main menu
            ask_what_to_install
            return
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}