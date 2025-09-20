#!/bin/bash
# Queue enrollment application for processing
read -r PUBLIC_KEY
mkdir -p /data/registration_queue
echo "$PUBLIC_KEY" > "/data/registration_queue/$(whoami).key"
echo "[ENROLL] Application queued for processing"