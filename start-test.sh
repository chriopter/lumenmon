#!/bin/bash
# Start Lumenmon test environment with console and multiple agents
set -euo pipefail

# Configuration
NUM_AGENTS=${1:-3}  # Default to 3 agents if not specified

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           LUMENMON TEST ENVIRONMENT LAUNCHER              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 1: Clean up any existing containers
echo -e "${YELLOW}[1/4] Cleaning up existing containers...${NC}"
docker rm -f $(docker ps -aq --filter "name=lumenmon-") 2>/dev/null || true
docker network rm lumenmon-net 2>/dev/null || true
docker volume rm lumenmon-ssh-keys 2>/dev/null || true

# Step 2: Start the Console
echo -e "${BLUE}[2/4] Starting Lumenmon Console...${NC}"
cd console
docker-compose up --build -d
cd ..

# Wait for console to be ready
echo -e "${BLUE}    Waiting for console to initialize...${NC}"
sleep 5

# Check if console is running
if docker ps | grep -q lumenmon-console; then
    echo -e "${GREEN}    ✓ Console started successfully${NC}"
else
    echo -e "${RED}    ✗ Failed to start console${NC}"
    exit 1
fi

# Step 3: Build agent image
echo -e "${BLUE}[3/4] Building agent image...${NC}"
cd agent
docker-compose build
cd ..
echo -e "${GREEN}    ✓ Agent image built${NC}"

# Step 4: Start test agents
echo -e "${BLUE}[4/4] Starting ${NUM_AGENTS} test agents...${NC}"

for i in $(seq 1 $NUM_AGENTS); do
    AGENT_NAME="agent-$(printf "%02d" $i)"
    CONTAINER_NAME="lumenmon-${AGENT_NAME}"

    echo -e "${BLUE}    Starting ${AGENT_NAME}...${NC}"

    docker run -d \
        --name "${CONTAINER_NAME}" \
        --hostname "${AGENT_NAME}" \
        --network lumenmon-net \
        -v lumenmon-ssh-keys:/shared:ro \
        -e CONSOLE_HOST=lumenmon-console \
        -e CONSOLE_PORT=22 \
        -e CONSOLE_USER=collector \
        -e AGENT_ID="${AGENT_NAME}" \
        -e CPU_SAMPLE_HZ=10 \
        -e MEMORY_SAMPLE_HZ=1 \
        -e DISK_SAMPLE_HZ=0.1 \
        -e NETWORK_SAMPLE_HZ=0.5 \
        -e PROCESS_SAMPLE_HZ=0.2 \
        -e SYSTEM_SAMPLE_HZ=0.017 \
        agent-agent \
        sh -c "echo '[${AGENT_NAME}] Waiting for SSH keys...';
               while [ ! -f /shared/agent_key ]; do sleep 1; done;
               cp /shared/agent_key /home/metrics/.ssh/id_rsa;
               chmod 600 /home/metrics/.ssh/id_rsa;
               echo '[${AGENT_NAME}] SSH key installed';
               exec /usr/local/bin/coordinator.sh" \
        > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}    ✓ ${AGENT_NAME} started${NC}"
    else
        echo -e "${RED}    ✗ Failed to start ${AGENT_NAME}${NC}"
    fi
done

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    TEST ENVIRONMENT READY                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Console Status:${NC}"
docker ps --filter "name=lumenmon-console" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo -e "${GREEN}Agent Status:${NC}"
docker ps --filter "name=lumenmon-agent" --format "table {{.Names}}\t{{.Status}}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}View Monitoring Dashboard:${NC}"
echo ""
echo "  Simple TUI (CPU focused):"
echo -e "  ${BLUE}docker exec -it lumenmon-console python3 /usr/local/bin/tui.py${NC}"
echo ""
echo "  Enhanced TUI (All metrics):"
echo -e "  ${BLUE}docker exec -it lumenmon-console python3 /usr/local/bin/tui_enhanced.py${NC}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "To stop all containers, run: ./stop-test.sh"
echo ""