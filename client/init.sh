#!/bin/sh
# Lumenmon Client Initialization
# Generates SSH key on first run and registers with server

KEY_FILE="/etc/lumenmon/id_rsa"
HOSTNAME=$(hostname)
SERVER_HOST="${SSH_SERVER:-localhost}"
SERVER_PORT="${SERVER_PORT:-8080}"

# Create config directory
mkdir -p /etc/lumenmon

# Generate SSH key if not exists
if [ ! -f "$KEY_FILE" ]; then
    echo "[INIT] Generating SSH keypair for client..."
    ssh-keygen -t rsa -b 2048 -f "$KEY_FILE" -N "" -C "lumenmon@$HOSTNAME" >/dev/null 2>&1
    
    if [ -f "${KEY_FILE}.pub" ]; then
        PUBKEY=$(cat "${KEY_FILE}.pub")
        echo "[INIT] SSH key generated successfully"
        
        # Submit public key to server for approval
        echo "[INIT] Submitting key to server at $SERVER_HOST:$SERVER_PORT for approval..."
        
        RESPONSE=$(curl -s -X POST "http://${SERVER_HOST}:${SERVER_PORT}/register" \
            -H "Content-Type: application/json" \
            -d "{\"hostname\":\"$HOSTNAME\",\"pubkey\":\"$PUBKEY\"}" \
            -w "\nHTTP_CODE:%{http_code}" 2>/dev/null)
        
        HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
        BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")
        
        if [ "$HTTP_CODE" = "202" ]; then
            echo "[INIT] ✅ Key submitted successfully!"
            echo "[INIT] ⏳ Waiting for admin approval..."
            echo "[INIT] Admin can approve via dashboard at http://${SERVER_HOST}:8501"
        else
            echo "[INIT] ⚠️ Failed to submit key (HTTP $HTTP_CODE)"
            echo "[INIT] Response: $BODY"
            echo "[INIT] Will retry on next startup..."
        fi
    else
        echo "[INIT] ❌ Failed to generate SSH key"
        exit 1
    fi
else
    echo "[INIT] SSH key already exists at $KEY_FILE"
fi

# Show key fingerprint for verification
if [ -f "$KEY_FILE" ]; then
    FINGERPRINT=$(ssh-keygen -lf "${KEY_FILE}.pub" | awk '{print $2}')
    echo "[INIT] Client fingerprint: $FINGERPRINT"
fi