#!/bin/bash
# Debug SSH authentication for agent

echo "Testing SSH authentication for agent..."
# Get the latest agent ID
AGENT_ID=$(docker exec lumenmon-console ls /data/agents/ | grep "^id_" | tail -1)

if [ -z "$AGENT_ID" ]; then
    echo "No agents found"
    exit 1
fi

echo "Testing agent: $AGENT_ID"

# Check user info
echo ""
echo "User info:"
docker exec lumenmon-console getent passwd "$AGENT_ID"

# Check home directory
echo ""
echo "Home directory contents:"
docker exec lumenmon-console ls -la "/data/agents/$AGENT_ID/" 2>&1
docker exec lumenmon-console ls -la "/data/agents/$AGENT_ID/.ssh/" 2>&1

# Check SSH config
echo ""
echo "SSH daemon config for user match:"
docker exec lumenmon-console /usr/sbin/sshd -T -C user="$AGENT_ID",host=localhost,addr=127.0.0.1 2>&1 | grep -E "(forcecommand|authorizedkeysfile|passwordauth)"

# Test SSH directly from agent
echo ""
echo "Testing SSH from agent container:"
docker exec lumenmon-agent ssh -v -o LogLevel=DEBUG \
    -i /home/metrics/.ssh/id_ed25519 \
    -p 2345 \
    "$AGENT_ID@localhost" echo "Connection successful" 2>&1 | grep -E "(debug1: Authentications|debug1: Next authentication|denied|Accepted|Connection)"