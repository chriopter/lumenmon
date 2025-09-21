#!/bin/bash
# Setup lumenmon CLI command

source "$DIR/installer/status.sh"

# Check if already installed
if [ -L /usr/local/bin/lumenmon ] || [ -L ~/.local/bin/lumenmon ]; then
    return 0
fi

# Try to create symlink
if ln -sf "$DIR/lumenmon.sh" /usr/local/bin/lumenmon 2>/dev/null; then
    status_ok "Command 'lumenmon' installed globally"
elif mkdir -p ~/.local/bin && ln -sf "$DIR/lumenmon.sh" ~/.local/bin/lumenmon 2>/dev/null; then
    status_ok "Command 'lumenmon' installed in ~/.local/bin"
    # Check if ~/.local/bin is in PATH
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        status_warn "Add ~/.local/bin to your PATH to use 'lumenmon'"
    fi
else
    status_warn "Run commands with: $DIR/lumenmon.sh"
fi