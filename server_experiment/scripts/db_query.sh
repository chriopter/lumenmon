#!/bin/bash
# Database query helper functions for Lumenmon TUI

DB_PATH="${DB_PATH:-/app/data/lumenmon.db}"

# Get all approved clients
get_clients() {
    sqlite3 -separator '|' "$DB_PATH" "
        SELECT id, hostname, last_seen, fingerprint
        FROM clients 
        WHERE status = 'approved'
        ORDER BY hostname
    " 2>/dev/null || echo ""
}

# Get pending registrations
get_pending_registrations() {
    sqlite3 -separator '|' "$DB_PATH" "
        SELECT fingerprint, hostname, first_seen, attempt_count
        FROM pending_registrations
        ORDER BY first_seen DESC
    " 2>/dev/null || echo ""
}

# Get latest metric value for a client
get_metric() {
    local client_id=$1
    local metric_name=$2
    
    result=$(sqlite3 "$DB_PATH" "
        SELECT metric_value 
        FROM metrics_${client_id}
        WHERE metric_name = '${metric_name}'
        AND metric_value IS NOT NULL
        ORDER BY timestamp DESC
        LIMIT 1
    " 2>/dev/null)
    
    echo "${result:-0}"
}

# Check if client is online (data in last 30 seconds)
is_client_online() {
    local client_id=$1
    
    count=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(*) 
        FROM metrics_${client_id}
        WHERE timestamp > datetime('now', '-30 seconds')
    " 2>/dev/null)
    
    [ "${count:-0}" -gt 0 ]
}

# Get client statistics
get_client_stats() {
    local client_id=$1
    
    cpu=$(get_metric "$client_id" "generic_cpu_usage")
    mem=$(get_metric "$client_id" "generic_memory_percent")
    load=$(get_metric "$client_id" "generic_cpu_load")
    uptime=$(get_metric "$client_id" "generic_system_uptime_seconds")
    
    echo "$cpu|$mem|$load|$uptime"
}

# Get time series data for charts
get_time_series() {
    local client_id=$1
    local metric_name=$2
    local duration="${3:--1 hour}"
    
    sqlite3 -separator '|' "$DB_PATH" "
        SELECT 
            strftime('%H:%M', timestamp) as time,
            ROUND(metric_value, 1) as value
        FROM metrics_${client_id}
        WHERE metric_name = '${metric_name}'
        AND metric_value IS NOT NULL
        AND timestamp > datetime('now', '${duration}')
        ORDER BY timestamp ASC
    " 2>/dev/null
}

# Get fleet-wide statistics
get_fleet_stats() {
    local total=0
    local online=0
    local total_cpu=0
    local total_mem=0
    local count=0
    
    while IFS='|' read -r id hostname last_seen fingerprint; do
        ((total++))
        
        if is_client_online "$id"; then
            ((online++))
        fi
        
        cpu=$(get_metric "$id" "generic_cpu_usage")
        mem=$(get_metric "$id" "generic_memory_percent")
        
        total_cpu=$(echo "$total_cpu + $cpu" | bc)
        total_mem=$(echo "$total_mem + $mem" | bc)
        ((count++))
    done < <(get_clients)
    
    if [ $count -gt 0 ]; then
        avg_cpu=$(echo "scale=1; $total_cpu / $count" | bc)
        avg_mem=$(echo "scale=1; $total_mem / $count" | bc)
    else
        avg_cpu=0
        avg_mem=0
    fi
    
    echo "$total|$online|$avg_cpu|$avg_mem"
}

# Approve a pending client
approve_client() {
    local fingerprint=$1
    
    # Get client info
    client_info=$(sqlite3 -separator '|' "$DB_PATH" "
        SELECT hostname, pubkey
        FROM pending_registrations
        WHERE fingerprint = '${fingerprint}'
        LIMIT 1
    ")
    
    if [ -z "$client_info" ]; then
        return 1
    fi
    
    IFS='|' read -r hostname pubkey <<< "$client_info"
    
    # Insert into clients table
    sqlite3 "$DB_PATH" "
        INSERT OR REPLACE INTO clients (hostname, pubkey, fingerprint, status, created_at, last_seen)
        VALUES ('${hostname}', '${pubkey}', '${fingerprint}', 'approved', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    "
    
    # Remove from pending
    sqlite3 "$DB_PATH" "
        DELETE FROM pending_registrations WHERE fingerprint = '${fingerprint}'
    "
    
    return 0
}

# Reject a pending client
reject_client() {
    local fingerprint=$1
    
    sqlite3 "$DB_PATH" "
        DELETE FROM pending_registrations WHERE fingerprint = '${fingerprint}'
    "
    
    return 0
}