#!/bin/bash
# Test script to run TUI locally without Docker

echo "Testing Lumenmon TUI locally..."

# Check if database exists
if [ ! -f "../server/data/lumenmon.db" ]; then
    echo "Warning: Database not found at ../server/data/lumenmon.db"
    echo "Creating a test database..."
    
    mkdir -p ../server/data
    sqlite3 ../server/data/lumenmon.db <<EOF
CREATE TABLE IF NOT EXISTS clients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT NOT NULL,
    pubkey TEXT NOT NULL UNIQUE,
    fingerprint TEXT NOT NULL UNIQUE,
    status TEXT DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pending_registrations (
    fingerprint TEXT PRIMARY KEY,
    hostname TEXT NOT NULL,
    pubkey TEXT NOT NULL,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    attempt_count INTEGER DEFAULT 1
);

-- Insert test client
INSERT INTO clients (hostname, status, fingerprint, pubkey) 
VALUES ('test-client-01', 'approved', 'SHA256:test123', 'ssh-rsa AAAAB3test');

-- Create metrics table for test client
CREATE TABLE IF NOT EXISTS metrics_1 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    metric_name TEXT NOT NULL,
    metric_value REAL,
    metric_text TEXT,
    type TEXT DEFAULT 'float',
    interval_seconds INTEGER DEFAULT 0,
    hostname TEXT DEFAULT 'localhost'
);

-- Insert some test metrics
INSERT INTO metrics_1 (metric_name, metric_value) VALUES 
    ('generic_cpu_usage', 45.2),
    ('generic_memory_percent', 62.5),
    ('generic_cpu_load', 1.23),
    ('generic_cpu_cores', 4),
    ('generic_memory_total_kb', 8388608),
    ('generic_memory_available_kb', 3145728),
    ('generic_disk_root_usage_percent', 75.0),
    ('generic_system_uptime_seconds', 86400);
EOF
fi

# Set environment variables
export DB_PATH="../server/data/lumenmon.db"
export REFRESH_RATE=5
export AUTO_REFRESH=false

# Check if gum is available
if ! command -v gum &> /dev/null; then
    echo "Gum is not installed. The TUI requires gum to work."
    echo "Install instructions: https://github.com/charmbracelet/gum"
    echo ""
    echo "For testing, you can still run the database query functions:"
    echo ""
    
    # Source and test db functions
    source scripts/db_query.sh
    source scripts/display_metrics.sh
    
    echo "Testing database queries..."
    echo "=========================="
    echo ""
    echo "Clients in database:"
    get_clients
    echo ""
    echo "Fleet statistics:"
    get_fleet_stats
    echo ""
    echo "Client 1 CPU usage: $(get_metric 1 'generic_cpu_usage')"
    echo "Client 1 Memory: $(get_metric 1 'generic_memory_percent')%"
else
    echo "Starting TUI..."
    ./scripts/tui.sh
fi