#!/bin/sh
# Simple SMTP Forwarder - minimal implementation
# Just accepts emails and forwards them

SERVER_URL="${SERVER_URL:-http://localhost:8080}"
SMTP_PORT="${SMTP_PORT:-2525}"

echo "[SMTP] Starting simple SMTP listener on port $SMTP_PORT"
echo "[SMTP] Will forward to: $SERVER_URL/api/feed"

while true; do
    # Create response file with SMTP conversation
    RESPONSE="/tmp/smtp_response"
    REQUEST="/tmp/smtp_request"
    
    # Listen for connection and capture all data
    {
        echo "220 lumenmon SMTP ready"
        
        # Read until QUIT
        while IFS= read -r LINE; do
            LINE=$(printf "%s" "$LINE" | awk '{sub(/\r$/,"")}1')
            echo "[SMTP Debug] Got: $LINE" >&2
            
            case "$LINE" in
                HELO*|EHLO*)
                    echo "250 Hello"
                    ;;
                MAIL*FROM:*)
                    echo "250 Sender OK"
                    ;;
                RCPT*TO:*)
                    echo "250 Recipient OK"
                    ;;
                DATA)
                    echo "354 End data with ."
                    # Read all data until single dot
                    DATA=""
                    while IFS= read -r DLINE; do
                        DLINE=$(printf "%s" "$DLINE" | awk '{sub(/\r$/,"")}1')
                        if [ "$DLINE" = "." ]; then
                            break
                        fi
                        DATA="$DATA $DLINE"
                    done
                    echo "250 Message accepted"
                    
                    # Forward to server
                    if [ -n "$DATA" ]; then
                        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
                        echo "[SMTP] $TIMESTAMP - Received email data" >&2
                        
                        # Create simple JSON
                        MSG=$(echo "$DATA" | head -c 500 | awk '{gsub(/"/, "\\\"")}1')
                        JSON="{\"source\":\"email\",\"timestamp\":\"$TIMESTAMP\",\"message\":\"Email: $MSG\"}"
                        
                        # Send to server
                        curl -s -X POST "$SERVER_URL/api/feed" \
                            -H "Content-Type: application/json" \
                            -d "$JSON" >&2
                        echo "[SMTP] Forwarded to server" >&2
                    fi
                    ;;
                QUIT)
                    echo "221 Bye"
                    exit 0
                    ;;
                *)
                    echo "250 OK"
                    ;;
            esac
        done
    } | nc -l -p $SMTP_PORT || {
        echo "[SMTP] Connection handler failed"
        sleep 1
    }
done