#!/bin/bash
# Rebuild everything

# Get the project root (parent of _dev)
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "Rebuilding everything..."
# Stop containers
docker stop lumenmon-console lumenmon-agent 2>/dev/null || true
docker rm lumenmon-console lumenmon-agent 2>/dev/null || true

# Clean data properly
echo "Cleaning agent data..."
rm -rf "$PROJECT_ROOT"/agent/data/debug/* 2>/dev/null || true
rm -rf "$PROJECT_ROOT"/agent/data/ssh/* 2>/dev/null || true

echo "Cleaning console data..."
rm -rf "$PROJECT_ROOT"/console/data/agents/id_* 2>/dev/null || true
rm -f "$PROJECT_ROOT"/console/data/ssh/ssh_host* 2>/dev/null || true
rm -f "$PROJECT_ROOT"/console/data/*.log 2>/dev/null || true

# Ensure directories exist with gitkeep
mkdir -p "$PROJECT_ROOT"/agent/data/debug "$PROJECT_ROOT"/agent/data/ssh
mkdir -p "$PROJECT_ROOT"/console/data/agents "$PROJECT_ROOT"/console/data/ssh
touch "$PROJECT_ROOT"/agent/data/.gitkeep "$PROJECT_ROOT"/agent/data/debug/.gitkeep "$PROJECT_ROOT"/agent/data/ssh/.gitkeep
touch "$PROJECT_ROOT"/console/data/.gitkeep "$PROJECT_ROOT"/console/data/agents/.gitkeep "$PROJECT_ROOT"/console/data/ssh/.gitkeep

# Start fresh
echo "Starting console..."
cd "$PROJECT_ROOT/console" && docker compose up -d --build
echo "Starting agent..."
cd "$PROJECT_ROOT/agent" && CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose up -d --build
echo "Rebuilt! Use './dev tui' to register agents"