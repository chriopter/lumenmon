#!/bin/sh
# Lumenmon Coordinator - Orchestrates metric collection and shipping
# Supports interval-based collection: allegro (fast), andante (medium), adagio (slow)

# === CONFIGURATION ===
# Note: SERVER_URL can be updated at runtime by tunnel setup
DEBUG="${DEBUG:-0}"
REQUESTED_INTERVAL="$1"  # allegro, andante, adagio, or empty for all

# === FUNCTIONS ===
log() {
    [ "$DEBUG" = "1" ] && echo "[collect] $1" >&2
}

# OS Detection Function
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

check_interval() {
    local script=$1
    local requested=$2
    
    # If no interval requested, run everything
    [ -z "$requested" ] && return 0
    
    # Extract INTERVAL from script
    local script_interval=$(grep "^INTERVAL=" "$script" 2>/dev/null | cut -d'"' -f2)
    
    # Check if interval matches
    [ "$script_interval" = "$requested" ] && return 0
    return 1
}

run_folder_collectors() {
    local folder=$1
    local output=""
    
    if [ -d "$folder" ]; then
        log "Running $folder collectors (interval: ${REQUESTED_INTERVAL:-all})..."
        for script in $folder/*.sh; do
            if [ -f "$script" ] && [ -x "$script" ]; then
                # Check if interval matches
                if check_interval "$script" "$REQUESTED_INTERVAL"; then
                    log "  - $(basename $script)"
                    result=$($script 2>/dev/null)
                    [ -n "$result" ] && output="${output}${result}\n"
                fi
            fi
        done
    fi
    
    echo -e "$output"
}

# === COLLECTOR EXECUTION ===
run_collectors() {
    local output=""
    
    # Detect OS type
    OS_TYPE=$(detect_os)
    log "Detected OS: $OS_TYPE"
    
    # ALWAYS run generic collectors
    output="${output}$(run_folder_collectors "generic")"
    
    # Run OS-specific collectors based on detection
    case "$OS_TYPE" in
        debian|ubuntu)
            output="${output}$(run_folder_collectors "debian")"
            ;;
        
        proxmox)
            # Proxmox is Debian-based, run both
            output="${output}$(run_folder_collectors "debian")"
            output="${output}$(run_folder_collectors "proxmox")"
            ;;
        
        alpine)
            # Alpine-specific collectors (if any)
            output="${output}$(run_folder_collectors "alpine")"
            ;;
        
        redhat|centos)
            # RedHat/CentOS collectors (future)
            output="${output}$(run_folder_collectors "redhat")"
            ;;
        
        arch)
            # Arch Linux collectors (future)
            output="${output}$(run_folder_collectors "arch")"
            ;;
        
        *)
            log "No OS-specific collectors for: $OS_TYPE"
            ;;
    esac
    
    echo -e "$output"
}

# === MAIN EXECUTION ===
echo "$(date '+%H:%M:%S') - Collection cycle [${REQUESTED_INTERVAL:-all}]"

# Collect metrics and pipe through shipper
OUTPUT=$(run_collectors)

# === DATA TRANSMISSION ===
if [ -n "$OUTPUT" ]; then
    # Pipe through shipper for JSON conversion and sending
    # Pass interval as first argument so shipper can set numeric interval
    # Use current SERVER_URL (may be updated by tunnel setup)
    if echo "$OUTPUT" | ./shipper.sh "${REQUESTED_INTERVAL:-unknown}" "${SERVER_URL:-http://localhost:8080}/metrics"; then
        echo "$(date '+%H:%M:%S') - Metrics [${REQUESTED_INTERVAL:-all}] shipped"
    else
        echo "$(date '+%H:%M:%S') - Failed to ship metrics"
    fi
else
    echo "$(date '+%H:%M:%S') - No metrics collected"
fi