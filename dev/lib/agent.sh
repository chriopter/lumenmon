#!/bin/bash
# Start agent container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "Starting agent..."
CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose -f "$PROJECT_ROOT/agent/docker-compose.yml" up -d --build