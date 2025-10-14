#!/bin/bash
# SSH ForceCommand for temporary registration users that queues public key for enrollment.
# Receives agent's public key via stdin and saves to registration queue for processing.
read -r PUBLIC_KEY
mkdir -p /data/registration_queue
echo "$PUBLIC_KEY" > "/data/registration_queue/$(whoami).key"
echo "[ENROLL] Application queued for processing"