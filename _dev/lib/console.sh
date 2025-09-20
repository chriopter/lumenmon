#!/bin/bash
# Start console container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "Starting console..."
docker compose -f "$PROJECT_ROOT/console/docker-compose.yml" up -d --build