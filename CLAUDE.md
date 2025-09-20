# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lumenmon is a lightweight system monitoring solution using SSH transport and TSV data format. Agents send metrics to a central console via SSH, which stores them in tmpfs (RAM) and displays via TUI.

## Development Commands

### Local Development
```bash
# Development commands (from project root)
./_dev/dev.sh rebuild   # Clean rebuild everything
./_dev/dev.sh console   # Start console only
./_dev/dev.sh agent     # Start agent only
./_dev/dev.sh tui       # Open TUI dashboard
./_dev/dev.sh logs [container]  # View logs
./_dev/dev.sh clean     # Clean data directories

# View dashboard directly
docker exec -it lumenmon-console python3 /app/tui/tui.py
```

### Building and Running
```bash
# Console
cd console
docker compose up -d --build

# Agent
cd agent
docker compose up -d --build

# Always use 'docker compose', not 'docker-compose'
```

### Deployment
```bash
# Install via installer script
curl -H "Accept: application/vnd.github.v3.raw" \
     -sSL https://api.github.com/repos/chriopter/lumenmon/contents/install.sh | bash

# Clean everything
docker rm -f $(docker ps -aq --filter "name=lumenmon") 2>/dev/null;
docker network prune -f; docker volume prune -f; rm -rf ~/.lumenmon
```

## Architecture

### Data Flow
1. Collectors (cpu.sh, memory.sh, etc.) gather metrics at defined rhythms (PULSE, BREATHE, CYCLE, REPORT)
2. Metrics sent as TSV via SSH tunnel to console: `timestamp\tagent_id\tmetric\ttype\tvalue\tinterval`
3. Console's SSH forced command (`/app/ssh/receiver.sh`) writes to tmpfs
4. TUI reads from `/var/lib/lumenmon/hot/` for real-time display

### SSH Transport Pattern
- Console runs SSH server on port 2345 (internal port 22)
- Agents establish persistent SSH connection with multiplexing
- Each collector sends data through shared socket at `/tmp/lumenmon.sock`
- SSH key-only authentication (PermitEmptyPasswords no, PasswordAuthentication no)
- Auto-reconnection on connection failure via connection_monitor.sh
- Per-agent Linux users with ForceCommand gateway pattern

### Critical Paths
- **Console gateway**: `/app/lib/gateway.sh` - receives filename then data via ForceCommand
- **Agent orchestrator**: `/app/agent.sh` - manages SSH tunnel and collectors
- **Connection monitor**: `/app/lib/connection_monitor.sh` - checks tunnel health and reconnects
- **Collectors**: `/app/collectors/generic/*.sh` - send metrics via SSH multiplexed socket
- **User restoration**: `/app/lib/restore_agents.sh` - recreates ephemeral users on container restart

### Storage
- tmpfs mount at `/var/lib/lumenmon/hot/` (100MB RAM)
- Latest values: `/var/lib/lumenmon/hot/latest/{agent_id}.tsv`
- Ring buffers: `/var/lib/lumenmon/hot/ring/{agent_id}/{metric}.tsv` (1000 entries max)

## Key Configuration

### Agent Environment Variables
```bash
CONSOLE_HOST    # Target console (from data/.env or docker-compose.override.yml)
CONSOLE_PORT    # Always 2345
PULSE=0.1       # CPU sampling (10Hz)
BREATHE=1       # Memory sampling (1Hz)
CYCLE=60        # Disk sampling (1/min)
REPORT=3600     # System info (1/hr)
```

### Common Issues

**Agent won't connect to remote console:**
- Check `~/.lumenmon/agent/data/.env` has correct CONSOLE_HOST
- May need: `CONSOLE_HOST=x.x.x.x docker compose up -d`

**SSH socket already exists:**
- Use `docker compose down` then `up -d`, not `restart`
- Socket at `/tmp/lumenmon.sock` needs cleanup between runs

**No metrics received:**
- Check if agent user exists in console: `docker exec lumenmon-console grep id_ /etc/passwd`
- Verify SSH key authentication is working
- Check gateway script permissions

## Testing and Validation

```bash
# Check agent sending data
docker logs -f lumenmon-agent  # Should show connection status every 30s

# Check console receiving
docker exec -it lumenmon-console ls -la /var/lib/lumenmon/hot/latest/

# Debug collector manually
docker exec -it lumenmon-agent bash
export CONSOLE_HOST=x.x.x.x CONSOLE_PORT=2345 SSH_SOCKET=/tmp/lumenmon.sock AGENT_ID=test
./collectors/generic/cpu.sh
```