# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lumenmon is a lightweight system monitoring solution with MQTT transport and web-based dashboard. It consists of two main components:
- **Console**: Central monitoring dashboard with MQTT broker and web interface (Docker: Flask + Mosquitto + Caddy)
- **Agent**: Bare metal bash scripts that collect metrics and publish to console via MQTT with TLS

## CLI Commands

### Console CLI (`lumenmon`)
```bash
lumenmon              # Show status
lumenmon invite       # Generate agent invite
lumenmon logs         # View container logs
lumenmon update       # Update container
lumenmon uninstall    # Remove everything
```

### Agent CLI (`lumenmon-agent`)
```bash
lumenmon-agent              # Show status
lumenmon-agent register     # Register with invite URL
lumenmon-agent start        # Start systemd service
lumenmon-agent stop         # Stop service
lumenmon-agent logs         # View service logs
lumenmon-agent uninstall    # Remove agent
```

### Development Commands
```bash
./dev/auto      # Full reset and setup
./dev/add3      # Spawn 3 test agents
./dev/release   # Create new release
./dev/updatedeps # Update vendored CSS/JS
```

## Installation

**Console:**
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/console/install.sh | bash
```

**Agent:**
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/agent/install.sh | bash
lumenmon-agent register '<invite-url>'
lumenmon-agent start
```

## Architecture

### Ports
- **8080**: Web dashboard (HTTP via Caddy)
- **8884**: MQTT broker with TLS (Mosquitto)
- **5000**: Flask API (internal, proxied by Caddy)

### Directory Structure

```
lumenmon/
├── console/                    # Docker container
│   ├── install.sh              # Console installer
│   ├── lumenmon                 # Console CLI
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── config/                 # Mosquitto config
│   ├── core/                   # Shell scripts
│   │   ├── enrollment/         # Invite generation
│   │   ├── mqtt/               # MQTT gateway
│   │   └── setup/              # Init scripts
│   └── web/                    # Flask app
│       ├── app/                # Python API
│       ├── config/             # Caddy config
│       └── public/             # HTML/CSS/JS
│
├── agent/                      # Bare metal scripts
│   ├── install.sh              # Agent installer
│   ├── lumenmon-agent          # Agent CLI
│   ├── agent.sh                # Main entry point
│   ├── core/
│   │   ├── mqtt/publish.sh     # MQTT publishing
│   │   ├── setup/register.sh   # Registration
│   │   └── status.sh           # Status checks
│   └── collectors/generic/     # Metric collectors
│       ├── cpu.sh
│       ├── memory.sh
│       ├── disk.sh
│       ├── heartbeat.sh
│       ├── hostname.sh
│       └── lumenmon.sh
│
└── dev/                        # Development scripts
```

### Data Flow
1. Agents collect metrics at intervals (CPU: 1s, Memory: 10s, Disk: 60s)
2. Metrics published to MQTT via `mosquitto_pub` with TLS
3. Console gateway writes to SQLite (`/data/metrics.db`)
4. Web dashboard queries SQLite for display
5. Tables: one per metric per agent (`id_xxx_metric_name`)

### Security Model
- **TLS certificate pinning** (agents verify broker certificate fingerprint)
- **Per-agent MQTT credentials** (32-char random passwords)
- **Agent data isolated by MQTT topic ACLs** (write-only to own topics)
- **DoS protection** (connection/message rate limits)

## Key Implementation Details

### Agent (Bare Metal)
- Pure bash + `mosquitto_pub` for MQTT
- `$LUMENMON_HOME` points to agent directory (default: `/opt/lumenmon/agent`)
- `$LUMENMON_DATA` points to data directory (`$LUMENMON_HOME/data`)
- Collectors source `$LUMENMON_HOME/core/mqtt/publish.sh` for `publish_metric` function
- Runs as systemd service (`lumenmon-agent.service`)

### Console (Docker)
- Flask API server with HTML/JavaScript frontend
- Mosquitto MQTT broker with TLS on port 8884
- Caddy reverse proxy (5000 → 8080)
- SQLite for metric storage with WAL mode

### Metric Collection Timing
```bash
PULSE=1       # CPU - 1 second
BREATHE=10    # Memory - 10 seconds
CYCLE=60      # Disk - 60 seconds
REPORT=3600   # Hostname/system - 1 hour
```

### MQTT Enrollment Flow
1. Console creates invite: `lumenmon://USERNAME:PASSWORD@HOST:8884#FINGERPRINT`
2. Agent registers: parses URI, verifies certificate fingerprint, saves credentials
3. Agent publishes to `metrics/{agent_id}/{metric_name}`

## Common Tasks

### Adding New Metrics
1. Create collector in `agent/collectors/generic/`
2. Source publish.sh: `source "$LUMENMON_HOME/core/mqtt/publish.sh"`
3. Call: `publish_metric "metric_name" "$value" "REAL" "$INTERVAL"`
4. Types: REAL (numeric), TEXT (string), INTEGER (whole number)

### Debugging Agent
```bash
lumenmon-agent status           # Check connectivity
journalctl -u lumenmon-agent    # View logs
cat /tmp/collector_cpu.log      # Collector errors
```

### Debugging Console
```bash
lumenmon logs                                    # Container logs
docker exec lumenmon-console cat /data/gateway.log  # Gateway errors
docker exec lumenmon-console sqlite3 /data/metrics.db ".tables"
```

## Code Style

Shell scripts start with 2-line comment after shebang:
```bash
#!/bin/bash
# What the script does (purpose).
# Key details (inputs/outputs, how invoked).
```
