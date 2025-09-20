#!/bin/bash
# Stop all containers

echo "Stopping containers..."
docker stop lumenmon-console lumenmon-agent 2>/dev/null || true