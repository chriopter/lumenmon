#!/bin/bash
# Stop all Lumenmon test containers and clean up
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════╗"
echo "║            LUMENMON TEST ENVIRONMENT CLEANUP              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current container counts
CONSOLE_COUNT=$(docker ps -q --filter "name=lumenmon-console" | wc -l)
AGENT_COUNT=$(docker ps -q --filter "name=lumenmon-agent" | wc -l)
TOTAL_COUNT=$((CONSOLE_COUNT + AGENT_COUNT))

if [ $TOTAL_COUNT -eq 0 ]; then
    echo -e "${YELLOW}No Lumenmon containers are running${NC}"
else
    echo -e "${BLUE}Found ${TOTAL_COUNT} running container(s)${NC}"
    echo ""

    # Show what will be stopped
    echo -e "${YELLOW}Containers to stop:${NC}"
    docker ps --filter "name=lumenmon-" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"
    echo ""
fi

# Step 1: Stop agents first
if [ $AGENT_COUNT -gt 0 ]; then
    echo -e "${BLUE}[1/4] Stopping ${AGENT_COUNT} agent(s)...${NC}"
    docker stop $(docker ps -q --filter "name=lumenmon-agent") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=lumenmon-agent") 2>/dev/null || true
    echo -e "${GREEN}    ✓ Agents stopped${NC}"
else
    echo -e "${YELLOW}[1/4] No agents to stop${NC}"
fi

# Step 2: Stop console
if [ $CONSOLE_COUNT -gt 0 ]; then
    echo -e "${BLUE}[2/4] Stopping console...${NC}"
    cd console 2>/dev/null && docker-compose down 2>/dev/null || true
    cd ..
    echo -e "${GREEN}    ✓ Console stopped${NC}"
else
    echo -e "${YELLOW}[2/4] No console to stop${NC}"
fi

# Step 3: Clean up any remaining containers
echo -e "${BLUE}[3/4] Cleaning up remaining containers...${NC}"
REMAINING=$(docker ps -aq --filter "name=lumenmon-" | wc -l)
if [ $REMAINING -gt 0 ]; then
    docker rm -f $(docker ps -aq --filter "name=lumenmon-") 2>/dev/null || true
    echo -e "${GREEN}    ✓ Removed ${REMAINING} container(s)${NC}"
else
    echo -e "${GREEN}    ✓ No remaining containers${NC}"
fi

# Step 4: Optional - Clean up volumes and network
read -p "$(echo -e ${YELLOW})[4/4] Remove network and SSH keys volume? (y/N): $(echo -e ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}    Removing network and volumes...${NC}"
    docker network rm lumenmon-net 2>/dev/null || true
    docker volume rm lumenmon-ssh-keys 2>/dev/null || true
    echo -e "${GREEN}    ✓ Network and volumes removed${NC}"
else
    echo -e "${YELLOW}    Keeping network and volumes for next run${NC}"
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      CLEANUP COMPLETE                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Verify cleanup
REMAINING_COUNT=$(docker ps -aq --filter "name=lumenmon-" | wc -l)
if [ $REMAINING_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All Lumenmon containers have been removed${NC}"
else
    echo -e "${RED}✗ Warning: ${REMAINING_COUNT} Lumenmon container(s) still exist${NC}"
    docker ps -a --filter "name=lumenmon-" --format "table {{.Names}}\t{{.Status}}"
fi

echo ""
echo "To start a new test environment, run: ./start-test.sh [number_of_agents]"
echo ""