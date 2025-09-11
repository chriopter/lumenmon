#!/bin/bash
# Single Client Spawner - Builds latest image and runs one client
# Usage: ./spawnclient.sh [-d]  # -d for detached mode

DETACHED=""
if [ "$1" = "-d" ]; then
    DETACHED="-d"
fi

echo "🔨 Building latest client image..."
cd "$(dirname "$0")/client" && docker build -t lumenmon-client . || {
    echo "❌ Failed to build client image"
    exit 1
}

CLIENT_NAME="client-$(date +%s%N | cut -c10-16)"
mkdir -p /tmp/$CLIENT_NAME

if [ -z "$DETACHED" ]; then
    echo "🚀 Spawning single client (foreground)..."
    echo "📂 Client: $CLIENT_NAME"
    echo "🔑 Keys: /tmp/$CLIENT_NAME"
    echo "🌐 Tunnel: SSH to localhost:2222 → localhost:8081"
    echo ""
else
    echo "✅ Started $CLIENT_NAME with keys in /tmp/$CLIENT_NAME"
fi

docker run $DETACHED --rm --name $CLIENT_NAME --hostname $CLIENT_NAME --network host \
  -e SSH_SERVER=localhost -e SSH_PORT=2222 -e TRANSPORT=tunnel -e DEBUG=1 \
  -v /tmp/$CLIENT_NAME:/etc/lumenmon lumenmon-client