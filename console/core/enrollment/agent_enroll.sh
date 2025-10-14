#!/bin/bash
# Processes registration queue and creates permanent agent Linux users with SSH access.
# Validates public keys, generates agent IDs from fingerprints, creates users and home directories.
set -euo pipefail

QUEUE_DIR="/data/registration_queue"
mkdir -p "$QUEUE_DIR"

# Function to create agent user
create_agent_user() {
    local PUBLIC_KEY="$1"

    # Validate it's a valid SSH key
    if ! echo "$PUBLIC_KEY" | ssh-keygen -lf - >/dev/null 2>&1; then
        echo "[ENROLL] ERROR: Invalid SSH key"
        return 1
    fi

    # Generate fingerprint with id_ prefix
    FINGERPRINT="id_$(echo "$PUBLIC_KEY" | ssh-keygen -lf - | awk '{print $2}' | cut -d: -f2 | tr '/+' '_-' | cut -c1-14)"

    # Check if already exists
    if id "$FINGERPRINT" &>/dev/null; then
        echo "[ENROLL] Agent already exists: $FINGERPRINT"
        return 0
    fi

    # Ensure base directory exists
    mkdir -p "/data/agents"

    # Create the home directory first (since it's a mounted volume)
    mkdir -p "/data/agents/$FINGERPRINT/.ssh"

    # Ensure agents group exists (should already exist from setup)
    if ! getent group agents > /dev/null 2>&1; then
        groupadd agents
    fi

    # Create Linux user WITHOUT -m flag (home already exists) and add to agents group
    echo "[ENROLL] Creating new agent user: $FINGERPRINT"
    useradd -d "/data/agents/$FINGERPRINT" -s /bin/sh -G agents "$FINGERPRINT"

    # Unlock the account (set to no password for SSH key-only auth)
    usermod -p '' "$FINGERPRINT"

    # Setup SSH access
    echo "$PUBLIC_KEY" > "/data/agents/$FINGERPRINT/.ssh/authorized_keys"

    # Fix ownership and permissions
    chown -R "$FINGERPRINT:$FINGERPRINT" "/data/agents/$FINGERPRINT"
    chmod 700 "/data/agents/$FINGERPRINT" "/data/agents/$FINGERPRINT/.ssh"
    chmod 600 "/data/agents/$FINGERPRINT/.ssh/authorized_keys"

    # Log
    echo "[$(date)] Enrolled agent: $FINGERPRINT" >> /data/agents.log

    echo "[ENROLL] Agent enrolled: $FINGERPRINT"
    return 0
}

# Process each pending enrollment
for keyfile in "$QUEUE_DIR"/reg_*.key; do
    [ -f "$keyfile" ] || continue

    REG_USER=$(basename "$keyfile" .key)

    echo "[ENROLL] Processing enrollment for $REG_USER"

    # Read the public key
    PUBLIC_KEY=$(cat "$keyfile")

    # Create real agent user
    if create_agent_user "$PUBLIC_KEY"; then
        echo "[ENROLL] Agent enrollment successful"

        # Clean up registration user and files
        userdel -r "$REG_USER" 2>/dev/null && echo "[ENROLL] Removed temporary user $REG_USER"
        rm -f "/tmp/.invite_${REG_USER}" 2>/dev/null
    else
        echo "[ENROLL] Failed to enroll agent"
    fi

    # Always remove the key file after processing
    rm -f "$keyfile"
done