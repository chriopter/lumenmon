#!/bin/bash
# Test the new pipeline: collectors → shipper → sink

echo "=== Testing New Pipeline ==="

# Test 1: Direct metric to shipper
echo "Testing shipper with simple metric..."
echo "test_metric:42:int:5" | ./client/collectors/shipper.sh http://localhost:8080/metrics

# Test 2: Multiple metrics
echo "Testing multiple metrics..."
(
echo "cpu_test:55.5:float:5"
echo "memory_test:1024:int:5"
echo "hostname_test:testserver:string:3600"
) | ./client/collectors/shipper.sh http://localhost:8080/metrics

# Test 3: Run a real collector through shipper
echo "Testing real collector..."
./client/collectors/generic/cpu.sh | ./client/collectors/shipper.sh http://localhost:8080/metrics

# Test 4: Test coordinator with specific tempo
echo "Testing coordinator with allegro tempo..."
cd client/collectors && ./coordinator.sh allegro

echo "=== Pipeline Test Complete ==="
echo "Check the dashboard at http://localhost:8501 to see the metrics"