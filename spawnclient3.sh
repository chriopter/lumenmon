#!/bin/bash
# 3-Client Spawner - DRY version that calls spawnclient.sh 3 times
# Usage: ./spawnclient3.sh

SCRIPT_DIR="$(dirname "$0")"

echo "🚀 Spawning 3 detached clients..."

for i in 1 2 3; do
    "$SCRIPT_DIR/spawnclient.sh" -d
    sleep 1  # Ensure unique names
done

echo ""
echo "🎉 Started 3 detached clients"
echo ""
echo "Commands:"
echo "  📊 Dashboard:      http://localhost:8501"
echo "  👀 View clients:   docker ps | grep ^client-"
echo "  🛑 Stop all:       docker ps --format '{{.Names}}' | grep '^client-' | xargs -r docker stop"
echo "  📝 View logs:      docker logs -f <client-name>"
echo "  🧹 Cleanup keys:   rm -rf /tmp/client-*"