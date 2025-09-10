#!/bin/sh
# Webhook Forwarder - Simple HTTP listener on port 9090
# Uses nc (netcat) for maximum simplicity

SERVER_URL="${SERVER_URL:-http://localhost:8080}"
WEBHOOK_PORT="${WEBHOOK_PORT:-9090}"

echo "[Webhook] Starting webhook listener on port $WEBHOOK_PORT"
echo "[Webhook] Will forward to: $SERVER_URL/api/feed"

while true; do
    # Create a response file
    RESPONSE="/tmp/webhook_response"
    echo -e "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\n\r\nOK" > $RESPONSE
    
    # Listen and capture request to temp file
    TMPFILE="/tmp/webhook_request"
    nc -l -p $WEBHOOK_PORT < $RESPONSE > $TMPFILE 2>/dev/null
    
    # Process the request
    if [ -f "$TMPFILE" ] && [ -s "$TMPFILE" ]; then
        # Get the body (everything after the empty line)
        # First, find where headers end
        BODY=$(awk '/^[\r]?$/{p=1; next} p' "$TMPFILE" 2>/dev/null)
        
        if [ -n "$BODY" ]; then
            TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
            echo "[Webhook] $TIMESTAMP - Received data (${#BODY} bytes)"
            
            # Create JSON with simple escaping
            # Limit message to 1000 chars and escape quotes
            MSG=$(echo "$BODY" | head -c 1000 | awk '{gsub(/"/, "\\\"")} 1' | awk '{gsub(/\n/, " ")} 1')
            JSON="{\"source\":\"webhook\",\"timestamp\":\"$TIMESTAMP\",\"message\":\"$MSG\"}"
            
            # Send to server
            echo "[Webhook] Sending to $SERVER_URL/api/feed"
            RESULT=$(curl -s -X POST "$SERVER_URL/api/feed" \
                -H "Content-Type: application/json" \
                -d "$JSON" 2>&1)
            echo "[Webhook] Server response: $RESULT"
        fi
    fi
    
    # Cleanup
    rm -f "$TMPFILE" "$RESPONSE"
    
    # Small delay before accepting next connection
    sleep 0.1
done