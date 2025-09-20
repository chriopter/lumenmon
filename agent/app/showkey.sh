#!/bin/bash
# Show agent's public SSH key

set -euo pipefail

# Check for ED25519 key first, then RSA
KEY_PATH="/home/metrics/.ssh/id_ed25519.pub"
if [ ! -f "$KEY_PATH" ]; then
    KEY_PATH="/home/metrics/.ssh/id_rsa.pub"
fi

if [ -f "$KEY_PATH" ]; then
    echo "======================================"
    echo "Agent Public Key:"
    echo "======================================"
    cat "$KEY_PATH"
    echo "======================================"
else
    echo "No SSH key found"
    echo "Run the agent first to generate a key"
fi