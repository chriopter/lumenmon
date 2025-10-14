#!/bin/bash
# Builds dashboard view as string buffer with agent list, metrics, pagination, and invites.
# Returns accumulated buffer string for single-write rendering. Sourced by tui.sh.

view_dashboard() {
    local buf=""

    # Header
    buf+="${CYAN}${BOLD}┌─ LUMENMON ─────────────────────────────────────────────────────────────────┐${NC}"$'\n'

    # Agents section
    buf+="${CYAN}├─ ${BOLD}AGENTS${NC}${CYAN} ────────────────────────────────────────────────────────────────────┤${NC}"$'\n'

    local agents=($(get_agents))
    local agent_count=${#agents[@]}

    if [ $agent_count -eq 0 ]; then
        buf+="${CYAN}│${NC} ${DIM}No agents registered yet${NC}                                                  ${CYAN}│${NC}"$'\n'
        buf+="${CYAN}│${NC} ${DIM}Use 'lumenmon invite' to create an enrollment invite${NC}                    ${CYAN}│${NC}"$'\n'
    else
        # Table header
        buf+="${CYAN}│${NC} ${DIM}   Status  Name                 Trend    CPU      Memory   Disk     Age ${CYAN}│${NC}"$'\n'
        buf+="${CYAN}├────────────────────────────────────────────────────────────────────────────┤${NC}"$'\n'

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

        # Draw visible agents (avoid subshells by using global ROW_BUFFER)
        local i=0
        for agent in "${agents[@]}"; do
            if [ $i -ge $start_idx ] && [ $i -lt $end_idx ]; then
                local selected=0
                [ $i -eq $SELECTED_ROW ] && selected=1
                build_agent_row "$agent" "$selected" "$i"
                buf+="$ROW_BUFFER"$'\n'
            fi
            ((i++))
        done

        # Show pagination indicator if needed
        if [ $agent_count -gt $max_visible ]; then
            local showing_start=$((start_idx + 1))
            local showing_end=$end_idx
            buf+="${CYAN}│${NC} ${DIM}Showing $showing_start-$showing_end of $agent_count agents${NC}                                          ${CYAN}│${NC}"$'\n'
        fi
    fi

    # Invites section
    buf+="${CYAN}├────────────────────────────────────────────────────────────────────────────┤${NC}"$'\n'
    local invite_count=$(get_invite_count)

    if [ $invite_count -gt 0 ]; then
        buf+="${CYAN}│${NC} ${YELLOW}🔑${NC} ${invite_count} active invite(s) - Press ${BOLD}c${NC} to copy install command                   ${CYAN}│${NC}"$'\n'
    else
        buf+="${CYAN}│${NC} ${DIM}No active invites - Press ${BOLD}i${NC}${DIM} to create one${NC}                                  ${CYAN}│${NC}"$'\n'
    fi

    # Footer
    buf+="${CYAN}└────────────────────────────────────────────────────────────────────────────┘${NC}"$'\n'
    buf+="${DIM}[↑↓] Navigate  [Enter] Detail  [i] Invite  [c] Copy  [r] Refresh  [q] Quit${NC}"$'\n'

    # Return buffer
    echo -n "$buf"
}
