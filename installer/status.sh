#!/bin/bash
# Structured output helpers for consistent status messages

# Status indicators with colors
status_ok() {
    echo -e "[\033[1;32m✓\033[0m] $1"
}

status_error() {
    echo -e "[\033[1;31m✗\033[0m] $1"
}

status_warn() {
    echo -e "[\033[1;33m⚠\033[0m] $1"
}

status_progress() {
    echo -e "[\033[1;36m→\033[0m] $1"
}

status_prompt() {
    echo -en "[\033[1;35m?\033[0m] $1"
}

# Exit with error message
die() {
    status_error "$1"
    exit 1
}

# Check command exists
require_command() {
    if command -v "$1" >/dev/null 2>&1; then
        status_ok "$2 found"
    else
        die "$2 not found - please install $1"
    fi
}