#!/bin/bash
# Main dashboard view

view_dashboard() {
    clear_screen

    # Header
    draw_header

    # Agents section
    draw_section_header "AGENTS"

    local agents=($(get_agents))
    local agent_count=${#agents[@]}

    if [ $agent_count -eq 0 ]; then
        echo -e "${CYAN}│${NC} ${DIM}No agents registered yet${NC}                                                  ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${DIM}Use 'lumenmon invite' to create an enrollment invite${NC}                    ${CYAN}│${NC}"
    else
        # Table header
        echo -e "${CYAN}│${NC} ${DIM}   Status  Name                 Trend    CPU      Memory   Disk     Age ${CYAN}│${NC}"
        draw_divider

        # Draw each agent row
        local i=0
        for agent in "${agents[@]}"; do
            local selected=0
            [ $i -eq $SELECTED_ROW ] && selected=1
            draw_agent_row "$agent" "$selected" "$i"
            ((i++))
        done
    fi

    # Invites section
    draw_divider
    local invite_count=$(get_invite_count)

    if [ $invite_count -gt 0 ]; then
        echo -e "${CYAN}│${NC} ${YELLOW}🔑${NC} ${invite_count} active invite(s) - Press ${BOLD}c${NC} to copy install command                   ${CYAN}│${NC}"
    else
        echo -e "${CYAN}│${NC} ${DIM}No active invites - Press ${BOLD}i${NC}${DIM} to create one${NC}                                  ${CYAN}│${NC}"
    fi

    # Footer
    draw_footer "dashboard"
}
