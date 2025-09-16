#!/bin/bash
# Quick test script for ultra-KISS Lumenmon

set -euo pipefail

echo "🚀 Starting Ultra-KISS Lumenmon Test Environment"
echo "================================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Clean up any existing containers
echo -e "${BLUE}Cleaning up old containers...${NC}"
docker rm -f $(docker ps -aq --filter "name=lumenmon-") 2>/dev/null || true
docker network rm lumenmon-net 2>/dev/null || true
docker volume rm lumenmon-ssh-keys 2>/dev/null || true

# Start console
echo -e "${GREEN}Starting console...${NC}"
cd console
docker-compose up --build -d
cd ..

# Wait for console to be ready
echo "Waiting for console to initialize..."
sleep 5

# Build agent image
echo -e "${GREEN}Building agent image...${NC}"
cd agent
docker build -t lumenmon-agent .
cd ..

# Start 3 agents
echo -e "${GREEN}Starting 3 agents...${NC}"
for i in 1 2 3; do
    docker run -d \
        --name "lumenmon-agent-0$i" \
        --hostname "agent-0$i" \
        --network lumenmon-net \
        -v lumenmon-ssh-keys:/shared:ro \
        -e CONSOLE_HOST=lumenmon-console \
        lumenmon-agent \
        sh -c "while [ ! -f /shared/agent_key ]; do sleep 1; done; \
               cp /shared/agent_key /home/metrics/.ssh/id_rsa; \
               chmod 600 /home/metrics/.ssh/id_rsa; \
               exec ./agent.sh"
    echo "  ✓ Agent $i started"
done

echo
echo "================================================"
echo -e "${GREEN}✨ Everything is running!${NC}"
echo "================================================"
echo
echo "📊 View the console (choose one):"
echo
echo "  Simple TUI (CPU-focused):"
echo -e "  ${BLUE}docker exec -it lumenmon-console python3 /usr/local/bin/tui.py${NC}"
echo
echo "  Enhanced TUI (all metrics):"
echo -e "  ${BLUE}docker exec -it lumenmon-console python3 /usr/local/bin/tui_enhanced.py${NC}"
echo
echo "📝 Check agent logs:"
echo -e "  ${BLUE}docker logs lumenmon-agent-01${NC}"
echo
echo "🛑 Stop everything:"
echo -e "  ${BLUE}docker rm -f \$(docker ps -aq --filter 'name=lumenmon-')${NC}"
echo