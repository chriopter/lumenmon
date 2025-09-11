#!/usr/bin/env python3
import sqlite3

DB_PATH = '/lumenmon/server/data/lumenmon.db'

conn = sqlite3.connect(DB_PATH)

# Check table structure
print("=== TABLE STRUCTURE ===")
cursor = conn.execute("PRAGMA table_info(metrics)")
for row in cursor:
    print(row)

print("\n=== DATA SUMMARY ===")
# Count records
count = conn.execute("SELECT COUNT(*) FROM metrics").fetchone()[0]
print(f"Total records: {count}")

if count > 0:
    # Get date range
    dates = conn.execute("SELECT MIN(timestamp) as oldest, MAX(timestamp) as newest FROM metrics").fetchone()
    print(f"Oldest: {dates[0]}")
    print(f"Newest: {dates[1]}")
    
    # Sample data
    print("\n=== SAMPLE DATA (last 5 records) ===")
    cursor = conn.execute("SELECT * FROM metrics ORDER BY timestamp DESC LIMIT 5")
    for row in cursor:
        print(row)
    
    # Check column names
    print("\n=== DISTINCT HOSTS ===")
    hosts = conn.execute("SELECT DISTINCT host FROM metrics").fetchall()
    print(hosts)
    
    print("\n=== DISTINCT METRIC NAMES ===")
    metrics = conn.execute("SELECT DISTINCT metric_name FROM metrics LIMIT 10").fetchall()
    print(metrics)

conn.close()