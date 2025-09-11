#!/bin/bash
# Display formatting functions for Lumenmon TUI

# 80s Terminal Colors - Bright and vibrant
GREEN="\033[1;32m"      # Bright green
YELLOW="\033[1;33m"     # Bright yellow
RED="\033[1;31m"        # Bright red
CYAN="\033[1;36m"       # Bright cyan
MAGENTA="\033[1;35m"    # Bright magenta
WHITE="\033[1;37m"      # Bright white
RESET="\033[0m"
BOLD="\033[1m"
BLINK="\033[5m"         # Blinking text
REVERSE="\033[7m"       # Reverse video
DIM="\033[2m"           # Dim text

# Neon glow effect
GLOW_GREEN="\033[38;5;46m"   # Neon green
GLOW_CYAN="\033[38;5;51m"    # Neon cyan
GLOW_PINK="\033[38;5;201m"   # Neon pink
GLOW_YELLOW="\033[38;5;226m" # Neon yellow

# Export only color codes, not BOLD which conflicts with gum
export GLOW_GREEN GLOW_CYAN GLOW_PINK GLOW_YELLOW RESET

# Create progress bar with 80s style
create_progress_bar() {
    local value=$1
    local max=${2:-100}
    local width=${3:-20}
    
    if [ "$max" -eq 0 ]; then
        printf "${DIM}[%${width}s]${RESET}" | tr ' ' '░'
        return
    fi
    
    local percentage=$((value * 100 / max))
    [ $percentage -gt 100 ] && percentage=100
    
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    # Retro color gradients
    local color=""
    if [ $percentage -lt 25 ]; then
        color="${GLOW_CYAN}"
        char="▰"
    elif [ $percentage -lt 50 ]; then
        color="${GLOW_GREEN}"
        char="▰"
    elif [ $percentage -lt 75 ]; then
        color="${GLOW_YELLOW}"
        char="▰"
    else
        color="${RED}${BLINK}"
        char="▰"
    fi
    
    printf "${color}"
    printf "%${filled}s" | tr ' ' '▰'
    printf "${DIM}"
    printf "%${empty}s" | tr ' ' '▱'
    printf "${RESET}"
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ $(echo "$bytes >= 1024" | bc) -eq 1 ] && [ $unit -lt 4 ]; do
        bytes=$(echo "scale=1; $bytes / 1024" | bc)
        ((unit++))
    done
    
    printf "%.1f%s" "$bytes" "${units[$unit]}"
}

# Format uptime
format_uptime() {
    local seconds=${1:-0}
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    
    if [ $days -gt 0 ]; then
        printf "%dd %dh" $days $hours
    elif [ $hours -gt 0 ]; then
        printf "%dh %dm" $hours $minutes
    else
        printf "%dm" $minutes
    fi
}

# Display client row
display_client_row() {
    local id=$1
    local hostname=$2
    local cpu=$3
    local mem=$4
    local load=$5
    local online=$6
    
    # Status indicator
    if [ "$online" = "true" ]; then
        status="${GREEN}●${RESET}"
        status_text="ONLINE"
    else
        status="${RED}○${RESET}"
        status_text="OFFLINE"
    fi
    
    # Truncate hostname if too long
    hostname=$(printf "%-15.15s" "$hostname")
    
    # CPU bar
    cpu_bar=$(create_progress_bar "${cpu%.*}" 100 10)
    
    # Format output with retro CRT terminal styling
    printf "${GLOW_CYAN}%s${RESET} ${GLOW_YELLOW}%-15s${RESET} ${DIM}│${RESET} CPU:%s ${GLOW_CYAN}%3.0f%%${RESET} ${DIM}│${RESET} MEM:${GLOW_MAGENTA}%3.0f%%${RESET} ${DIM}│${RESET} LOAD:${GLOW_YELLOW}%4.1f${RESET} ${DIM}│${RESET} %s\n" \
        "$status" "$hostname" "$cpu_bar" "${cpu:-0}" "${mem:-0}" "${load:-0}" "$status_text"
}

# Display ASCII header
display_header() {
    # Get terminal width
    local term_width=$(tput cols 2>/dev/null || echo 80)
    
    # 80s style header with scanlines effect
    echo -e "${GLOW_CYAN}"
    printf '▀%.0s' $(seq 1 $term_width)
    echo ""
    
    # Big retro ASCII title
    echo -e "${GLOW_GREEN}"
    cat << 'EOF'
     ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
     ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
     ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
     ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
     ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
     ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
EOF
    
    # Retro subtitle with blinking
    echo -e "${GLOW_PINK}${BLINK}        ◄ SYSTEM MONITOR v4.2.0 ►  ${RESET}${GLOW_YELLOW}[ AUTHORIZED ACCESS ONLY ]${RESET}"
    
    echo -e "${GLOW_CYAN}"
    printf '▄%.0s' $(seq 1 $term_width)
    echo -e "${RESET}"
    echo ""
}

# Display fleet statistics box - 80s style
display_fleet_stats() {
    local total=$1
    local online=$2
    local avg_cpu=$3
    local avg_mem=$4
    
    local term_width=$(tput cols 2>/dev/null || echo 80)
    
    # Retro double-line box with neon glow
    echo -e "${GLOW_PINK}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║${GLOW_CYAN}${BLINK}                       ◄ FLEET COMMAND CENTER ►                             ${RESET}${GLOW_PINK}║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    
    # Status indicators with retro styling
    echo -n "║ "
    
    # Online status with retro LED indicators
    if [ -n "$online" ] && [ "$online" -gt 0 ]; then
        echo -ne "${GLOW_GREEN}██ SYSTEMS ONLINE: ${online}/${total}${RESET}  "
    else
        echo -ne "${RED}${BLINK}██ SYSTEMS OFFLINE${RESET}  "
    fi
    
    # CPU gauge
    echo -ne "${GLOW_CYAN}║ CPU ["
    # Handle empty or invalid cpu values
    local cpu_int=${avg_cpu%.*}
    [ -z "$cpu_int" ] && cpu_int=0
    local cpu_blocks=$((cpu_int / 10))
    for i in $(seq 1 10); do
        if [ $i -le $cpu_blocks ]; then
            if [ $i -le 5 ]; then
                echo -ne "${GLOW_GREEN}█"
            elif [ $i -le 8 ]; then
                echo -ne "${GLOW_YELLOW}█"
            else
                echo -ne "${RED}█"
            fi
        else
            echo -ne "${DIM}░"
        fi
    done
    echo -ne "${RESET}${GLOW_CYAN}] ${avg_cpu}%${RESET}  "
    
    # Memory gauge
    echo -ne "${GLOW_MAGENTA}║ MEM ["
    # Handle empty or invalid mem values
    local mem_int=${avg_mem%.*}
    [ -z "$mem_int" ] && mem_int=0
    local mem_blocks=$((mem_int / 10))
    for i in $(seq 1 10); do
        if [ $i -le $mem_blocks ]; then
            if [ $i -le 5 ]; then
                echo -ne "${GLOW_GREEN}█"
            elif [ $i -le 8 ]; then
                echo -ne "${GLOW_YELLOW}█"
            else
                echo -ne "${RED}█"
            fi
        else
            echo -ne "${DIM}░"
        fi
    done
    echo -e "${RESET}${GLOW_MAGENTA}] ${avg_mem}%${RESET}${GLOW_PINK} ║"
    
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# Display pending registrations - 80s alert style
display_pending_registrations() {
    local count=$1
    
    if [ $count -eq 0 ]; then
        return
    fi
    
    echo ""
    echo -e "${RED}${BLINK}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}${BLINK}║        ⚠️  ALERT: $count UNAUTHORIZED ACCESS ATTEMPT(S) DETECTED  ⚠️             ║${RESET}"
    echo -e "${RED}${BLINK}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
}

# Display client details
display_client_details() {
    local client_id=$1
    local hostname=$2
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    printf "║  CLIENT: %-68s ║\n" "${hostname^^}"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    
    # Get all metrics
    local cpu=$(get_metric "$client_id" "generic_cpu_usage")
    local mem=$(get_metric "$client_id" "generic_memory_percent")
    local load=$(get_metric "$client_id" "generic_cpu_load")
    local uptime=$(get_metric "$client_id" "generic_system_uptime_seconds")
    local cpu_cores=$(get_metric "$client_id" "generic_cpu_cores")
    local mem_total=$(get_metric "$client_id" "generic_memory_total_kb")
    local mem_available=$(get_metric "$client_id" "generic_memory_available_kb")
    local disk_usage=$(get_metric "$client_id" "generic_disk_root_usage_percent")
    
    # CPU section
    printf "║  CPU Usage:     %s %3.0f%%                          ║\n" \
        "$(create_progress_bar "${cpu%.*}" 100 30)" "$cpu"
    printf "║  CPU Cores:     %-3.0f              Load Average: %-5.2f                        ║\n" \
        "$cpu_cores" "$load"
    
    echo "║                                                                               ║"
    
    # Memory section
    printf "║  Memory Usage:  %s %3.0f%%                          ║\n" \
        "$(create_progress_bar "${mem%.*}" 100 30)" "$mem"
    
    if [ "$mem_total" != "0" ]; then
        local mem_total_gb=$(echo "scale=1; $mem_total / 1024 / 1024" | bc)
        local mem_available_gb=$(echo "scale=1; $mem_available / 1024 / 1024" | bc)
        printf "║  Total: %-6.1f GB               Available: %-6.1f GB                        ║\n" \
            "$mem_total_gb" "$mem_available_gb"
    fi
    
    echo "║                                                                               ║"
    
    # Disk section
    printf "║  Disk Usage:    %s %3.0f%%                          ║\n" \
        "$(create_progress_bar "${disk_usage%.*}" 100 30)" "$disk_usage"
    
    echo "║                                                                               ║"
    
    # Uptime
    printf "║  System Uptime: %-20s                                          ║\n" \
        "$(format_uptime "$uptime")"
    
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
}

# Display menu separator - 80s style
display_separator() {
    echo -e "${GLOW_PINK}◄▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬►${RESET}"
}