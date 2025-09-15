#!/bin/sh
# SMTP Forwarder - Exact copy of webhook pattern that works
# Uses nc (netcat) for maximum simplicity

SERVER_URL="${SERVER_URL:-http://localhost:8080}"
SMTP_PORT="${SMTP_PORT:-2525}"

echo "[SMTP] Starting SMTP listener on port $SMTP_PORT"
echo "[SMTP] Will forward to: $SERVER_URL/api/feed"

while true; do
    # Create a response file
    RESPONSE="/tmp/smtp_response"
    echo -e "220 lumenmon SMTP ready\r\n250 OK\r\n250 OK\r\n250 OK\r\n354 OK\r\n250 OK\r\n221 Bye\r\n" > $RESPONSE
    
    # Listen and capture request to temp file
    TMPFILE="/tmp/smtp_request"
    nc -l -p $SMTP_PORT < $RESPONSE > $TMPFILE 2>/dev/null
    
    # Process the request
    if [ -f "$TMPFILE" ] && [ -s "$TMPFILE" ]; then
        # Just log that we got something
        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
        SIZE=$(wc -c < "$TMPFILE")
        echo "[SMTP] $TIMESTAMP - Received SMTP data ($SIZE bytes)"
        
        # Create JSON
        JSON="{\"source\":\"email\",\"timestamp\":\"$TIMESTAMP\",\"message\":\"Email received ($SIZE bytes)\"}"
        
        # Send to server
        echo "[SMTP] Sending to $SERVER_URL/api/feed"
        RESULT=$(curl -s -X POST "$SERVER_URL/api/feed" \
            -H "Content-Type: application/json" \
            -d "$JSON" 2>&1)
        echo "[SMTP] Server response: $RESULT"
    fi
    
    # Cleanup
    rm -f "$TMPFILE" "$RESPONSE"
    
    # Small delay before accepting next connection
    sleep 0.1
done