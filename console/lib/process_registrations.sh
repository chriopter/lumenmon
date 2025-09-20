#!/bin/bash
# Process registration queue (runs as root)
# Called periodically to process pending registrations

QUEUE_DIR="/data/registration_queue"
mkdir -p "$QUEUE_DIR"

# Process each pending registration
for keyfile in "$QUEUE_DIR"/reg_*.key; do
    [ -f "$keyfile" ] || continue

    REG_USER=$(basename "$keyfile" .key)

    echo "[PROCESS] Processing registration for $REG_USER"

    # Read the public key
    PUBLIC_KEY=$(cat "$keyfile")

    # Create real agent user (will validate key and create user)
    if /app/lib/add_agent.sh "$PUBLIC_KEY"; then
        echo "[PROCESS] Agent user created successfully"

        # Clean up registration user and files
        userdel -r "$REG_USER" 2>/dev/null && echo "[PROCESS] Removed temporary user $REG_USER"
        rm -f "/tmp/.invite_${REG_USER}" 2>/dev/null
    else
        echo "[PROCESS] Failed to create agent user"
    fi

    # Always remove the key file after processing
    rm -f "$keyfile"
done