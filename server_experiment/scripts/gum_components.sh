#!/bin/bash
# Reusable Gum components for amazing TUI

# Loading spinner with custom message
show_spinner() {
    local message="${1:-Loading...}"
    local command="${2:-sleep 1}"
    
    gum spin --spinner globe \
        --title "$message" \
        --spinner.foreground="212" \
        -- $command
}

# Styled alert box
show_alert() {
    local level="$1"  # info, warning, error, success
    local message="$2"
    
    case "$level" in
        "error")
            gum style \
                --foreground 196 \
                --border double \
                --border-foreground 196 \
                --padding "1 2" \
                --margin "1" \
                --bold=true \
                "⚠️  ERROR: $message"
            ;;
        "warning")
            gum style \
                --foreground 214 \
                --border rounded \
                --border-foreground 214 \
                --padding "1 2" \
                --margin "1" \
                "⚡ WARNING: $message"
            ;;
        "success")
            gum style \
                --foreground 82 \
                --border double \
                --border-foreground 82 \
                --padding "1 2" \
                --margin "1" \
                "✅ SUCCESS: $message"
            ;;
        "info")
            gum style \
                --foreground 33 \
                --border normal \
                --border-foreground 33 \
                --padding "1 2" \
                --margin "1" \
                "ℹ️  $message"
            ;;
    esac
}

# Fancy header with gradient effect
show_header() {
    gum style \
        --foreground 212 \
        --border double \
        --border-foreground 212 \
        --padding "1 2" \
        --margin "1" \
        --align center \
        --bold=true \
        "L U M E N M O N" \
        "System Monitor v4.2.0"
}

# Animated menu with icons
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    echo ""
    gum style \
        --foreground 51 \
        --bold=true \
        --align center \
        "═══ $title ═══"
    echo ""
    
    gum choose \
        --cursor "▶ " \
        --cursor.foreground="212" \
        --selected.foreground="46" \
        --height 10 \
        "${options[@]}"
}

# Progress bar with percentage
show_progress() {
    local current="$1"
    local total="$2"
    local label="${3:-Progress}"
    
    local percentage=$((current * 100 / total))
    
    echo "$label: $percentage%" | gum style --foreground 46
    
    # Create visual bar
    local bar_width=40
    local filled=$((percentage * bar_width / 100))
    local empty=$((bar_width - filled))
    
    printf "["
    printf "%${filled}s" | tr ' ' '█' | gum style --foreground 46
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d/%d\n" "$current" "$total"
}

# Searchable list
show_searchable_list() {
    local title="$1"
    local placeholder="${2:-Search...}"
    shift 2
    local items=("$@")
    
    gum style --foreground 214 --bold=true "$title"
    
    printf '%s\n' "${items[@]}" | \
        gum filter \
            --placeholder "$placeholder" \
            --prompt "🔍 " \
            --indicator "→" \
            --indicator.foreground="212" \
            --match.foreground="46" \
            --height 15
}

# Confirmation dialog with style
confirm_action() {
    local message="$1"
    local affirmative="${2:-Yes}"
    local negative="${3:-No}"
    
    gum confirm \
        --affirmative "$affirmative" \
        --negative "$negative" \
        --affirmative.background="46" \
        --negative.background="196" \
        --prompt.foreground="226" \
        "$message"
}

# Input with validation
get_input() {
    local prompt="$1"
    local placeholder="${2:-Enter value...}"
    local default_value="${3:-}"
    
    gum input \
        --prompt "$prompt " \
        --placeholder "$placeholder" \
        --value "$default_value" \
        --cursor.foreground="212" \
        --prompt.foreground="214" \
        --width 50
}

# Table display
show_table() {
    local title="$1"
    local data="$2"
    
    echo "$title" | gum style --foreground 51 --bold=true --margin "1 0"
    
    echo "$data" | gum table \
        --border.foreground="241" \
        --header.foreground="212" \
        --selected.foreground="46"
}

# Toast notification
show_toast() {
    local message="$1"
    local duration="${2:-2}"
    
    (
        gum style \
            --foreground 226 \
            --background 235 \
            --border rounded \
            --border-foreground 226 \
            --padding "0 1" \
            --margin "0 1" \
            "🔔 $message"
        sleep "$duration"
    ) &
}

# Multi-select with checkboxes
multi_select() {
    local title="$1"
    shift
    local options=("$@")
    
    gum style --foreground 214 --bold=true "$title"
    
    gum choose \
        --no-limit \
        --cursor "[ ] " \
        --selected-prefix "[✓] " \
        --unselected-prefix "[ ] " \
        --cursor.foreground="212" \
        --header "Use space to select, enter to confirm" \
        "${options[@]}"
}

# Animated transition
transition() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    
    for frame in "${frames[@]}"; do
        printf "\r%s Loading..." "$frame" | gum style --foreground 51
        sleep 0.05
    done
    printf "\r%20s\r" ""  # Clear the line
}

# Status indicator with color
show_status() {
    local status="$1"
    local label="$2"
    
    case "$status" in
        "online"|"active"|"running")
            echo "● $label" | gum style --foreground 46 --bold=true
            ;;
        "offline"|"inactive"|"stopped")
            echo "○ $label" | gum style --foreground 196 --bold=true
            ;;
        "warning"|"degraded")
            echo "◐ $label" | gum style --foreground 214 --bold=true
            ;;
        *)
            echo "◌ $label" | gum style --foreground 241
            ;;
    esac
}

# Styled divider
show_divider() {
    local style="${1:-single}"
    local color="${2:-241}"
    local width=$(tput cols 2>/dev/null || echo 80)
    
    case "$style" in
        "double")
            printf '═%.0s' $(seq 1 $width) | gum style --foreground "$color"
            ;;
        "thick")
            printf '━%.0s' $(seq 1 $width) | gum style --foreground "$color"
            ;;
        "dotted")
            printf '·%.0s' $(seq 1 $width) | gum style --foreground "$color"
            ;;
        *)
            printf '─%.0s' $(seq 1 $width) | gum style --foreground "$color"
            ;;
    esac
    echo ""
}

# Key-value display
show_kv() {
    local key="$1"
    local value="$2"
    local key_color="${3:-214}"
    local value_color="${4:-46}"
    
    printf "%s: %s\n" \
        "$(echo "$key" | gum style --foreground "$key_color" --bold=true)" \
        "$(echo "$value" | gum style --foreground "$value_color")"
}