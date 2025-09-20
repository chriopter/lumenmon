#!/bin/bash
# Ultra-KISS debug: list collectors, run one, save output

# Setup environment for collectors
export PULSE=1 BREATHE=1 CYCLE=1 REPORT=1
export SSH_SOCKET=/dev/null AGENT_USER=debug CONSOLE_HOST=localhost

# List collectors
echo "Collectors:"
find collectors -name "*.sh" -not -path "*/debug.sh" | nl

# Get choice and run
read -p "Number: " n
script=$(find collectors -name "*.sh" -not -path "*/debug.sh" | sed -n "${n}p")
mkdir -p data/debug
echo "Running $script -> data/debug/$(basename $script .sh).log"
$script > data/debug/$(basename $script .sh).log 2>&1 &
pid=$!
sleep 2
kill $pid 2>/dev/null
echo "Sample output:"
head -5 data/debug/$(basename $script .sh).log