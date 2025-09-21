#!/bin/bash
# Image fetching and building

# Colors
BLUE="${BLUE:-\033[0;34m}"
GREEN="${GREEN:-\033[0;32m}"
RED="${RED:-\033[0;31m}"
NC="${NC:-\033[0m}"

# Configuration
GITHUB_OWNER="${GITHUB_OWNER:-chriopter}"
REGISTRY="ghcr.io"

# Define print functions if not already available
if ! declare -f print_info &>/dev/null; then
    print_info() {
        echo -e "${BLUE}→${NC} $1"
    }
fi

if ! declare -f print_success &>/dev/null; then
    print_success() {
        echo -e "${GREEN}✓${NC} $1"
    }
fi

if ! declare -f print_error &>/dev/null; then
    print_error() {
        echo -e "${RED}✗${NC} $1"
    }
fi

fetch_image() {
    echo ""
    print_info "Preparing ${COMPONENT} (${VERSION})..."

    if [ "$VERSION" = "local" ]; then
        print_info "Will build from local source..."
        # No fetch needed for local build
        export LUMENMON_IMAGE=""
    else
        # Map version names to actual tags
        if [ "$VERSION" = "latest" ]; then
            TAG="latest"
        elif [ "$VERSION" = "dev" ]; then
            TAG="main"  # or "dev" if you have a dev tag
        else
            TAG="$VERSION"
        fi

        print_info "Pulling image from GitHub Container Registry..."
        IMAGE="${REGISTRY}/${GITHUB_OWNER}/lumenmon-${COMPONENT}:${TAG}"

        print_info "Pulling ${IMAGE}..."
        if docker pull "$IMAGE"; then
            print_success "Image pulled successfully"
            # Set image for deploy phase
            export LUMENMON_IMAGE="$IMAGE"
        else
            print_error "Failed to pull image. Falling back to local build..."
            VERSION="local"
            export LUMENMON_IMAGE=""
        fi
    fi
}