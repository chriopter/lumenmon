#!/bin/sh
# OS Detection Script
# Sets OS_TYPE variable for use by other scripts

# === DETECT OS TYPE ===
detect_os() {
    OS_TYPE="unknown"
    
    # Check /proc/version for kernel hints (works with pid: host)
    if [ -f /proc/version ]; then
        KERNEL_INFO=$(cat /proc/version)
        
        # Detect specific distributions
        if echo "$KERNEL_INFO" | grep -q "pve"; then
            OS_TYPE="proxmox"
        elif echo "$KERNEL_INFO" | grep -qi "debian"; then
            OS_TYPE="debian"
        elif echo "$KERNEL_INFO" | grep -qi "ubuntu"; then
            OS_TYPE="ubuntu"
        elif echo "$KERNEL_INFO" | grep -qi "red hat\|centos\|rhel"; then
            OS_TYPE="redhat"
        elif echo "$KERNEL_INFO" | grep -qi "alpine"; then
            OS_TYPE="alpine"
        elif echo "$KERNEL_INFO" | grep -qi "arch"; then
            OS_TYPE="arch"
        elif echo "$KERNEL_INFO" | grep -qi "suse"; then
            OS_TYPE="suse"
        fi
    fi
    
    # Fallback: Check for OS-specific processes (via pid: host)
    if [ "$OS_TYPE" = "unknown" ]; then
        # Check for systemd
        if ps aux 2>/dev/null | grep -q "[s]ystemd"; then
            OS_TYPE="systemd-linux"
        fi
    fi
    
    echo "$OS_TYPE"
}

# Export the detected OS type
OS_TYPE=$(detect_os)
export OS_TYPE

# If script is run directly, output the OS type
if [ "${0##*/}" = "detect_os.sh" ]; then
    echo "Detected OS: $OS_TYPE"
fi