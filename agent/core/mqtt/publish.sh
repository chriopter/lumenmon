#!/bin/bash
# MQTT publishing helper function for collectors.
# Abstracts socket communication with Python MQTT daemon.

publish_metric() {
    local metric_name="$1"
    local value="$2"
    local type="$3"

    # Send JSON message to Unix socket
    echo "{\"metric\":\"$metric_name\",\"value\":$value,\"type\":\"$type\"}" | \
        socat - UNIX-SENDTO:/tmp/mqtt.sock 2>/dev/null || \
        echo "[collector] WARNING: Failed to publish $metric_name" >&2
}
