#!/bin/bash
# Lumenmon Installer - KISS & Bulletproof
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/chriopter/lumenmon.git"
INSTALL_DIR="$HOME/.lumenmon"

echo "================================"
echo "      Lumenmon Installer"
echo "================================"
echo ""

# Check for Docker
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check for Docker Compose
if ! docker compose version >/dev/null 2>&1 && ! docker-compose version >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    echo "Please install Docker Compose first"
    exit 1
fi

# Smart clone/update
if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "${BLUE}📦 Updating Lumenmon...${NC}"
    cd "$INSTALL_DIR"
    git pull --ff-only --quiet
    echo -e "${GREEN}✓ Updated successfully${NC}"
else
    echo -e "${BLUE}📦 Installing Lumenmon...${NC}"
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo -e "${GREEN}✓ Installed successfully${NC}"
fi

# Ensure data directories exist (these are gitignored)
mkdir -p "$INSTALL_DIR/console/data"
mkdir -p "$INSTALL_DIR/agent/data"

# Menu
echo ""
echo "What would you like to do?"
echo ""
echo "  1) Install/Start Console"
echo "  2) Install/Start Agent"
echo "  3) Install/Start Both"
echo "  4) Update Containers"
echo "  5) Stop All"
echo ""
read -p "Enter choice [1-5]: " choice

case $choice in
    1)
        # Install Console
        echo -e "${BLUE}Starting Console...${NC}"
        cd "$INSTALL_DIR/console"
        docker-compose up -d

        # Get console IP
        CONSOLE_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

        echo ""
        echo -e "${GREEN}✅ Console is running!${NC}"
        echo ""
        echo "📊 Access the dashboard:"
        echo -e "${YELLOW}   docker exec -it lumenmon-console python3 /usr/local/bin/tui.py${NC}"
        echo ""
        echo "📝 For remote agents, use this Console IP: ${CONSOLE_IP}"
        ;;

    2)
        # Install Agent
        echo -e "${BLUE}Configuring Agent...${NC}"

        # Load existing config if it exists
        CURRENT_HOST="lumenmon-console"
        if [ -f "$INSTALL_DIR/agent/data/.env" ]; then
            source "$INSTALL_DIR/agent/data/.env"
            CURRENT_HOST="${CONSOLE_HOST:-lumenmon-console}"
        fi

        # Always ask for Console host (showing current value)
        echo "Current Console host: ${CURRENT_HOST}"
        read -p "Enter Console hostname/IP [${CURRENT_HOST}]: " NEW_HOST
        CONSOLE_HOST=${NEW_HOST:-$CURRENT_HOST}

        # Save configuration
        echo "CONSOLE_HOST=$CONSOLE_HOST" > "$INSTALL_DIR/agent/data/.env"
        echo -e "${GREEN}✓ Configuration saved${NC}"

        echo -e "${BLUE}Starting Agent...${NC}"
        cd "$INSTALL_DIR/agent"
        docker-compose up -d

        echo ""
        echo -e "${GREEN}✅ Agent is running!${NC}"
        echo "   Connected to console: $CONSOLE_HOST"
        ;;

    3)
        # Install Both
        echo -e "${BLUE}Starting Console and Agent...${NC}"

        cd "$INSTALL_DIR/console"
        docker-compose up -d

        # Ask if agent should use local or remote console
        echo ""
        echo "Agent configuration:"
        echo "  1) Use local console (same machine)"
        echo "  2) Use remote console (different machine)"
        read -p "Choice [1]: " AGENT_CHOICE

        if [ "${AGENT_CHOICE}" == "2" ]; then
            read -p "Enter Console hostname/IP: " CONSOLE_HOST
            echo "CONSOLE_HOST=$CONSOLE_HOST" > "$INSTALL_DIR/agent/data/.env"
        else
            # Default to local console
            echo "CONSOLE_HOST=lumenmon-console" > "$INSTALL_DIR/agent/data/.env"
        fi

        cd "$INSTALL_DIR/agent"
        docker-compose up -d

        echo ""
        echo -e "${GREEN}✅ Console and Agent are running!${NC}"
        echo ""
        echo "📊 Access the dashboard:"
        echo -e "${YELLOW}   docker exec -it lumenmon-console python3 /usr/local/bin/tui.py${NC}"
        ;;

    4)
        # Update containers
        echo -e "${BLUE}Updating containers...${NC}"

        if [ -d "$INSTALL_DIR/console" ]; then
            cd "$INSTALL_DIR/console"
            docker-compose pull
            docker-compose up -d
        fi

        if [ -d "$INSTALL_DIR/agent" ]; then
            cd "$INSTALL_DIR/agent"
            docker-compose pull
            docker-compose up -d
        fi

        echo -e "${GREEN}✅ Containers updated${NC}"
        ;;

    5)
        # Stop all
        echo -e "${BLUE}Stopping all containers...${NC}"

        cd "$INSTALL_DIR"
        [ -d console ] && (cd console && docker-compose down)
        [ -d agent ] && (cd agent && docker-compose down)

        echo -e "${GREEN}✅ All containers stopped${NC}"
        ;;

    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo "To run this installer again:"
echo -e "${BLUE}curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash${NC}"
echo ""