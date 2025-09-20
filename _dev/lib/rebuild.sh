#!/bin/bash
# Rebuild everything

echo "Rebuilding everything..."
# Stop containers
docker stop lumenmon-console lumenmon-agent 2>/dev/null || true
docker rm lumenmon-console lumenmon-agent 2>/dev/null || true

# Clean data properly
# Agent data - remove everything but keep directory structure
rm -rf ../agent/data/debug/* 2>/dev/null || true
rm -rf ../agent/data/ssh/* 2>/dev/null || true

# Console data - remove agent directories and SSH host keys
rm -rf ../console/data/agents/id_* 2>/dev/null || true
rm -f ../console/data/ssh/ssh_host* 2>/dev/null || true
rm -f ../console/data/users/* 2>/dev/null || true

# Ensure directories exist with gitkeep
mkdir -p ../agent/data/debug ../agent/data/ssh
mkdir -p ../console/data/agents ../console/data/ssh ../console/data/users
touch ../agent/data/.gitkeep ../agent/data/debug/.gitkeep ../agent/data/ssh/.gitkeep
touch ../console/data/.gitkeep ../console/data/agents/.gitkeep ../console/data/ssh/.gitkeep ../console/data/users/.gitkeep

# Start fresh
cd ../console && docker compose up -d --build && cd - >/dev/null
cd ../agent && CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose up -d --build && cd - >/dev/null
echo "Rebuilt! Use './dev.sh tui' to register agents"