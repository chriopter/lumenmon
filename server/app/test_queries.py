#!/usr/bin/env python3
import sqlite3
import sys
import os

# Use the same path as in container
DB_PATH = '/lumenmon/server/data/lumenmon.db'

def test_latest_metrics():
    conn = sqlite3.connect(DB_PATH)
    print("=== TESTING get_latest_metrics QUERY ===")
    
    query = """
    SELECT 
        host as hostname,
        metric_name,
        metric_value as value,
        timestamp
    FROM metrics m1
    WHERE timestamp = (
        SELECT MAX(timestamp) 
        FROM metrics m2 
        WHERE m2.host = m1.host 
        AND m2.metric_name = m1.metric_name
    )
    ORDER BY host, metric_name
    """
    
    cursor = conn.execute(query)
    results = cursor.fetchall()
    print(f"Found {len(results)} results")
    for row in results[:5]:
        print(row)
    
    conn.close()
    return len(results) > 0

def test_hosts():
    conn = sqlite3.connect(DB_PATH)
    print("\n=== TESTING get_hosts QUERY ===")
    
    query = """
    SELECT DISTINCT host 
    FROM metrics 
    ORDER BY host
    """
    
    cursor = conn.execute(query)
    results = cursor.fetchall()
    print(f"Found hosts: {results}")
    
    conn.close()
    return len(results) > 0

def test_time_series():
    conn = sqlite3.connect(DB_PATH)
    print("\n=== TESTING get_time_series QUERY ===")
    
    # Test with fallback
    query = """
    SELECT 
        host as hostname,
        metric_name,
        metric_value as value,
        timestamp
    FROM metrics
    ORDER BY timestamp DESC
    LIMIT 10
    """
    
    cursor = conn.execute(query)
    results = cursor.fetchall()
    print(f"Found {len(results)} time series records")
    for row in results[:3]:
        print(row)
    
    conn.close()
    return len(results) > 0

if __name__ == "__main__":
    if not os.path.exists(DB_PATH):
        print(f"ERROR: Database not found at {DB_PATH}")
        sys.exit(1)
    
    all_good = True
    all_good = test_latest_metrics() and all_good
    all_good = test_hosts() and all_good
    all_good = test_time_series() and all_good
    
    if all_good:
        print("\n✅ All queries return data!")
    else:
        print("\n❌ Some queries failed!")