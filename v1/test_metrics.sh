#!/bin/bash
# Test script for new metric format

echo "Testing new metric format..."

# Test new format (name:value:type:interval)
echo "Sending new format metrics..."
curl -X POST http://localhost:8080/metrics -d "
test_cpu_usage:45.2:float:5
test_memory_total:8192:int:5
test_hostname:testserver:string:3600
test_uptime:86400:int:3600
"

# Test backward compatibility (name:value)
echo "Sending old format metrics..."
curl -X POST http://localhost:8080/metrics -d "
old_cpu:65.5
old_memory:4096
old_hostname:oldserver
"

echo "Done! Check database for results."