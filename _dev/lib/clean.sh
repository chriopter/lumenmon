#!/bin/bash
# Clean data directories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "Cleaning data directories..."
find "$PROJECT_ROOT/agent/data" -type f ! -name '.gitkeep' -delete 2>/dev/null || true
find "$PROJECT_ROOT/console/data" -type f ! -name '.gitkeep' -delete 2>/dev/null || true
# Also remove agent directories
rm -rf "$PROJECT_ROOT"/console/data/agents/id_* 2>/dev/null || true
echo "Done"