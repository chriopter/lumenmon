#!/bin/bash
# Non-blocking keyboard input reading

# Read a single key with timeout
# Returns the key pressed or empty string if timeout
read_key() {
    local key

    # Read with 0.1s timeout, single character
    IFS= read -rsn1 -t 0.1 key 2>/dev/null || true

    # Handle escape sequences (arrow keys)
    if [ "$key" = $'\x1b' ]; then
        # Read next two characters for escape sequence
        read -rsn2 -t 0.01 key 2>/dev/null || true
        case "$key" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT" ;;
            *)    echo "ESC" ;;
        esac
    else
        echo "$key"
    fi

    return 0
}
