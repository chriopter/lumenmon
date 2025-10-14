#!/bin/bash
# Renders main dashboard view with agent list, metrics table, pagination, and active invites.
# Shows header, up to 20 agents with sparklines/stats, pagination indicator, invite status, footer. Sourced by tui.sh.
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

        # Calculate pagination (show max 20 agents at a time)
        local max_visible=20
        local start_idx=0

        # Center selected row in view
        if [ $agent_count -gt $max_visible ]; then
            start_idx=$((SELECTED_ROW - max_visible / 2))
            [ $start_idx -lt 0 ] && start_idx=0
            [ $start_idx -gt $((agent_count - max_visible)) ] && start_idx=$((agent_count - max_visible))
        fi

        local end_idx=$((start_idx + max_visible))
        [ $end_idx -gt $agent_count ] && end_idx=$agent_count

        # Draw visible agents
        local i=0
        for agent in "${agents[@]}"; do
            if [ $i -ge $start_idx ] && [ $i -lt $end_idx ]; then
                local selected=0
                [ $i -eq $SELECTED_ROW ] && selected=1
                draw_agent_row "$agent" "$selected" "$i"
            fi
            ((i++))
        done

        # Show pagination indicator if needed
        if [ $agent_count -gt $max_visible ]; then
            local showing_start=$((start_idx + 1))
            local showing_end=$end_idx
            echo -e "${CYAN}│${NC} ${DIM}Showing $showing_start-$showing_end of $agent_count agents${NC}                                          ${CYAN}│${NC}"
        fi
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
