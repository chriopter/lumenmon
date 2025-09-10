#!/bin/bash
# Test webhook forwarder with various payloads

echo "Testing Lumenmon Webhook Forwarder on port 9090"
echo "================================================"

# Test 1: Simple text message
echo -e "\n1. Sending simple text message..."
curl -X POST localhost:9090/webhook \
  -d "Simple text notification from monitoring system" \
  2>/dev/null
echo " ✓"

# Test 2: JSON payload
echo -e "\n2. Sending JSON payload..."
curl -X POST localhost:9090/webhook \
  -H "Content-Type: application/json" \
  -d '{"alert": "CPU High", "host": "server01", "value": 95.5, "severity": "warning"}' \
  2>/dev/null
echo " ✓"

# Test 3: Form data
echo -e "\n3. Sending form data..."
curl -X POST localhost:9090/webhook \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "service=nginx&status=down&timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  2>/dev/null
echo " ✓"

# Test 4: GitHub-style webhook
echo -e "\n4. Sending GitHub-style webhook..."
curl -X POST localhost:9090/webhook \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{
    "ref": "refs/heads/main",
    "repository": {"name": "lumenmon", "full_name": "user/lumenmon"},
    "pusher": {"name": "developer"},
    "commits": [{"message": "Fix monitoring issue", "author": {"name": "Dev"}}]
  }' \
  2>/dev/null
echo " ✓"

# Test 5: Prometheus AlertManager webhook
echo -e "\n5. Sending Prometheus AlertManager webhook..."
curl -X POST localhost:9090/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "version": "4",
    "groupKey": "{}:{alertname=\"DiskSpaceLow\"}",
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {"alertname": "DiskSpaceLow", "instance": "localhost:9090"},
      "annotations": {"description": "Disk space is below 10%"}
    }]
  }' \
  2>/dev/null
echo " ✓"

echo -e "\n================================================"
echo "All webhooks sent! Check the feed at:"
echo "http://localhost:8080/"
echo ""
echo "To view feed data directly:"
echo "curl -s localhost:8080/api/feed | python3 -m json.tool"