#!/bin/bash
# ASCII chart generation for Lumenmon TUI

# Generate simple ASCII line chart
generate_ascii_chart() {
    local title=$1
    local data=$2
    local width=${3:-60}
    local height=${4:-10}
    
    # Parse data into arrays
    local times=()
    local values=()
    local max_value=0
    local min_value=999999
    
    while IFS='|' read -r time value; do
        times+=("$time")
        values+=("$value")
        
        # Track min/max for scaling
        if (( $(echo "$value > $max_value" | bc -l) )); then
            max_value=$value
        fi
        if (( $(echo "$value < $min_value" | bc -l) )); then
            min_value=$value
        fi
    done <<< "$data"
    
    # If no data, show empty chart
    if [ ${#values[@]} -eq 0 ]; then
        echo "╔═══════════════════════════════════════════════════════════╗"
        printf "║ %-57s ║\n" "$title"
        echo "╠═══════════════════════════════════════════════════════════╣"
        printf "║ %-57s ║\n" "No data available"
        echo "╚═══════════════════════════════════════════════════════════╝"
        return
    fi
    
    # Calculate scale
    local range=$(echo "$max_value - $min_value" | bc)
    if [ $(echo "$range < 1" | bc) -eq 1 ]; then
        range=1
    fi
    
    # Create chart grid
    echo "╔═══════════════════════════════════════════════════════════╗"
    printf "║ %-57s ║\n" "$title"
    echo "╠═══════════════════════════════════════════════════════════╣"
    
    # Draw chart lines
    for ((y=$height; y>=0; y--)); do
        local line="║"
        local y_value=$(echo "$min_value + ($range * $y / $height)" | bc)
        
        # Y-axis label
        if [ $y -eq $height ]; then
            line=$(printf "║%5.0f│" "$max_value")
        elif [ $y -eq 0 ]; then
            line=$(printf "║%5.0f│" "$min_value")
        else
            line="║     │"
        fi
        
        # Plot points
        local chart_width=$((width - 8))
        local step=$((${#values[@]} / chart_width))
        [ $step -eq 0 ] && step=1
        
        for ((x=0; x<$chart_width; x++)); do
            local idx=$((x * step))
            if [ $idx -lt ${#values[@]} ]; then
                local val=${values[$idx]}
                local normalized=$(echo "($val - $min_value) * $height / $range" | bc)
                
                if [ $(echo "$normalized >= $y - 0.5 && $normalized < $y + 0.5" | bc) -eq 1 ]; then
                    # Point is at this height
                    if [ $(echo "$val > 80" | bc) -eq 1 ]; then
                        line="${line}█"  # High value
                    elif [ $(echo "$val > 50" | bc) -eq 1 ]; then
                        line="${line}▓"  # Medium value
                    else
                        line="${line}▒"  # Low value
                    fi
                else
                    line="${line}·"
                fi
            else
                line="${line} "
            fi
        done
        
        line="${line}║"
        echo "$line"
    done
    
    # X-axis
    echo "║     └────────────────────────────────────────────────────║"
    
    # Time labels (show first and last)
    if [ ${#times[@]} -gt 0 ]; then
        local first_time="${times[0]}"
        local last_time="${times[-1]}"
        printf "║     %-25s %25s     ║\n" "$first_time" "$last_time"
    fi
    
    # Statistics
    local avg=$(echo "scale=1; ($(IFS=+; echo "${values[*]}")) / ${#values[@]}" | bc)
    printf "║     Min: %5.1f  Avg: %5.1f  Max: %5.1f                    ║\n" \
        "$min_value" "$avg" "$max_value"
    
    echo "╚═══════════════════════════════════════════════════════════╝"
}

# Generate sparkline
generate_sparkline() {
    local data=$1
    local width=${2:-40}
    
    local values=()
    while IFS='|' read -r time value; do
        values+=("$value")
    done <<< "$data"
    
    if [ ${#values[@]} -eq 0 ]; then
        echo "No data"
        return
    fi
    
    # Sparkline characters
    local sparks=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
    
    # Find min/max
    local max_value=0
    local min_value=999999
    for val in "${values[@]}"; do
        if (( $(echo "$val > $max_value" | bc -l) )); then
            max_value=$val
        fi
        if (( $(echo "$val < $min_value" | bc -l) )); then
            min_value=$val
        fi
    done
    
    local range=$(echo "$max_value - $min_value" | bc)
    if [ $(echo "$range < 1" | bc) -eq 1 ]; then
        range=1
    fi
    
    # Generate sparkline
    local sparkline=""
    local step=$((${#values[@]} / width))
    [ $step -eq 0 ] && step=1
    
    for ((i=0; i<${#values[@]}; i+=$step)); do
        local val=${values[$i]}
        local normalized=$(echo "($val - $min_value) * 7 / $range" | bc)
        [ $normalized -gt 7 ] && normalized=7
        [ $normalized -lt 0 ] && normalized=0
        sparkline="${sparkline}${sparks[$normalized]}"
    done
    
    echo "$sparkline"
}

# Generate horizontal bar chart
generate_bar_chart() {
    local title=$1
    shift
    local items=("$@")
    
    echo "╔═══════════════════════════════════════════════════════════╗"
    printf "║ %-57s ║\n" "$title"
    echo "╠═══════════════════════════════════════════════════════════╣"
    
    for item in "${items[@]}"; do
        IFS='|' read -r label value <<< "$item"
        
        # Normalize to 0-100
        local bar_length=$((value * 40 / 100))
        local bar=""
        
        for ((i=0; i<40; i++)); do
            if [ $i -lt $bar_length ]; then
                if [ $value -gt 80 ]; then
                    bar="${bar}█"
                elif [ $value -gt 50 ]; then
                    bar="${bar}▓"
                else
                    bar="${bar}▒"
                fi
            else
                bar="${bar}░"
            fi
        done
        
        printf "║ %-10s [%s] %3d%% ║\n" "$label" "$bar" "$value"
    done
    
    echo "╚═══════════════════════════════════════════════════════════╝"
}

# Generate mini graph for inline display
generate_mini_graph() {
    local data=$1
    local width=${2:-20}
    
    local values=()
    while IFS='|' read -r time value; do
        values+=("$value")
    done <<< "$data"
    
    if [ ${#values[@]} -eq 0 ]; then
        printf "%${width}s" "─"
        return
    fi
    
    # Use box drawing characters for mini graph
    local chars=("─" "╱" "╲" "┌" "┐" "└" "┘")
    
    # Simple trend indicator
    local trend=""
    local step=$((${#values[@]} / width))
    [ $step -eq 0 ] && step=1
    
    local prev_val=${values[0]}
    for ((i=$step; i<${#values[@]}; i+=$step)); do
        local val=${values[$i]}
        
        if (( $(echo "$val > $prev_val + 5" | bc -l) )); then
            trend="${trend}╱"  # Rising
        elif (( $(echo "$val < $prev_val - 5" | bc -l) )); then
            trend="${trend}╲"  # Falling
        else
            trend="${trend}─"  # Stable
        fi
        
        prev_val=$val
    done
    
    # Pad or truncate to width
    printf "%-${width}.${width}s" "$trend"
}