#!/bin/sh
# Network and internet connectivity collector

# === IDENTITY ===
GROUP="generic"
COLLECTOR="network"
PREFIX="${GROUP}_${COLLECTOR}"

# === COLLECT ===
# Check internet connectivity by pinging Google DNS
if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
    INTERNET="yes"
    
    # If we have internet, measure latency
    LATENCY=$(ping -c 1 -W 1 8.8.8.8 2>/dev/null | grep 'time=' | sed 's/.*time=\([0-9.]*\).*/\1/')
else
    INTERNET="no"
    LATENCY="0"
fi

# Check if we can resolve DNS (ping google.com)
if ping -c 1 -W 1 google.com >/dev/null 2>&1; then
    DNS="yes"
else
    DNS="no"
fi

# Count network interfaces (excluding lo)
INTERFACES=$(ip link 2>/dev/null | grep -c "^[0-9]:" || echo "0")
INTERFACES=$((INTERFACES - 1))  # Exclude loopback

# Get primary IP address
PRIMARY_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' || echo "none")

# === OUTPUT ===
echo "${PREFIX}_internet:${INTERNET}"
echo "${PREFIX}_dns:${DNS}"
echo "${PREFIX}_latency_ms:${LATENCY:-0}"
echo "${PREFIX}_interfaces:${INTERFACES}"
echo "${PREFIX}_primary_ip:${PRIMARY_IP}"