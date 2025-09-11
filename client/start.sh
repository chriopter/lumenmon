#!/bin/sh
# Lumenmon Client Startup Script
# Manages forwarders and tempo-based collectors

# Start forwarders in background
/forwarders/webhook.sh &
/forwarders/smtp.sh &

# Move to collectors directory
cd /collectors

# Start tempo-based collectors
echo "Starting Allegro collector - ${ALLEGRO_INTERVAL:-5}s"
while true; do
    ./collect.sh allegro
    sleep ${ALLEGRO_INTERVAL:-5}
done &

echo "Starting Andante collector - ${ANDANTE_INTERVAL:-60}s"
while true; do
    ./collect.sh andante
    sleep ${ANDANTE_INTERVAL:-60}
done &

echo "Starting Adagio collector - ${ADAGIO_INTERVAL:-3600}s"
while true; do
    ./collect.sh adagio
    sleep ${ADAGIO_INTERVAL:-3600}
done &

# Keep container running
wait