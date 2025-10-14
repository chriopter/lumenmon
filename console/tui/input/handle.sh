#!/bin/bash
# Processes keyboard input and updates TUI state (navigation, view switching, actions).
# Handles dashboard navigation (↑↓), detail view (Enter/ESC), invites (i/c), refresh (r), quit (q). Sourced by tui.sh.
handle_input() {
    local key=$(read_key)

    # Skip if no key pressed
    [ -z "$key" ] && return

    # Global actions
    case "$key" in
        q|Q)
            # Quit
            quit_tui
            ;;
        r|R)
            # Refresh - just return to redraw
            return
            ;;
    esac

    # View-specific actions
    if [ "$STATE" = "dashboard" ]; then
        handle_dashboard_input "$key"
    elif [ "$STATE" = "detail" ]; then
        handle_detail_input "$key"
    fi
}

handle_dashboard_input() {
    local key=$1
    local agent_count=$(count_agents)

    case "$key" in
        UP)
            ((SELECTED_ROW--))
            [ $SELECTED_ROW -lt 0 ] && SELECTED_ROW=0
            ;;
        DOWN)
            ((SELECTED_ROW++))
            [ $SELECTED_ROW -ge $agent_count ] && SELECTED_ROW=$((agent_count - 1))
            [ $SELECTED_ROW -lt 0 ] && SELECTED_ROW=0
            ;;
        i|I)
            # Create invite
            /app/core/enrollment/invite_create.sh --full > /tmp/lumenmon_last_invite.txt 2>&1
            ;;
        c|C)
            # Copy invite (if any exists)
            if [ -f /tmp/lumenmon_last_invite.txt ]; then
                cat /tmp/lumenmon_last_invite.txt | head -1
            fi
            ;;
        ''|$'\n')
            # Enter - view detail
            if [ $agent_count -gt 0 ]; then
                SELECTED_AGENT=$(get_agents | sed -n "$((SELECTED_ROW + 1))p")
                STATE="detail"
            fi
            ;;
    esac
}

handle_detail_input() {
    local key=$1

    case "$key" in
        ESC)
            # Back to dashboard
            STATE="dashboard"
            ;;
    esac
}

quit_tui() {
    show_cursor
    clear_screen
    exit 0
}
