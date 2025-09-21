#!/bin/bash
# Image fetching and building

# Colors
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
GITHUB_OWNER="${GITHUB_OWNER:-chriopter}"
REGISTRY="ghcr.io"

print_info() {
    echo -e "${BLUE}→${NC} $1"
}

fetch_image() {
    echo ""
    print_info "Preparing ${COMPONENT} (${VERSION})..."

    if [ "$VERSION" = "local" ]; then
        print_info "Will build from local source..."
        # No fetch needed for local build
        export LUMENMON_IMAGE=""
    else
        print_info "Pulling from GHCR..."
        IMAGE="${REGISTRY}/${GITHUB_OWNER}/lumenmon-${COMPONENT}:${VERSION}"

        docker pull "$IMAGE"

        # Set image for deploy phase
        export LUMENMON_IMAGE="$IMAGE"
    fi
}