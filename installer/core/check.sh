#!/bin/bash
# Validation and prerequisite checks

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_error() {
    echo -e "${RED}✗${NC} $1"
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

    # Check if we're in the right directory
    if [ ! -d "console" ] || [ ! -d "agent" ]; then
        if [ ! -d "../console" ] || [ ! -d "../agent" ]; then
            print_error "Please run this script from the lumenmon repository root"
            exit 1
        fi
        # We're in installer/, adjust path
        cd ..
    fi
}