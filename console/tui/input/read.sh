#!/bin/bash
# Non-blocking keyboard input reader with fast polling for responsive arrow key navigation.
# Provides read_key() with 0.01s timeout that detects arrow keys (ESC [ A/B/C/D) and regular keys. Sourced by tui.sh.
# Read a single key with timeout
# Returns the key pressed or empty string if timeout
read_key() {
    local key key2 key3

    # Read with 0.01s (10ms) timeout for responsive input
    IFS= read -rsn1 -t 0.01 key 2>/dev/null || true

    # Handle escape sequences (arrow keys, etc)
    if [ "$key" = $'\x1b' ]; then
        # Try to read the rest of the escape sequence
        IFS= read -rsn1 -t 0.01 key2 2>/dev/null || true
        IFS= read -rsn1 -t 0.01 key3 2>/dev/null || true

        # Arrow keys: ESC [ A/B/C/D
        if [ "$key2" = "[" ]; then
            case "$key3" in
                A) echo "UP"; return 0 ;;
                B) echo "DOWN"; return 0 ;;
                C) echo "RIGHT"; return 0 ;;
                D) echo "LEFT"; return 0 ;;
            esac
        fi

        # Just ESC key
        echo "ESC"
    else
        echo "$key"
    fi

    return 0
}
