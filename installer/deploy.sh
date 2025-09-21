#!/bin/bash
# Container deployment and lifecycle management

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}→${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

deploy_container() {
    print_info "Deploying ${COMPONENT}..."

    # Ensure we're in the install directory
    if [ ! -d "${INSTALL_DIR}/${COMPONENT}" ]; then
        print_error "Component directory not found: ${INSTALL_DIR}/${COMPONENT}"
        exit 1
    fi

    cd "${INSTALL_DIR}/${COMPONENT}"

    # Stop existing container if any
    print_info "Stopping existing containers..."
    docker compose down 2>/dev/null || true

    # Deploy based on version
    print_info "Starting ${COMPONENT} container..."
    if [ "$VERSION" = "local" ]; then
        print_info "Building from local source..."
        docker compose up -d --build
    elif [ -n "$LUMENMON_IMAGE" ]; then
        print_info "Using image: ${LUMENMON_IMAGE}"
        # Override the image in docker-compose
        export LUMENMON_IMAGE
        docker compose up -d
    else
        print_info "Building from local source (fallback)..."
        docker compose up -d --build
    fi

    if [ $? -eq 0 ]; then
        echo ""
        print_success "Installation complete!"

        # Component-specific instructions
        if [ "$COMPONENT" = "console" ]; then
            echo ""
            print_info "Console is running on port 2345"
            print_info "Create an invite: docker exec lumenmon-console /app/core/enrollment/invite_create.sh"
            print_info "Access TUI: docker exec -it lumenmon-console python3 /app/tui/main.py"
        else
            echo ""
            print_info "Agent is running"
            print_info "Register with console using an invite URL"
            print_info "Check logs: docker logs lumenmon-agent"
        fi
    else
        print_error "Deployment failed"
        exit 1
    fi

    echo ""
    print_success "Done!"
}