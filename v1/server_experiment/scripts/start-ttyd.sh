#!/bin/bash
# Start script for ttyd web terminal

# Configuration from environment
TTYD_PORT=${TTYD_PORT:-7681}
TTYD_AUTH=${TTYD_AUTH:-}  # Format: username:password
TTYD_SSL=${TTYD_SSL:-false}
TTYD_TITLE=${TTYD_TITLE:-"Lumenmon TUI"}
TTYD_MAX_CLIENTS=${TTYD_MAX_CLIENTS:-10}
TTYD_READONLY=${TTYD_READONLY:-false}

# Build ttyd command
TTYD_CMD="ttyd"

# Add port
TTYD_CMD="$TTYD_CMD --port $TTYD_PORT"

# Add options for better terminal interaction
TTYD_CMD="$TTYD_CMD --writable"

# Add authentication if provided
if [ -n "$TTYD_AUTH" ]; then
    TTYD_CMD="$TTYD_CMD --credential $TTYD_AUTH"
    echo "Authentication enabled for web terminal"
fi

# Add SSL if enabled
if [ "$TTYD_SSL" = "true" ]; then
    TTYD_CMD="$TTYD_CMD --ssl"
    TTYD_CMD="$TTYD_CMD --ssl-cert /app/cert.pem"
    TTYD_CMD="$TTYD_CMD --ssl-key /app/key.pem"
    echo "SSL enabled for web terminal"
fi

# Add read-only mode if enabled
if [ "$TTYD_READONLY" = "true" ]; then
    TTYD_CMD="$TTYD_CMD --readonly"
    echo "Read-only mode enabled"
fi

# Add other options
TTYD_CMD="$TTYD_CMD --max-clients $TTYD_MAX_CLIENTS"

# Terminal settings for better compatibility
export TERM=xterm-256color
export COLORTERM=truecolor
export LINES=24
export COLUMNS=80

# Note: ttyd doesn't support custom CSS via command line in this version

# Start message
echo "════════════════════════════════════════════════════════════════"
echo "  LUMENMON WEB TERMINAL STARTING"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Web Interface: http://localhost:$TTYD_PORT"
if [ -n "$TTYD_AUTH" ]; then
    echo "  Authentication: Required"
fi
echo "  Max Clients: $TTYD_MAX_CLIENTS"
echo "  Read-Only: $TTYD_READONLY"
echo ""
echo "  Press Ctrl+C to stop the server"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Start ttyd with the wrapper script for proper terminal initialization
echo "Starting ttyd with command: $TTYD_CMD /app/scripts/ttyd-wrapper.sh"
exec $TTYD_CMD /app/scripts/ttyd-wrapper.sh