#!/bin/bash
# debug.sh - Interactive collector debugger
# Run collectors locally without Docker/SSH to see raw output

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find collectors directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COLLECTORS_DIR="$SCRIPT_DIR/generic"

# Set up debug environment
export AGENT_ID="${HOSTNAME:-debug}"
export PULSE="1"        # All run at 1 second for debugging
export BREATHE="1"      # All run at 1 second for debugging
export CYCLE="1"        # All run at 1 second for debugging
export REPORT="1"       # All run at 1 second for debugging
export LUMENMON_TRANSPORT="cat"  # Just output to terminal

# List available collectors
list_collectors() {
    echo -e "${BLUE}Available collectors:${NC}"
    echo ""
    local i=1
    for collector in "$COLLECTORS_DIR"/*.sh; do
        if [ -f "$collector" ]; then
            name=$(basename "$collector" .sh)
            echo "  $i) $name"
            ((i++))
        fi
    done
    echo ""
}

# Main menu
clear
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            LUMENMON COLLECTOR DEBUG MODE                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "This tool runs collectors locally to see their raw TSV output."
echo "Press Ctrl+C to stop a running collector."
echo ""

list_collectors

# Get user choice
echo -e "${YELLOW}Enter collector number or name (or 'q' to quit):${NC} "
read -r choice

# Handle quit
if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    echo "Goodbye!"
    exit 0
fi

# Find the selected collector
selected=""
if [[ "$choice" =~ ^[0-9]+$ ]]; then
    # User entered a number
    i=1
    for collector in "$COLLECTORS_DIR"/*.sh; do
        if [ -f "$collector" ]; then
            if [ "$i" = "$choice" ]; then
                selected="$collector"
                break
            fi
            ((i++))
        fi
    done
else
    # User entered a name
    if [ -f "$COLLECTORS_DIR/$choice.sh" ]; then
        selected="$COLLECTORS_DIR/$choice.sh"
    fi
fi

# Check if we found a collector
if [ -z "$selected" ]; then
    echo -e "${YELLOW}Invalid choice: $choice${NC}"
    exit 1
fi

# Run the collector
name=$(basename "$selected" .sh)
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Running collector: $name${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "TSV Format: timestamp | agent_id | metric | type | value | interval"
echo ""
echo -e "${YELLOW}Output:${NC}"
echo "--------------------------------------------------------------------------------"

# Execute the collector
exec "$selected"