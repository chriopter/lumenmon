#!/bin/sh
# Lumenmon Client Startup Script
# Manages SSH tunnel, forwarders and collectors

echo "[START] Lumenmon Client starting..."

# Initialize client (generate SSH key if needed)
/init.sh

# TUNNEL-ONLY MODE - No fallback allowed
echo "[START] Transport mode: tunnel-only (no fallback)"

# Set tunnel URL immediately - before any processes start
export SERVER_URL="http://localhost:8081"
echo "[START] SERVER_URL set to: $SERVER_URL"

# Start SSH tunnel for secure transport
echo "[START] Starting SSH tunnel manager..."
/tunnel.sh &
TUNNEL_PID=$!

# Wait for tunnel to establish (with retries for approval workflow)
echo "[START] Waiting for tunnel to establish (checking every 5s, max 60s)..."
TUNNEL_WAIT=0
TUNNEL_MAX_WAIT=60
TUNNEL_CHECK_INTERVAL=5

while [ $TUNNEL_WAIT -lt $TUNNEL_MAX_WAIT ]; do
    if nc -z localhost 8081 2>/dev/null; then
        echo "[START] ✅ SSH tunnel established after ${TUNNEL_WAIT}s"
        break
    fi
    echo "[START] Tunnel not ready yet (${TUNNEL_WAIT}s elapsed). Waiting for approval or retry..."
    sleep $TUNNEL_CHECK_INTERVAL
    TUNNEL_WAIT=$((TUNNEL_WAIT + TUNNEL_CHECK_INTERVAL))
done

# Final check
if ! nc -z localhost 8081 2>/dev/null; then
    echo "[START] ❌ SSH tunnel failed after ${TUNNEL_MAX_WAIT}s timeout"
    echo "[START] ❌ TUNNEL-ONLY MODE: No fallback allowed - exiting"
    kill $TUNNEL_PID 2>/dev/null
    exit 1
fi

echo "[START] ✅ SSH tunnel established - all metrics will use tunnel"

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