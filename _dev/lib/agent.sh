#!/bin/bash
# Start agent container

echo "Starting agent..."
cd ../agent && CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose up -d --build