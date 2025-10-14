#!/bin/bash
# Renders TUI header, section headers, dividers, and bottom border with box-drawing characters.
# Provides draw_header(), draw_section_header(), draw_divider(), draw_bottom(). Sourced by tui.sh.
draw_header() {
    local width=${1:-80}

    echo -e "${CYAN}${BOLD}┌─ LUMENMON ─────────────────────────────────────────────────────────────────┐${NC}"
}

draw_section_header() {
    local title="$1"
    echo -e "${CYAN}├─ ${BOLD}${title}${NC}${CYAN} ────────────────────────────────────────────────────────────────────┤${NC}"
}

draw_divider() {
    echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────────┤${NC}"
}

draw_bottom() {
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────────────┘${NC}"
}
