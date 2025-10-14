#!/bin/bash
# Generates ASCII line charts and bar charts from metric data using Unicode box drawing characters.
# Provides plot_line() for time series graphs with axes, labels, and statistics. Sourced by tui.sh.

# Generate a line chart with axes
# Usage: plot_line "title" "10 20 30 40 50" height
plot_line() {
    local title="$1"
    local values="$2"
    local height=${3:-10}
    local -a nums

    # Parse values into array
    read -ra nums <<< "$values"

    # Handle empty or insufficient data
    if [ ${#nums[@]} -lt 2 ]; then
        echo "┌─ $title ─ No Data ─┐"
        for ((i=0; i<height; i++)); do
            echo "│                    │"
        done
        echo "└────────────────────┘"
        return
    fi

    # Find min and max
    local min=${nums[0]%.*} max=${nums[0]%.*}
    for n in "${nums[@]}"; do
        n=${n%.*}  # Strip decimals
        [ "$n" -lt "$min" ] 2>/dev/null && min=$n
        [ "$n" -gt "$max" ] 2>/dev/null && max=$n
    done

    # Add padding
    local range=$((max - min))
    [ $range -eq 0 ] && range=10 && max=$((min + 10))

    # Calculate stats
    local sum=0 count=0
    for n in "${nums[@]}"; do
        sum=$(echo "$sum + ${n%.*}" | bc 2>/dev/null || echo "$sum")
        ((count++))
    done
    local avg=$((sum / count))
    local current=${nums[-1]%.*}

    # Title line with stats
    printf "┌─ ${BOLD}%s${NC} ─ Cur: ${GREEN}%s${NC} Min: %s Avg: %s Max: %s ─┐\n" \
        "$title" "${nums[-1]}" "$min" "$avg" "$max"

    # Draw chart (bottom to top)
    for ((row=height-1; row>=0; row--)); do
        # Y-axis label
        local y_val=$((min + (range * row / (height - 1))))
        printf "│%4d " "$y_val"

        # Plot line
        for ((col=0; col<${#nums[@]}; col++)); do
            local val=${nums[$col]%.*}
            local scaled_val=$(( (val - min) * (height - 1) / range ))

            # Determine character
            if [ $scaled_val -eq $row ]; then
                printf "●"
            elif [ $scaled_val -gt $row ]; then
                printf "│"
            else
                printf " "
            fi
        done

        printf " │\n"
    done

    # Bottom line
    printf "└─────"
    for ((i=0; i<${#nums[@]}; i++)); do
        printf "─"
    done
    printf "─┘\n"
}

# Generate horizontal bar chart
# Usage: plot_bars "title" "label1:val1 label2:val2 ..."
plot_bars() {
    local title="$1"
    shift
    local width=40

    echo "┌─ $title ─┐"

    # Find max value for scaling
    local max=0
    for item in "$@"; do
        local val=${item#*:}
        val=${val%.*}
        [ "$val" -gt "$max" ] 2>/dev/null && max=$val
    done

    [ $max -eq 0 ] && max=100

    # Draw bars
    for item in "$@"; do
        local label=${item%:*}
        local val=${item#*:}
        local val_int=${val%.*}

        # Calculate bar length
        local bar_len=$((val_int * width / max))

        # Draw bar
        printf "│ %-12s " "$label"
        for ((i=0; i<bar_len; i++)); do
            printf "█"
        done
        printf " %5.1f%%\n" "$val"
    done

    echo "└────────────────────────────────────────────────────┘"
}
