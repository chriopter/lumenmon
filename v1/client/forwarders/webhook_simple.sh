#!/bin/sh
# Simple webhook forwarder that just captures everything and forwards it

SERVER_URL="${SERVER_URL:-http://localhost:8080}"
WEBHOOK_PORT="${WEBHOOK_PORT:-9090}"

echo "[Webhook] Starting simple webhook listener on port $WEBHOOK_PORT"
echo "[Webhook] Will forward to: $SERVER_URL/api/feed"

while true; do
    # Use nc to listen and capture the full request
    REQUEST=$(printf "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\nOK" | nc -l -p $WEBHOOK_PORT 2>/dev/null)
    
    if [ -n "$REQUEST" ]; then
        # Extract just the body (everything after empty line)
        BODY=$(echo "$REQUEST" | awk 'p{print} /^$/{p=1}' | tail -n +2)
        
        if [ -n "$BODY" ]; then
            TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
            echo "[Webhook] $TIMESTAMP - Received: $BODY"
            
            # Create simple JSON - just escape quotes
            ESCAPED=$(echo "$BODY" | awk '{gsub(/"/, "\\\"")} 1' | head -c 500)
            JSON="{\"source\":\"webhook\",\"timestamp\":\"$TIMESTAMP\",\"message\":\"$ESCAPED\"}"
            
            # Send to server
            curl -s -X POST "$SERVER_URL/api/feed" \
                -H "Content-Type: application/json" \
                -d "$JSON" && echo "[Webhook] Sent to server"
        fi
    fi
    
    sleep 0.1
done