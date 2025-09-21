#!/bin/bash
# Validation and prerequisite checks

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/chriopter/lumenmon.git"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.lumenmon}"

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}→${NC} $1"
}

check_prerequisites() {
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi

    # Check Git
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed"
        exit 1
    fi

    # Clone or update repository
    if [ -d "$INSTALL_DIR/.git" ]; then
        print_info "Updating Lumenmon..."
        cd "$INSTALL_DIR"
        git pull --ff-only --quiet
        print_success "Updated successfully"
    else
        print_info "Installing Lumenmon to $INSTALL_DIR..."
        git clone --quiet "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        print_success "Repository cloned successfully"
    fi

    # Verify we have the required directories
    if [ ! -d "console" ] || [ ! -d "agent" ]; then
        print_error "Repository structure invalid"
        exit 1
    fi
}