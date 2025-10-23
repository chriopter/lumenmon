#!/bin/bash
# Test all collectors by running them once and displaying output in table format.
# Usage: ./agent/collectors/test_collectors.sh (from anywhere)

set -euo pipefail

# Change to script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Mock environment variables (matches agent.sh)
export PULSE=1
export BREATHE=10
export CYCLE=60
export REPORT=3600
export AGENT_ID="test_agent"

# Create temporary directory structure that matches agent layout
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

mkdir -p "$TEMP_DIR/core/mqtt"

# Create mock publish.sh that outputs to stdout instead of MQTT socket
cat > "$TEMP_DIR/core/mqtt/publish.sh" << 'EOF'
#!/bin/bash
publish_metric() {
    local metric="$1"
    local value="$2"
    local type="$3"
    echo "$metric|$value|$type"
}
EOF

echo "Testing all collectors (waits ~2 seconds per collector)..."
echo ""
printf "%-25s %-20s %-10s\n" "METRIC" "VALUE" "TYPE"
printf "%-25s %-20s %-10s\n" "-------------------------" "--------------------" "----------"

# Find all collector scripts
collectors=$(find generic -name "*.sh" -type f | sort)

for collector in $collectors; do
    # Run collector with mocked /app path, timeout after 2s, get first output
    (
        # Override /app path to use our temp dir
        mkdir -p "$TEMP_DIR/app"
        ln -sf "$TEMP_DIR/core" "$TEMP_DIR/app/core" 2>/dev/null || true

        # Patch the source line in the collector script on-the-fly
        sed 's|source /app/core/mqtt/publish.sh|source '"$TEMP_DIR"'/core/mqtt/publish.sh|' "$collector" | \
            timeout 2s bash 2>/dev/null | head -1 | while IFS='|' read metric value type; do
                printf "%-25s %-20s %-10s\n" "$metric" "$value" "$type"
            done
    ) || true
done

echo ""
echo "✓ Test complete"
