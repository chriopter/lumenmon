#!/usr/bin/env python3
# Helper script to publish MQTT messages from shell scripts.
# Usage: mqtt_publish.py <topic> <message> [--host HOST] [--port PORT]

import sys
import paho.mqtt.client as mqtt
import argparse
import time

def main():
    parser = argparse.ArgumentParser(description='Publish MQTT message')
    parser.add_argument('topic', help='MQTT topic')
    parser.add_argument('message', help='Message payload')
    parser.add_argument('--host', default='localhost', help='MQTT broker host')
    parser.add_argument('--port', type=int, default=1883, help='MQTT broker port')
    parser.add_argument('--timeout', type=int, default=5, help='Connection timeout in seconds')

    args = parser.parse_args()

    connected = False
    published = False
    error = None

    def on_connect(client, userdata, flags, rc):
        nonlocal connected, error
        if rc == 0:
            connected = True
        else:
            error = f"Connection failed with code {rc}"

    def on_publish(client, userdata, mid):
        nonlocal published
        published = True

    try:
        client = mqtt.Client()
        client.on_connect = on_connect
        client.on_publish = on_publish

        client.connect(args.host, args.port, 60)

        # Wait for connection
        start_time = time.time()
        while not connected and error is None and (time.time() - start_time) < args.timeout:
            client.loop(timeout=0.1)

        if not connected:
            if error:
                print(f"Error: {error}", file=sys.stderr)
            else:
                print(f"Error: Connection timeout", file=sys.stderr)
            return 1

        # Now publish the message
        try:
            client.publish(args.topic, args.message)
        except Exception as e:
            print(f"Error publishing: {e}", file=sys.stderr)
            return 1

        # Wait for publish confirmation
        start_time = time.time()
        while not published and (time.time() - start_time) < 2:
            client.loop(timeout=0.1)

        # Disconnect cleanly
        client.disconnect()
        client.loop(timeout=0.1)

        if published:
            return 0
        elif error:
            print(f"Error: {error}", file=sys.stderr)
            return 1
        else:
            print(f"Error: Timeout after {args.timeout} seconds", file=sys.stderr)
            return 1

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
