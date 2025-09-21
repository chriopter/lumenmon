#!/bin/bash
# Validation and prerequisite checks

# Colors are already defined in install.sh if not already set
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
BLUE="${BLUE:-\033[0;34m}"
NC="${NC:-\033[0m}"

# Use existing print functions or define them if not available
if ! declare -f print_error &>/dev/null; then
    print_error() {
        echo -e "${RED}✗${NC} $1"
    }
fi

if ! declare -f print_success &>/dev/null; then
    print_success() {
        echo -e "${GREEN}✓${NC} $1"
    }
fi

if ! declare -f print_info &>/dev/null; then
    print_info() {
        echo -e "${BLUE}→${NC} $1"
    }
fi

check_prerequisites() {
    # Since install.sh already checked docker/git and cloned the repo,
    # we only need to verify the repository structure

    # Verify we have the required directories
    if [ ! -d "console" ] || [ ! -d "agent" ]; then
        print_error "Repository structure invalid"
        exit 1
    fi

    print_success "Prerequisites verified"
}