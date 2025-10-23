#!/usr/bin/env python3
# Single persistent MQTT connection daemon for all metrics.
# Listens on Unix socket, publishes to broker with one TLS connection.

import paho.mqtt.client as mqtt
import socket
import json
import os
import sys

# Load MQTT credentials once
MQTT_DATA_DIR = "/data/mqtt"
try:
    mqtt_host = open(f"{MQTT_DATA_DIR}/host").read().strip()
    mqtt_user = open(f"{MQTT_DATA_DIR}/username").read().strip()
    mqtt_pass = open(f"{MQTT_DATA_DIR}/password").read().strip()
except FileNotFoundError as e:
    print(f"[mqtt-publisher] ERROR: Missing credential file: {e}", file=sys.stderr, flush=True)
    sys.exit(1)

# Connect to MQTT broker with persistent TLS connection
client = mqtt.Client()
client.username_pw_set(mqtt_user, mqtt_pass)
client.tls_set(f"{MQTT_DATA_DIR}/server.crt")

try:
    client.connect(mqtt_host, 8884, 60)
    client.loop_start()
    print(f"[mqtt-publisher] Connected to {mqtt_host}:8884", flush=True)
except Exception as e:
    print(f"[mqtt-publisher] ERROR: Failed to connect to MQTT broker: {e}", file=sys.stderr, flush=True)
    sys.exit(1)

# Create Unix socket for collectors
SOCKET_PATH = "/tmp/mqtt.sock"
if os.path.exists(SOCKET_PATH):
    os.unlink(SOCKET_PATH)

sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
sock.bind(SOCKET_PATH)
print(f"[mqtt-publisher] Listening on {SOCKET_PATH}", flush=True)

# Listen for messages from collectors and publish to MQTT
while True:
    try:
        data, _ = sock.recvfrom(4096)
        msg = json.loads(data.decode())

        # Build topic and payload (include interval for staleness detection)
        topic = f"metrics/{mqtt_user}/{msg['metric']}"
        payload = json.dumps({
            "value": msg["value"],
            "type": msg["type"],
            "interval": msg.get("interval", 60)  # Default 60s if not provided
        })

        # Publish to MQTT broker
        client.publish(topic, payload)

    except json.JSONDecodeError as e:
        print(f"[mqtt-publisher] WARNING: Invalid JSON: {e}", file=sys.stderr, flush=True)
    except Exception as e:
        print(f"[mqtt-publisher] ERROR: {e}", file=sys.stderr, flush=True)
