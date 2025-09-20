#!/bin/bash
# Queue registration for processing
read -r PUBLIC_KEY
mkdir -p /data/registration_queue
echo "$PUBLIC_KEY" > "/data/registration_queue/$(whoami).key"
echo "[REGISTER] Queued for processing"