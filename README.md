# Lumenmon

Lightweight system monitoring with modular collectors, SSH transport, and real-time TUI.

## Architecture

- **Console**: Central monitoring dashboard with TUI display
- **Agents**: Distributed metric collectors running on monitored systems
- **Transport**: Secure SSH with TSV data format
- **Storage**: tmpfs (RAM) for hot data, optional disk persistence

## Quick Start

### 1. Start Console
```bash
cd console
docker-compose up --build -d
```

### 2. View Monitoring Dashboard

**Simple TUI (CPU-focused):**
```bash
docker exec -it lumenmon-console python3 /usr/local/bin/tui.py
```

**Enhanced TUI (All metrics):**
```bash
docker exec -it lumenmon-console python3 /usr/local/bin/tui_enhanced.py
```

### 3. Start Agent(s)

**Single Agent:**
```bash
cd agent
docker-compose up --build
```

**Multiple Test Agents:**
```bash
# Start 5 test agents with random names
for i in {1..5}; do
  docker run -d \
    --name "lumenmon-agent-$(openssl rand -hex 4)" \
    --hostname "node-$(openssl rand -hex 4)" \
    --network lumenmon-net \
    -v lumenmon-ssh-keys:/shared:ro \
    -e CONSOLE_HOST=lumenmon-console \
    agent-agent \
    sh -c "while [ ! -f /shared/agent_key ]; do sleep 1; done; \
           cp /shared/agent_key /home/metrics/.ssh/id_rsa; \
           chmod 600 /home/metrics/.ssh/id_rsa; \
           exec /usr/local/bin/coordinator.sh"
done
```

## Collected Metrics

### High Frequency (0.1-10Hz)
- **CPU**: Usage %, load averages, core count
- **Memory**: Usage %, available/free, swap
- **Network**: RX/TX rates, connectivity, latency

### Medium Frequency (0.1-1Hz)
- **Disk**: Usage % per filesystem, inodes
- **Processes**: Total, running, sleeping, zombie counts

### Low Frequency (per minute)
- **System**: OS, kernel, uptime, container detection

## Configuration

### Agent Sampling Rates

Set via environment variables in `agent/docker-compose.yml`:

```yaml
environment:
  - CPU_SAMPLE_HZ=10        # 10Hz for CPU
  - MEMORY_SAMPLE_HZ=1      # 1Hz for memory
  - DISK_SAMPLE_HZ=0.1      # Every 10s for disk
  - NETWORK_SAMPLE_HZ=0.5   # Every 2s for network
  - PROCESS_SAMPLE_HZ=0.2   # Every 5s for processes
  - SYSTEM_SAMPLE_HZ=0.017  # Every minute for system
```

## Management Commands

### View Logs
```bash
# Console logs
docker logs lumenmon-console

# Agent logs
docker logs lumenmon-agent
```

### Stop Everything
```bash
# Stop console and agents
docker-compose -f console/docker-compose.yml down -v
docker rm -f $(docker ps -aq --filter "name=lumenmon-") 2>/dev/null || true
```

### Clean Restart
```bash
# Remove all containers and volumes
docker-compose -f console/docker-compose.yml down -v
docker-compose -f agent/docker-compose.yml down -v
docker volume rm lumenmon-ssh-keys 2>/dev/null || true

# Start fresh
cd console && docker-compose up --build -d
cd ../agent && docker-compose up --build
```

## Architecture Details

### Data Flow
1. Agents run modular collectors (cpu.sh, memory.sh, etc.)
2. Each collector sends TSV data via SSH to console
3. Console appends data to tmpfs ring buffers
4. TUI reads from tmpfs for real-time display

### Security
- SSH key-based authentication only
- Forced command pattern on console
- No passwords or tokens
- Isolated Docker networks

### Performance
- tmpfs (RAM) for hot data - no disk I/O
- Efficient TSV format
- Persistent SSH connections
- Configurable sampling rates

## Development

### Project Structure
```
lumenmon/
├── console/           # Central monitoring console
│   ├── tui.py        # Simple CPU-focused TUI
│   ├── tui_enhanced.py # Full metrics dashboard
│   ├── lumenmon-append # SSH forced command handler
│   └── Dockerfile
├── agent/            # Metric collection agent
│   ├── coordinator.sh # Manages collectors
│   ├── collectors/   # Modular metric collectors
│   │   ├── cpu.sh
│   │   ├── memory.sh
│   │   ├── disk.sh
│   │   ├── network.sh
│   │   ├── processes.sh
│   │   └── system.sh
│   └── Dockerfile
└── README.md
```

### Adding New Collectors

1. Create new collector in `agent/collectors/`
2. Follow TSV output format: `timestamp\tagent_id\tmetric\ttype\tvalue\tinterval`
3. Add to coordinator.sh startup sequence
4. Update console TUI to display new metrics

## License

MIT