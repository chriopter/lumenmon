#!/bin/bash
# Processes keyboard input and updates global state arrays for navigation and view switching.
# Handles dashboard navigation (↑↓), detail view (Enter/ESC), invites, refresh, quit. Sourced by tui.sh.
handle_input() {
    local key=$(read_key)

    # Skip if no key pressed
    [ -z "$key" ] && return

    # Track input time for deferred refresh
    LAST_INPUT_TIME=$SECONDS

    # Global actions
    case "$key" in
        q|Q)
            # Quit
            return 1  # Signal event loop to exit
            ;;
        r|R)
            # Refresh - trigger data reload
            NEEDS_REFRESH=1
            NEEDS_RENDER=1
            return 0
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
            PREV_SELECTED_ROW=$SELECTED_ROW
            ((SELECTED_ROW--))
            [ $SELECTED_ROW -lt 0 ] && SELECTED_ROW=0

            # Differential update - only redraw changed rows
            update_selection "$PREV_SELECTED_ROW" "$SELECTED_ROW"
            ;;
        DOWN)
            PREV_SELECTED_ROW=$SELECTED_ROW
            ((SELECTED_ROW++))
            [ $SELECTED_ROW -ge $agent_count ] && SELECTED_ROW=$((agent_count - 1))
            [ $SELECTED_ROW -lt 0 ] && SELECTED_ROW=0

            # Differential update - only redraw changed rows
            update_selection "$PREV_SELECTED_ROW" "$SELECTED_ROW"
            ;;
        i|I)
            # Create invite - needs full redraw
            /app/core/enrollment/invite_create.sh --full > /tmp/lumenmon_last_invite.txt 2>&1
            NEEDS_REFRESH=1
            NEEDS_RENDER=1
            ;;
        c|C)
            # Copy invite (if any exists)
            if [ -f /tmp/lumenmon_last_invite.txt ]; then
                cat /tmp/lumenmon_last_invite.txt | head -1
            fi
            ;;
        ''|$'\n')
            # Enter - view detail (full redraw)
            if [ $agent_count -gt 0 ]; then
                SELECTED_AGENT=$(get_agents | sed -n "$((SELECTED_ROW + 1))p")
                STATE="detail"
                NEEDS_RENDER=1
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
            NEEDS_RENDER=1
            ;;
    esac
}
