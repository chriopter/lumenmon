#!/bin/bash

# Spawn 3 test client containers with random names
for i in 1 2 3; do 
    N="client-$(date +%s%N | cut -c10-16)"
    docker run -d --rm --name $N --hostname $N --network host -e SSH_SERVER=localhost -e TRANSPORT=tunnel lumenmon-client
    echo "Started $N"
done

echo ""
echo "✅ Started 3 test clients"
echo ""
echo "Commands:"
echo "  Check dashboard:  http://localhost:8501"
echo "  View clients:     docker ps | grep ^client-"
echo "  Stop all:         docker ps --format '{{.Names}}' | grep '^client-' | xargs -r docker stop"
echo "  View logs:        docker logs <client-name>"