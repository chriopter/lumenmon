#!/bin/bash
# Lumenmon Dev Helper - Ultra KISS
set -e

case "${1:-}" in
    clean)
        echo "Cleaning data directories..."
        find agent/data -type f ! -name '.gitkeep' -delete 2>/dev/null || true
        find console/data -type f ! -name '.gitkeep' -delete 2>/dev/null || true
        echo "Done"
        ;;

    console)
        echo "Starting console..."
        cd console && docker compose up -d --build
        ;;

    agent)
        echo "Starting agent..."
        cd agent && CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose up -d --build
        ;;

    tui)
        docker exec -it lumenmon-console python3 /app/tui/tui.py
        ;;

    stop)
        echo "Stopping containers..."
        docker stop lumenmon-console lumenmon-agent 2>/dev/null || true
        ;;

    logs)
        docker logs -f lumenmon-${2:-console}
        ;;

    ssh-debug)
        echo "Testing SSH authentication for agent..."
        # Get the latest agent ID
        AGENT_ID=$(docker exec lumenmon-console ls /data/agents/ | grep "^id_" | tail -1)

        if [ -z "$AGENT_ID" ]; then
            echo "No agents found"
            exit 1
        fi

        echo "Testing agent: $AGENT_ID"

        # Check user info
        echo ""
        echo "User info:"
        docker exec lumenmon-console getent passwd "$AGENT_ID"

        # Check home directory
        echo ""
        echo "Home directory contents:"
        docker exec lumenmon-console ls -la "/data/agents/$AGENT_ID/" 2>&1
        docker exec lumenmon-console ls -la "/data/agents/$AGENT_ID/.ssh/" 2>&1

        # Check SSH config
        echo ""
        echo "SSH daemon config for user match:"
        docker exec lumenmon-console /usr/sbin/sshd -T -C user="$AGENT_ID",host=localhost,addr=127.0.0.1 2>&1 | grep -E "(forcecommand|authorizedkeysfile|passwordauth)"

        # Test SSH directly from agent
        echo ""
        echo "Testing SSH from agent container:"
        docker exec lumenmon-agent ssh -v -o LogLevel=DEBUG \
            -i /home/metrics/.ssh/id_ed25519 \
            -p 2345 \
            "$AGENT_ID@localhost" echo "Connection successful" 2>&1 | grep -E "(debug1: Authentications|debug1: Next authentication|denied|Accepted|Connection)"
        ;;

    ssh-test)
        echo "Testing SSH connection..."
        docker exec lumenmon-console sh -c "ps aux | grep sshd"
        echo ""
        echo "SSH host keys:"
        docker exec lumenmon-console ls -la /etc/ssh/ssh_host* 2>&1 || echo "No host keys"
        echo ""
        echo "Data directory:"
        docker exec lumenmon-console ls -la /data/ 2>&1
        echo ""
        echo "Agents directory:"
        docker exec lumenmon-console ls -la /data/agents/ 2>&1
        echo ""
        echo "SSH config test:"
        docker exec lumenmon-console /usr/sbin/sshd -T 2>&1 | grep -E "^(port|forcecommand|match)" | head -20
        ;;

    rebuild)
        echo "Rebuilding everything..."
        # Stop containers
        docker stop lumenmon-console lumenmon-agent 2>/dev/null || true
        docker rm lumenmon-console lumenmon-agent 2>/dev/null || true
        # Clean data properly
        # Agent data - remove everything but keep directory structure
        rm -rf agent/data/debug/* 2>/dev/null || true
        rm -rf agent/data/ssh/* 2>/dev/null || true
        # Console data - remove agent directories and SSH host keys
        rm -rf console/data/agents/id_* 2>/dev/null || true
        rm -f console/data/ssh/ssh_host* 2>/dev/null || true
        # Ensure directories exist with gitkeep
        mkdir -p agent/data/debug agent/data/ssh
        mkdir -p console/data/agents console/data/ssh
        touch agent/data/.gitkeep agent/data/debug/.gitkeep agent/data/ssh/.gitkeep
        touch console/data/.gitkeep console/data/agents/.gitkeep console/data/ssh/.gitkeep
        # Start fresh
        cd console && docker compose up -d --build && cd ..
        cd agent && CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose up -d --build && cd ..
        echo "Rebuilt! Use './dev.sh tui' to register agents"
        ;;

    *)
        echo "Usage: ./dev.sh [command]"
        echo ""
        echo "Commands:"
        echo "  clean      - Clean data directories"
        echo "  console    - Start console container"
        echo "  agent      - Start agent container"
        echo "  rebuild    - Stop, clean, and restart everything"
        echo "  tui        - Open TUI (use to register agents)"
        echo "  stop       - Stop all containers"
        echo "  logs [console|agent] - Show logs"
        echo "  ssh-debug  - Debug SSH connection for agents"
        echo "  ssh-test   - Test SSH daemon and config"
        ;;
esac