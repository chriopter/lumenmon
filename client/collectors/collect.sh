#!/bin/sh
# Lumenmon Collector - Main collection orchestrator
# Detects OS and runs appropriate collectors

# === CONFIGURATION ===
SERVER="${SERVER_URL:-http://localhost:8080}/metrics"
DEBUG="${DEBUG:-0}"

# === FUNCTIONS ===
log() {
    [ "$DEBUG" = "1" ] && echo "[collect] $1" >&2
}

run_folder_collectors() {
    local folder=$1
    local output=""
    
    if [ -d "$folder" ]; then
        log "Running $folder collectors..."
        for script in $folder/*.sh; do
            if [ -f "$script" ] && [ -x "$script" ]; then
                log "  - $(basename $script)"
                result=$($script 2>/dev/null)
                [ -n "$result" ] && output="${output}${result}\n"
            fi
        done
    fi
    
    echo -e "$output"
}

# === COLLECTOR EXECUTION ===
run_collectors() {
    local output=""
    
    # Source OS detection
    . ./detect_os.sh
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
echo "$(date '+%H:%M:%S') - Starting collection cycle"

# Collect metrics
OUTPUT=$(run_collectors)

# === DATA TRANSMISSION ===
if [ -n "$OUTPUT" ]; then
    # Send to server
    if echo "$OUTPUT" | curl -X POST --data-binary @- "$SERVER" -s; then
        echo "$(date '+%H:%M:%S') - Metrics sent successfully"
    else
        echo "$(date '+%H:%M:%S') - Failed to send metrics"
    fi
else
    echo "$(date '+%H:%M:%S') - No metrics collected"
fi