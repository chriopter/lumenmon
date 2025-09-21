#!/bin/bash
# Lumenmon Installer
set -e

# Get repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all installer modules
source "${REPO_ROOT}/installer/core/check.sh"
source "${REPO_ROOT}/installer/core/ask.sh"
source "${REPO_ROOT}/installer/core/fetch.sh"
source "${REPO_ROOT}/installer/core/deploy.sh"

# Main installation flow
check_prerequisites
ask_what_to_install
fetch_image
deploy_container