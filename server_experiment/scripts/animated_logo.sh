#!/bin/bash
# Simple LUMENMON logo display - no animations to avoid jumping

# Colors
GLOW_GREEN="\033[38;5;46m"
GLOW_CYAN="\033[38;5;51m"
RESET="\033[0m"
BOLD="\033[1m"

# Display logo instantly - no animation
animate_logo_build() {
    # Clear screen and hide cursor
    clear
    echo -ne "\033[?25l"
    
    # Print the complete logo instantly
    echo -e "${GLOW_CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GLOW_CYAN}║${GLOW_GREEN}${BOLD}  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗${RESET}${GLOW_CYAN}║${RESET}"
    echo -e "${GLOW_CYAN}║${GLOW_GREEN}${BOLD}  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║${RESET}${GLOW_CYAN}║${RESET}"
    echo -e "${GLOW_CYAN}║${GLOW_GREEN}${BOLD}  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║${RESET}${GLOW_CYAN}║${RESET}"
    echo -e "${GLOW_CYAN}║${GLOW_GREEN}${BOLD}  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║${RESET}${GLOW_CYAN}║${RESET}"
    echo -e "${GLOW_CYAN}║${GLOW_GREEN}${BOLD}  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║${RESET}${GLOW_CYAN}║${RESET}"
    echo -e "${GLOW_CYAN}║${GLOW_GREEN}${BOLD}  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝${RESET}${GLOW_CYAN}║${RESET}"
    echo -e "${GLOW_CYAN}║                    [ SYSTEM MONITORING TERMINAL v4.2.0 ]                       ║${RESET}"
    echo -e "${GLOW_CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    
    # Show cursor again
    echo -ne "\033[?25h"
}

# Simple message display - no effects
type_message() {
    local message="$1"
    local color="${2:-$GLOW_GREEN}"
    
    # Just print the message instantly
    echo -e "${color}${message}${RESET}"
}

# Main sequence - simplified
show_logo_animation() {
    # Display the logo
    animate_logo_build
    
    # Display system messages
    echo ""
    type_message "▶ INITIALIZING LUMENMON SYSTEM..." "$GLOW_CYAN"
    type_message "  ✓ Terminal Connected" "$GLOW_GREEN"
    type_message "  ✓ Database Link Established" "$GLOW_GREEN"
    type_message "  ✓ Security Protocols Active" "$GLOW_GREEN"
    echo ""
    type_message "◉ STATUS: MONITORING ALL SYSTEMS" "$GLOW_CYAN"
    
    # Brief pause before main TUI
    sleep 0.2
}

# Export for use in other scripts
export -f animate_logo_build
export -f type_message
export -f show_logo_animation