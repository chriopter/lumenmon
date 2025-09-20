#!/bin/bash
# Test SSH daemon and config

echo "Testing SSH connection..."
docker exec lumenmon-console sh -c "ps aux | grep sshd"
echo ""
echo "SSH host keys:"
docker exec lumenmon-console ls -la /etc/ssh/ssh_host* 2>&1 || echo "No host keys"
echo ""
echo "Data directory:"
docker exec lumenmon-console ls -la /data/ 2>&1
echo ""
echo "Agents directory:"
docker exec lumenmon-console ls -la /data/agents/ 2>&1
echo ""
echo "SSH config test:"
docker exec lumenmon-console /usr/sbin/sshd -T 2>&1 | grep -E "^(port|forcecommand|match)" | head -20