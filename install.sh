#!/bin/bash
# Lumenmon Installer - Bootstrap Script
set -e

# Configuration
REPO_URL="https://github.com/chriopter/lumenmon.git"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.lumenmon}"

# Colors for output (export for use in sourced scripts)
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# Print functions (will be reused by sourced scripts)
print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}→${NC} $1"
}

# Export functions for use in sourced scripts
export -f print_error
export -f print_success
export -f print_info

# Basic prerequisite checks before cloning
if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Please install Git first."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed."
    exit 1
fi

# Clone or update the repository
if [ -d "$INSTALL_DIR/.git" ]; then
    print_info "Updating Lumenmon..."
    cd "$INSTALL_DIR"
    git pull --ff-only --quiet
    print_success "Updated successfully"
else
    print_info "Installing Lumenmon to $INSTALL_DIR..."
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    print_success "Repository cloned successfully"
fi

# Change to install directory and run the actual installer
cd "$INSTALL_DIR"

# Source all installer modules
source installer/check.sh
source installer/ask.sh
source installer/fetch.sh
source installer/deploy.sh

# Run the installation flow
check_prerequisites
ask_what_to_install
fetch_image
deploy_container