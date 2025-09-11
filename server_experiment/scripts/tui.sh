#!/bin/bash
# Main TUI script for Lumenmon using gum

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper scripts
source "$SCRIPT_DIR/db_query.sh"
source "$SCRIPT_DIR/display_metrics.sh"
source "$SCRIPT_DIR/charts.sh"
source "$SCRIPT_DIR/gum_components.sh"
source "$SCRIPT_DIR/animated_logo.sh"

# Configuration
REFRESH_RATE=${REFRESH_RATE:-5}
AUTO_REFRESH=${AUTO_REFRESH:-true}

# Clear screen and reset cursor
clear_screen() {
    # Fast clear with no delay
    printf "\033[2J\033[H"
}

# Main menu with enhanced Gum styling
show_main_menu() {
    local choice
    
    while true; do
        clear_screen
        
        # Show the awesome 80s ASCII logo
        animate_logo_build
        
        # Get fleet statistics with loading animation
        local stats=$(gum spin --spinner dot --title "Loading fleet status..." \
            --spinner.foreground="46" -- bash -c "get_fleet_stats")
        IFS='|' read -r total online avg_cpu avg_mem <<< "$stats"
        
        # Display fleet stats with style
        display_fleet_stats "$total" "$online" "$avg_cpu" "$avg_mem"
        
        # Check for pending registrations
        local pending_count=$(get_pending_registrations | wc -l)
        if [ $pending_count -gt 0 ]; then
            show_alert "warning" "$pending_count pending registration(s) awaiting approval"
        fi
        
        show_divider "double" "212"
        
        # Show clients inline with main menu
        echo ""
        show_divider "double" "46"
        echo ""
        
        # Display all clients right here with 80s style
        echo ""
        gum style \
            --foreground 51 \
            --bold=true \
            --align center \
            "◄══════ CONNECTED CLIENTS ══════►"
        echo ""
        
        while IFS='|' read -r id hostname last_seen fingerprint; do
            # Get client stats
            IFS='|' read -r cpu mem load uptime <<< "$(get_client_stats "$id")"
            
            # Check if online
            if is_client_online "$id"; then
                online="true"
            else
                online="false"
            fi
            
            display_client_row "$id" "$hostname" "$cpu" "$mem" "$load" "$online"
        done < <(get_clients)
        
        echo ""
        show_divider "single" "241"
        
        # Simplified menu options
        local options=(
            "🔍 Search & Select Client"
            "⚠️  Pending Registrations [$pending_count]"
            "📈 Fleet Analytics Dashboard"
            "⚙️  Settings (Refresh: ${REFRESH_RATE}s)"
            "🔄 Refresh Now"
            "🚪 Exit"
        )
        
        # Fancy menu selection with neon styling
        echo ""
        choice=$(gum choose \
            --cursor "▶ " \
            --cursor.foreground="201" \
            --selected.foreground="46" \
            --header "═══ MAIN MENU ═══" \
            --header.foreground="226" \
            --height 8 \
            "${options[@]}")
        
        # Handle auto-refresh
        if [ "$AUTO_REFRESH" = "true" ] && [ -z "$choice" ]; then
            transition
            continue
        fi
        
        case "$choice" in
            *"Search & Select Client")
                select_client_menu_enhanced
                ;;
            *"Pending Registrations"*)
                manage_pending_registrations
                ;;
            *"Fleet Analytics"*)
                show_fleet_analytics_enhanced
                ;;
            *"Settings"*)
                show_settings_menu
                ;;
            *"Refresh Now")
                show_toast "Refreshing..." 1
                continue
                ;;
            *"Exit")
                if confirm_action "Are you sure you want to exit?"; then
                    clear_screen
                    show_alert "info" "Goodbye! Thank you for using Lumenmon."
                    exit 0
                fi
                ;;
        esac
    done
}

# Show all clients
show_all_clients() {
    clear_screen
    animate_logo_build
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           CONNECTED CLIENTS                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Get all clients and display
    while IFS='|' read -r id hostname last_seen fingerprint; do
        # Get client stats
        IFS='|' read -r cpu mem load uptime <<< "$(get_client_stats "$id")"
        
        # Check if online
        if is_client_online "$id"; then
            online="true"
        else
            online="false"
        fi
        
        display_client_row "$id" "$hostname" "$cpu" "$mem" "$load" "$online"
    done < <(get_clients)
    
    echo ""
    gum confirm "Return to main menu?" && return
}

# Enhanced searchable client selection
select_client_menu_enhanced() {
    clear_screen
    show_header
    
    # Loading animation while fetching clients
    show_toast "Loading client list..." 1
    
    # Build client list for selection
    local clients=()
    local client_map=()
    
    while IFS='|' read -r id hostname last_seen fingerprint; do
        # Get basic stats
        cpu=$(get_metric "$id" "generic_cpu_usage")
        mem=$(get_metric "$id" "generic_memory_percent")
        
        local status_icon
        local status_color
        if is_client_online "$id"; then
            status_icon="🔵"
            status_color="online"
        else
            status_icon="🔴"
            status_color="offline"
        fi
        
        # Format: emoji hostname [CPU/MEM] status
        clients+=("$status_icon $hostname │ CPU:${cpu%.*}% MEM:${mem%.*}% │ $status_color")
        client_map+=("$id|$hostname")
    done < <(get_clients)
    
    if [ ${#clients[@]} -eq 0 ]; then
        show_alert "warning" "No clients available"
        sleep 2
        return
    fi
    
    # Use searchable list with filter
    local selected=$(show_searchable_list "SELECT CLIENT" "Type to search clients..." "${clients[@]}")
    
    if [ -n "$selected" ]; then
        # Find the selected client ID
        local index=0
        for client in "${clients[@]}"; do
            if [ "$client" = "$selected" ]; then
                IFS='|' read -r client_id hostname <<< "${client_map[$index]}"
                
                # Transition animation
                gum spin --spinner meter --title "Loading $hostname details..." \
                    --spinner.foreground="212" -- sleep 0.5
                    
                show_client_details_enhanced "$client_id" "$hostname"
                break
            fi
            ((index++))
        done
    fi
}

# Keep old function for compatibility
select_client_menu() {
    select_client_menu_enhanced
}

# Enhanced client details with rich Gum components
show_client_details_enhanced() {
    local client_id=$1
    local hostname=$2
    
    while true; do
        clear_screen
        
        # Fancy client header
        gum style \
            --foreground 212 \
            --border double \
            --border-foreground 212 \
            --padding "1 2" \
            --margin "1" \
            --align center \
            --bold=true \
            "🕸️ CLIENT: $hostname" \
            "ID: $client_id"
        
        # Get metrics with spinner
        local cpu=$(gum spin --spinner pulse --title "Fetching metrics..." \
            --spinner.foreground="46" -- bash -c "get_metric $client_id 'generic_cpu_usage'")
        local mem=$(get_metric "$client_id" "generic_memory_percent")
        local load=$(get_metric "$client_id" "generic_cpu_load")
        
        # Display metrics in styled boxes
        echo ""
        gum join --horizontal \
            "$(show_kv 'CPU Usage' "${cpu%.*}%" 214 46)" \
            "$(show_kv 'Memory' "${mem%.*}%" 214 46)" \
            "$(show_kv 'Load' "$load" 214 46)"
        
        echo ""
        show_divider "thick" "51"
        
        # Time series with loading
        gum spin --spinner dots --title "Generating charts..." \
            --spinner.foreground="212" -- sleep 0.3
            
        # Get time series data
        local cpu_data=$(get_time_series "$client_id" "generic_cpu_usage" "-1 hour")
        local mem_data=$(get_time_series "$client_id" "generic_memory_percent" "-1 hour")
        
        # Display charts
        generate_ascii_chart "CPU Usage (Last Hour)" "$cpu_data"
        echo ""
        generate_ascii_chart "Memory Usage (Last Hour)" "$mem_data"
        
        echo ""
        show_divider "single" "241"
        
        # Enhanced options menu
        local options=(
            "📋 Show Raw Metrics"
            "🔄 Refresh Data"
            "🎨 Change View"
            "⬅️  Back to Main Menu"
        )
        
        local choice=$(show_menu "CLIENT ACTIONS" "${options[@]}")
        
        case "$choice" in
            *"Show Raw Metrics")
                show_raw_metrics_enhanced "$client_id"
                ;;
            *"Refresh Data")
                show_toast "Refreshing..." 1
                continue
                ;;
            *"Change View")
                select_view_type
                ;;
            *"Back to Main Menu")
                return
                ;;
        esac
    done
}

# Keep old function for compatibility
show_client_details() {
    show_client_details_enhanced "$1" "$2"
}

# Enhanced raw metrics display
show_raw_metrics_enhanced() {
    local client_id=$1
    
    clear_screen
    
    gum style \
        --foreground 46 \
        --border normal \
        --border-foreground 46 \
        --padding "1 2" \
        --margin "1" \
        "RAW METRICS - Client $client_id"
    
    # Fetch data with spinner
    local data=$(gum spin --spinner line --title "Querying database..." \
        --spinner.foreground="212" -- sqlite3 -column -header "$DB_PATH" "
        SELECT 
            datetime(timestamp, 'localtime') as time,
            metric_name as metric,
            ROUND(metric_value, 2) as value
        FROM metrics_${client_id}
        ORDER BY timestamp DESC
        LIMIT 50" 2>/dev/null)
    
    # Display in styled pager
    echo "$data" | gum pager \
        --border-foreground="241" \
        --help.foreground="214"
}

# Keep old function
show_raw_metrics() {
    show_raw_metrics_enhanced "$1"
}

# Manage pending registrations
manage_pending_registrations() {
    clear_screen
    display_header
    
    echo ""
    gum style \
        --foreground 226 \
        --border double \
        --border-foreground 226 \
        --padding "1 2" \
        --align center \
        "PENDING REGISTRATIONS"
    
    local pending=$(get_pending_registrations)
    
    if [ -z "$pending" ]; then
        echo ""
        gum style --foreground 46 "No pending registrations"
        sleep 2
        return
    fi
    
    # Display pending registrations
    echo ""
    echo "Fingerprint                                      | Hostname        | Attempts"
    echo "────────────────────────────────────────────────┼─────────────────┼──────────"
    
    while IFS='|' read -r fingerprint hostname first_seen attempts; do
        printf "%-48s | %-15s | %s\n" \
            "${fingerprint:0:48}" "$hostname" "$attempts"
    done <<< "$pending"
    
    echo ""
    
    # Select action
    local action=$(gum choose \
        "Approve a Client" \
        "Reject a Client" \
        "Back to Main Menu" \
        --header "Select an action:")
    
    case "$action" in
        "Approve a Client")
            approve_client_interactive
            ;;
        "Reject a Client")
            reject_client_interactive
            ;;
        "Back to Main Menu")
            return
            ;;
    esac
}

# Interactive client approval
approve_client_interactive() {
    local fingerprints=()
    local hostnames=()
    
    while IFS='|' read -r fingerprint hostname first_seen attempts; do
        fingerprints+=("$fingerprint")
        hostnames+=("$hostname - ${fingerprint:0:20}...")
    done < <(get_pending_registrations)
    
    if [ ${#fingerprints[@]} -eq 0 ]; then
        return
    fi
    
    local selected=$(printf '%s\n' "${hostnames[@]}" | \
        gum choose --header "Select client to approve:")
    
    if [ -n "$selected" ]; then
        # Find the fingerprint
        local index=0
        for host in "${hostnames[@]}"; do
            if [ "$host" = "$selected" ]; then
                if approve_client "${fingerprints[$index]}"; then
                    gum style --foreground 46 "✓ Client approved successfully"
                else
                    gum style --foreground 196 "✗ Failed to approve client"
                fi
                sleep 2
                break
            fi
            ((index++))
        done
    fi
}

# Interactive client rejection
reject_client_interactive() {
    local fingerprints=()
    local hostnames=()
    
    while IFS='|' read -r fingerprint hostname first_seen attempts; do
        fingerprints+=("$fingerprint")
        hostnames+=("$hostname - ${fingerprint:0:20}...")
    done < <(get_pending_registrations)
    
    if [ ${#fingerprints[@]} -eq 0 ]; then
        return
    fi
    
    local selected=$(printf '%s\n' "${hostnames[@]}" | \
        gum choose --header "Select client to reject:")
    
    if [ -n "$selected" ]; then
        # Find the fingerprint
        local index=0
        for host in "${hostnames[@]}"; do
            if [ "$host" = "$selected" ]; then
                if reject_client "${fingerprints[$index]}"; then
                    gum style --foreground 46 "✓ Client rejected"
                else
                    gum style --foreground 196 "✗ Failed to reject client"
                fi
                sleep 2
                break
            fi
            ((index++))
        done
    fi
}

# Enhanced fleet analytics with Gum
show_fleet_analytics_enhanced() {
    clear_screen
    
    # Animated header
    gum style \
        --foreground 212 \
        --border double \
        --border-foreground 212 \
        --padding "2 4" \
        --margin "1" \
        --align center \
        --bold=true \
        "🌐 FLEET ANALYTICS DASHBOARD 🌐" \
        "Real-time System Monitoring"
    
    # Loading animation
    show_toast "Analyzing fleet performance..." 2
    
    # Collect metrics with progress indicator
    local cpu_values=()
    local mem_values=()
    local client_names=()
    local client_count=0
    local total_clients=$(get_clients | wc -l)
    
    while IFS='|' read -r id hostname last_seen fingerprint; do
        ((client_count++))
        show_progress $client_count $total_clients "Loading clients"
        
        cpu=$(get_metric "$id" "generic_cpu_usage")
        mem=$(get_metric "$id" "generic_memory_percent")
        
        cpu_values+=("$hostname|${cpu%.*}")
        mem_values+=("$hostname|${mem%.*}")
        client_names+=("$hostname")
    done < <(get_clients)
    
    clear_screen
    show_header
    
    # Display analytics with tabs
    local tabs=(
        "📊Overview"
        "📈Performance"
        "📋Details"
    )
    
    local selected_tab=$(gum choose \
        --header "Select Analytics View:" \
        --cursor "▶ " \
        --cursor.foreground="212" \
        "${tabs[@]}")
    
    case "$selected_tab" in
        *"Overview")
            show_divider "double" "46"
            generate_bar_chart "CPU Usage by Client" "${cpu_values[@]}"
            echo ""
            generate_bar_chart "Memory Usage by Client" "${mem_values[@]}"
            ;;
        *"Performance")
            show_performance_metrics
            ;;
        *"Details")
            show_detailed_analytics
            ;;
    esac
    
    echo ""
    show_divider "single" "241"
    
    if confirm_action "Return to main menu?" "Yes" "Stay here"; then
        return
    else
        show_fleet_analytics_enhanced
    fi
}

# Keep old function
show_fleet_analytics() {
    show_fleet_analytics_enhanced
}

# Enhanced settings menu
show_settings_menu() {
    clear_screen
    
    gum style \
        --foreground 214 \
        --border rounded \
        --border-foreground 214 \
        --padding "1 2" \
        --margin "1" \
        --align center \
        "⚙️  SETTINGS"
    
    local settings=(
        "🔄 Auto-Refresh: $AUTO_REFRESH"
        "⏱️  Refresh Rate: ${REFRESH_RATE}s"
        "🎨 Theme Settings"
        "🔔 Notifications"
        "💾 Export Data"
        "⬅️  Back"
    )
    
    local choice=$(show_menu "Configure Options" "${settings[@]}")
    
    case "$choice" in
        *"Auto-Refresh"*)
            if [ "$AUTO_REFRESH" = "true" ]; then
                AUTO_REFRESH="false"
                show_alert "info" "Auto-refresh disabled"
            else
                AUTO_REFRESH="true"
                show_alert "success" "Auto-refresh enabled"
            fi
            show_settings_menu
            ;;
        *"Refresh Rate"*)
            local new_rate=$(get_input "Refresh rate (seconds):" "1-60" "$REFRESH_RATE")
            if [[ "$new_rate" =~ ^[0-9]+$ ]] && [ "$new_rate" -ge 1 ] && [ "$new_rate" -le 60 ]; then
                REFRESH_RATE="$new_rate"
                show_alert "success" "Refresh rate set to ${REFRESH_RATE}s"
            else
                show_alert "error" "Invalid refresh rate. Must be 1-60 seconds."
            fi
            show_settings_menu
            ;;
        *"Theme Settings"*)
            show_theme_settings
            ;;
        *"Notifications"*)
            show_notification_settings
            ;;
        *"Export Data"*)
            export_data_menu
            ;;
        *"Back"*)
            return
            ;;
    esac
}

# Additional helper functions
select_view_type() {
    local views=("Detailed" "Compact" "Graph-only")
    local selected=$(gum choose --header "Select view type:" "${views[@]}")
    show_alert "info" "View changed to: $selected"
}

show_performance_metrics() {
    echo "Performance metrics view - Coming soon!"
}

show_detailed_analytics() {
    echo "Detailed analytics view - Coming soon!"
}

show_theme_settings() {
    show_alert "info" "Theme customization coming soon!"
}

show_notification_settings() {
    show_alert "info" "Notification settings coming soon!"
}

export_data_menu() {
    show_alert "info" "Data export feature coming soon!"
}

# Keep old function
toggle_auto_refresh() {
    show_settings_menu
}

# Trap for clean exit
trap 'clear_screen; echo "Goodbye!"; exit 0' INT TERM

# Main entry point
main() {
    # Check if database exists
    if [ ! -f "$DB_PATH" ]; then
        gum style \
            --foreground 196 \
            --border double \
            --border-foreground 196 \
            --padding "1 2" \
            "ERROR: Database not found at $DB_PATH"
        exit 1
    fi
    
    # Check if gum is installed
    if ! command -v gum &> /dev/null; then
        echo "ERROR: gum is not installed"
        echo "Please install gum: https://github.com/charmbracelet/gum"
        exit 1
    fi
    
    # Force interactive mode for gum
    export GUM_CHOOSE_SELECTED_PREFIX_FOREGROUND=46
    export GUM_CHOOSE_CURSOR_FOREGROUND=46
    
    # Start main menu
    show_main_menu
}

# Run main function
main "$@"