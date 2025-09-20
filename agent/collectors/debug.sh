#!/bin/bash
# Ultra-KISS debug: list collectors, run one, show live output

# Setup environment for collectors
export PULSE=1 BREATHE=1 CYCLE=1 REPORT=1
export AGENT_USER=debug CONSOLE_HOST=localhost
export SSH_SOCKET=/tmp/debug.sock

# Create fake SSH that displays data
cat > /tmp/ssh << 'EOF'
#!/bin/bash
echo "--- $(date +%H:%M:%S) ---"
cat
EOF
chmod +x /tmp/ssh

# List collectors
echo "Collectors:"
find . -name "*.sh" -not -path "./debug.sh" | nl

# Get choice and run
read -p "Number: " n
script=$(find . -name "*.sh" -not -path "./debug.sh" | sed -n "${n}p")

echo "Running $script (Ctrl+C to stop)..."
echo "----------------------------------------"

# Run with fake ssh in PATH
PATH=/tmp:$PATH $script