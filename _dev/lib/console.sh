#!/bin/bash
# Start console container

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
echo "Starting console..."
cd "$PROJECT_ROOT/console" && docker compose up -d --build