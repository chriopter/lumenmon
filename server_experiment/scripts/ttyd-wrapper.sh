#!/bin/bash
# Wrapper script to ensure proper terminal initialization for ttyd

# Set up terminal environment
export TERM=xterm-256color
export COLORTERM=truecolor
export DB_PATH=${DB_PATH:-/app/data/lumenmon.db}
export REFRESH_RATE=${REFRESH_RATE:-5}
export AUTO_REFRESH=${AUTO_REFRESH:-true}

# Unset BOLD to prevent conflicts with gum
unset BOLD

# Get terminal dimensions dynamically
export LINES=$(tput lines 2>/dev/null || echo 40)
export COLUMNS=$(tput cols 2>/dev/null || echo 120)

# Force interactive mode
set -i

# Ensure we have a proper TTY
if [ ! -t 0 ]; then
    echo "Warning: No TTY detected, forcing allocation..."
    exec script -qfc "/app/scripts/tui.sh" /dev/null
fi

# Ensure terminal is properly sized and configured
stty sane 2>/dev/null || true
stty rows $LINES cols $COLUMNS 2>/dev/null || true

# Clear screen and reset
clear
reset

# Set window title
echo -ne "\033]0;◄ LUMENMON SYSTEM MONITOR v4.2.0 ►\007"

# Source the animated logo script
source /app/scripts/animated_logo.sh

# Add subtle CRT scanline effect (optional)
add_scanlines() {
    # Position at top of screen
    tput cup 0 0
    
    # Create subtle scanline overlay
    for ((i=0; i<$(tput lines); i+=2)); do
        tput cup $i 0
        echo -ne "\033[38;5;236m"
        printf '%.0s─' $(seq 1 $(tput cols))
        echo -ne "\033[0m"
    done
}

# Show the animated logo build
show_logo_animation

# Optional: Add scanlines for CRT effect (comment out if too much)
# add_scanlines

# Start the TUI directly
exec /app/scripts/tui.sh