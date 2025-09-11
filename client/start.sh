#!/bin/sh
# Lumenmon Client Startup Script
# Manages SSH tunnel, forwarders and collectors

echo "[START] Lumenmon Client starting..."

# Initialize client (generate SSH key if needed)
/init.sh

# Determine transport mode
TRANSPORT_MODE="${TRANSPORT:-tunnel}"
echo "[START] Transport mode: $TRANSPORT_MODE"

if [ "$TRANSPORT_MODE" = "tunnel" ]; then
    # Start SSH tunnel for secure transport
    echo "[START] Starting SSH tunnel manager..."
    /tunnel.sh &
    TUNNEL_PID=$!
    
    # Wait for tunnel to establish
    echo "[START] Waiting for tunnel to establish..."
    sleep 10
    
    # Override server URL to use tunnel
    export SERVER_URL="http://localhost:8080"
    echo "[START] Metrics will be sent through SSH tunnel to localhost:8080"
elif [ "$TRANSPORT_MODE" = "direct" ]; then
    # Direct HTTP mode (for local networks)
    echo "[START] Using direct HTTP to ${SERVER_URL}"
else
    echo "[START] Unknown transport mode: $TRANSPORT_MODE"
    exit 1
fi

# Start forwarders in background
echo "[START] Starting webhook forwarder..."
/forwarders/webhook.sh &

echo "[START] Starting SMTP forwarder..."
/forwarders/smtp.sh &

# Move to collectors directory
cd /collectors

# Start tempo-based collectors
echo "[START] Starting Allegro collector - ${ALLEGRO_INTERVAL:-5}s"
while true; do
    ./coordinator.sh allegro
    sleep ${ALLEGRO_INTERVAL:-5}
done &

echo "[START] Starting Andante collector - ${ANDANTE_INTERVAL:-60}s"
while true; do
    ./coordinator.sh andante
    sleep ${ANDANTE_INTERVAL:-60}
done &

echo "[START] Starting Adagio collector - ${ADAGIO_INTERVAL:-3600}s"
while true; do
    ./coordinator.sh adagio
    sleep ${ADAGIO_INTERVAL:-3600}
done &

echo "[START] All services started. Monitoring..."

# Keep container running
wait