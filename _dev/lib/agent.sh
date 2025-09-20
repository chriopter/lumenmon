#!/bin/bash
# Start agent container

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
echo "Starting agent..."
cd "$PROJECT_ROOT/agent" && CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose up -d --build