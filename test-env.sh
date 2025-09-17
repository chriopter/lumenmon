#!/bin/bash
# Test environment for local development
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
NUM_AGENTS=3
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Functions
start_env() {
    echo -e "${BLUE}Starting test environment...${NC}"

    # Start console
    echo -e "${BLUE}Starting console...${NC}"
    cd "$SCRIPT_DIR/console"
    docker-compose up -d --build

    # Wait for console to be ready
    sleep 3

    # Start multiple agents
    echo -e "${BLUE}Starting ${NUM_AGENTS} test agents...${NC}"
    cd "$SCRIPT_DIR/agent"

    for i in $(seq 1 $NUM_AGENTS); do
        AGENT_NAME="test-agent-$(printf "%02d" $i)"
        echo -e "${BLUE}  Starting ${AGENT_NAME}...${NC}"

        docker run -d \
            --name "lumenmon-test-agent-$(printf "%02d" $i)" \
            --hostname "${AGENT_NAME}" \
            --network lumenmon-net \
            -v lumenmon-ssh-keys:/shared:ro \
            -e CONSOLE_HOST=lumenmon-console \
            -e AGENT_ID="${AGENT_NAME}" \
            -e CPU_SAMPLE_HZ=10 \
            -e MEMORY_SAMPLE_HZ=1 \
            agent-agent \
            sh -c "while [ ! -f /shared/agent_key ]; do sleep 1; done;
                   cp /shared/agent_key /home/metrics/.ssh/id_rsa;
                   chmod 600 /home/metrics/.ssh/id_rsa;
                   exec /usr/local/bin/agent.sh" \
            > /dev/null 2>&1

        echo -e "${GREEN}  ✓ ${AGENT_NAME} started${NC}"
    done

    echo ""
    echo -e "${GREEN}✓ Test environment ready!${NC}"
    echo ""
    echo "View dashboard:"
    echo -e "${YELLOW}  docker exec -it lumenmon-console python3 /usr/local/bin/tui.py${NC}"
}

stop_env() {
    echo -e "${BLUE}Stopping test environment...${NC}"

    # Stop agents
    for i in $(seq 1 $NUM_AGENTS); do
        docker stop "lumenmon-test-agent-$(printf "%02d" $i)" 2>/dev/null || true
        docker rm "lumenmon-test-agent-$(printf "%02d" $i)" 2>/dev/null || true
    done

    # Stop console
    cd "$SCRIPT_DIR/console"
    docker-compose down

    echo -e "${GREEN}✓ Test environment stopped${NC}"
}

status_env() {
    echo -e "${BLUE}Test environment status:${NC}"
    echo ""

    echo "Console:"
    docker ps --filter "name=lumenmon-console" --format "  {{.Names}}: {{.Status}}"

    echo ""
    echo "Agents:"
    docker ps --filter "name=lumenmon-test-agent" --format "  {{.Names}}: {{.Status}}"
}

logs_env() {
    echo -e "${BLUE}Following logs (Ctrl+C to stop)...${NC}"

    # Get all container names
    CONTAINERS="lumenmon-console"
    for i in $(seq 1 $NUM_AGENTS); do
        CONTAINERS="$CONTAINERS lumenmon-test-agent-$(printf "%02d" $i)"
    done

    docker logs -f $CONTAINERS 2>/dev/null || echo "No containers running"
}

clean_env() {
    echo -e "${YELLOW}Cleaning test environment...${NC}"

    stop_env

    # Remove network and volumes
    docker network rm lumenmon-net 2>/dev/null || true
    docker volume rm lumenmon-ssh-keys 2>/dev/null || true

    echo -e "${GREEN}✓ Test environment cleaned${NC}"
}

# Main
case "${1:-help}" in
    start)
        start_env
        ;;
    stop)
        stop_env
        ;;
    status)
        status_env
        ;;
    logs)
        logs_env
        ;;
    clean)
        clean_env
        ;;
    *)
        echo "Lumenmon Test Environment"
        echo ""
        echo "Usage: $0 {start|stop|status|logs|clean}"
        echo ""
        echo "  start   - Start console and ${NUM_AGENTS} test agents"
        echo "  stop    - Stop all containers"
        echo "  status  - Show container status"
        echo "  logs    - Follow container logs"
        echo "  clean   - Stop and remove everything"
        ;;
esac