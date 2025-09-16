# Lumenmon

## Commands

### Start Server
```bash
cd server
docker-compose up --build
```

### Connect to TUI
```bash
docker exec -it lumenmon-server python3 /usr/local/bin/tui.py
```

### Start Single Client
```bash
cd client
docker-compose up --build
```

### Start Test Client with Random Name
```bash
docker run -d \
  --name "lumenmon-$(openssl rand -hex 4)" \
  --hostname "node-$(openssl rand -hex 4)" \
  --network lumenmon-net \
  -v lumenmon-ssh-keys:/shared:ro \
  -e SERVER_HOST=lumenmon-server \
  client-client \
  sh -c "while [ ! -f /shared/client_key ]; do sleep 1; done; cp /shared/client_key /home/metrics/.ssh/id_rsa; chmod 600 /home/metrics/.ssh/id_rsa; exec /usr/local/bin/collect.sh"
```

### Start 10 Test Clients
```bash
for i in {1..10}; do
  docker run -d \
    --name "lumenmon-$(openssl rand -hex 4)" \
    --hostname "node-$(openssl rand -hex 4)" \
    --network lumenmon-net \
    -v lumenmon-ssh-keys:/shared:ro \
    -e SERVER_HOST=lumenmon-server \
    client-client \
    sh -c "while [ ! -f /shared/client_key ]; do sleep 1; done; cp /shared/client_key /home/metrics/.ssh/id_rsa; chmod 600 /home/metrics/.ssh/id_rsa; exec /usr/local/bin/collect.sh"
done
```

### Stop Everything
```bash
docker-compose -f server/docker-compose.yml down -v
docker rm -f $(docker ps -aq --filter "name=lumenmon-") 2>/dev/null || true
```