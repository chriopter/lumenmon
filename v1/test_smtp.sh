#!/bin/bash
# Test SMTP forwarder with various email scenarios

echo "Testing Lumenmon SMTP Forwarder on port 2525"
echo "============================================="

# First check if SMTP port is open
echo -e "\nChecking SMTP server availability..."
if timeout 1 nc -zv localhost 2525 2>&1 | grep -q "succeeded"; then
    echo "✓ SMTP port 2525 is open"
else
    echo "✗ SMTP port 2525 is not responding"
    echo "  Make sure the container is running: docker-compose -f client/docker-compose.yml up -d"
    exit 1
fi

# Test basic SMTP greeting
echo "Testing SMTP greeting..."
GREETING=$(echo "QUIT" | timeout 2 nc localhost 2525 2>&1 | head -1)
if echo "$GREETING" | grep -q "220"; then
    echo "✓ SMTP server responding: $GREETING"
else
    echo "✗ No valid SMTP greeting received"
    echo "  Received: $GREETING"
fi

# Function to send SMTP commands
send_smtp() {
    local FROM="$1"
    local TO="$2"
    local SUBJECT="$3"
    local BODY="$4"
    
    echo "  Connecting to localhost:2525..."
    
    # Test connection first
    if ! timeout 1 nc -zv localhost 2525 2>&1 | grep -q "succeeded"; then
        echo "  ✗ Cannot connect to SMTP port 2525"
        return 1
    fi
    
    echo "  Sending SMTP commands..."
    
    # Send SMTP conversation and capture response
    SMTP_RESPONSE=$({
        echo "HELO testclient"
        sleep 0.1
        echo "MAIL FROM: <$FROM>"
        sleep 0.1
        echo "RCPT TO: <$TO>"
        sleep 0.1
        echo "DATA"
        sleep 0.1
        echo "Subject: $SUBJECT"
        echo "From: $FROM"
        echo "To: $TO"
        echo ""
        echo "$BODY"
        echo "."
        sleep 0.1
        echo "QUIT"
    } | nc localhost 2525 2>&1)
    
    # Check if we got any response
    if [ -z "$SMTP_RESPONSE" ]; then
        echo "  ✗ No response from SMTP server"
        return 1
    fi
    
    # Show first line of response for debugging
    FIRST_LINE=$(echo "$SMTP_RESPONSE" | head -1)
    echo "  Response: $FIRST_LINE"
    
    # Check for success
    if echo "$SMTP_RESPONSE" | grep -q "250"; then
        echo "  ✓ Email sent successfully"
    else
        echo "  ✗ Failed (no 250 response code)"
        echo "  Full response:"
        echo "$SMTP_RESPONSE" | head -10 | sed 's/^/    /'
    fi
}

# Test 1: Alert email
echo -e "\n1. Sending system alert email..."
send_smtp "monitoring@system.local" \
          "admin@company.com" \
          "ALERT: High Memory Usage" \
          "Memory usage has exceeded 90% threshold on production server.
Server: prod-web-01
Memory: 14.5GB / 16GB (90.6%)
Time: $(date)"

# Test 2: Backup notification
echo -e "\n2. Sending backup completion email..."
send_smtp "backup@system.local" \
          "ops@company.com" \
          "Backup Completed Successfully" \
          "Daily backup completed successfully.
Database: production_db
Size: 2.3GB
Duration: 15 minutes
Status: SUCCESS"

# Test 3: Security alert
echo -e "\n3. Sending security alert email..."
send_smtp "security@system.local" \
          "security-team@company.com" \
          "Security Alert: Failed Login Attempts" \
          "Multiple failed login attempts detected:
IP Address: 192.168.1.100
Attempts: 5
User: admin
Action: IP temporarily blocked"

# Test 4: Service down notification
echo -e "\n4. Sending service down notification..."
send_smtp "healthcheck@monitor.local" \
          "devops@company.com" \
          "Service Down: API Gateway" \
          "Critical service is not responding:
Service: API Gateway
Port: 443
Last seen: $(date -d '5 minutes ago' 2>/dev/null || date)
Attempted restart: YES
Status: FAILED"

# Test 5: Disk space warning
echo -e "\n5. Sending disk space warning..."
send_smtp "diskmonitor@system.local" \
          "infrastructure@company.com" \
          "Warning: Low Disk Space" \
          "Disk space running low on following partitions:
/dev/sda1: 89% used (89GB/100GB)
/dev/sdb1: 95% used (475GB/500GB)
Recommended action: Clean up log files or expand storage"

# Test 6: Cron job notification
echo -e "\n6. Sending cron job notification..."
send_smtp "cron@localhost" \
          "admin@localhost" \
          "Cron Job: Database Cleanup Completed" \
          "Scheduled maintenance task completed:
Job: Database cleanup
Rows cleaned: 10,542
Space freed: 523MB
Next run: Tomorrow 2:00 AM"

# Test 7: Certificate expiry warning
echo -e "\n7. Sending SSL certificate expiry warning..."
send_smtp "ssl-monitor@system.local" \
          "webmaster@company.com" \
          "SSL Certificate Expiring Soon" \
          "SSL certificates expiring within 30 days:
Domain: api.company.com
Expires: $(date -d '+25 days' 2>/dev/null || date)
Issuer: Let's Encrypt
Action required: Renew certificate"

# Test 8: Application error
echo -e "\n8. Sending application error email..."
send_smtp "app@production.local" \
          "dev-team@company.com" \
          "Application Error: NullPointerException" \
          "Error detected in production application:
Application: UserService
Error: java.lang.NullPointerException
Location: UserController.java:156
Frequency: 15 times in last hour
Stack trace available in logs"

echo -e "\n============================================="
echo "All emails sent! Check the feed at:"
echo "http://localhost:8080/"
echo ""
echo "To view feed data directly:"
echo "curl -s localhost:8080/api/feed | python3 -m json.tool"
echo ""
echo "Note: If tests show ✗, make sure the SMTP forwarder is running"
echo "and listening on port 2525"