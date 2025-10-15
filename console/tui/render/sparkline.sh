#!/bin/bash
# Generates ASCII sparklines from space-separated metric values using block characters.
# Normalizes values to 0-7 range and renders with ▁▂▃▄▅▆▇█ characters. Sourced by tui.sh.

# Generate sparkline from space-separated values
# Usage: sparkline "10 20 30 40 50"
sparkline() {
    local values="$1"
    local -a ticks=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
    local -a nums

    # Parse values into array
    read -ra nums <<< "$values"

    # Handle empty input
    [ ${#nums[@]} -eq 0 ] && { echo "--------"; return; }

    # Find min and max (integer arithmetic)
    local min=${nums[0]%.*} max=${nums[0]%.*}
    for n in "${nums[@]}"; do
        n=${n%.*}  # Strip decimals
        [ "$n" -lt "$min" ] 2>/dev/null && min=$n
        [ "$n" -gt "$max" ] 2>/dev/null && max=$n
    done

    # Calculate range
    local range=$((max - min))
    [ $range -eq 0 ] && range=1

    # Generate sparkline
    local result=""
    for n in "${nums[@]}"; do
        n=${n%.*}  # Strip decimals
        local idx=$(( (n - min) * 7 / range ))
        [ $idx -lt 0 ] && idx=0
        [ $idx -gt 7 ] && idx=7
        result="${result}${ticks[$idx]}"
    done

    # Pad to 8 characters with spaces
    printf "%-8s" "$result"
}

# Generate sparkline and store in variable (no subshell needed)
# Usage: sparkline_to_var "10 20 30" output_var_name
sparkline_to_var() {
    local values="$1"
    local -n output=$2
    local -a ticks=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
    local -a nums

    # Parse values into array
    read -ra nums <<< "$values"

    # Handle empty input
    if [ ${#nums[@]} -eq 0 ]; then
        output="--------"
        return
    fi

    # Find min and max (integer arithmetic)
    local min=${nums[0]%.*} max=${nums[0]%.*}
    for n in "${nums[@]}"; do
        n=${n%.*}  # Strip decimals
        [ "$n" -lt "$min" ] 2>/dev/null && min=$n
        [ "$n" -gt "$max" ] 2>/dev/null && max=$n
    done

    # Calculate range
    local range=$((max - min))
    [ $range -eq 0 ] && range=1

    # Generate sparkline
    local result=""
    for n in "${nums[@]}"; do
        n=${n%.*}  # Strip decimals
        local idx=$(( (n - min) * 7 / range ))
        [ $idx -lt 0 ] && idx=0
        [ $idx -gt 7 ] && idx=7
        result="${result}${ticks[$idx]}"
    done

    # Pad to 8 characters with spaces
    printf -v output "%-8s" "$result"
}
