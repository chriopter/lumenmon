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
./dev/auto         # Full reset, setup, virtual agent, and watch for .reset
./dev/add3         # Spawn 3 test agents
./dev/release      # Create new release
./dev/updatedeps   # Update vendored CSS/JS
```

### Remote Development (.reset file)
When developing in a remote environment (e.g., CodeCage), the dev server runs on the host machine. To trigger a full restart of the dev environment:

```bash
touch .reset       # Creates .reset file, ./dev/auto watches and restarts
```

The `./dev/auto` script watches for a `.reset` file in the project root. When detected:
1. Kills the virtual agent process
2. Re-executes itself (full restart)
3. Removes the `.reset` file

This allows remote tools to trigger rebuilds without direct terminal access.

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
│   └── collectors/             # Metric collectors
│       ├── generic/            # Universal collectors
│       │   ├── cpu.sh
│       │   ├── memory.sh
│       │   ├── disk.sh
│       │   ├── heartbeat.sh
│       │   ├── hostname.sh
│       │   └── lumenmon.sh
│       ├── proxmox/            # Proxmox-specific
│       │   ├── containers.sh
│       │   ├── vms.sh
│       │   ├── storage.sh
│       │   └── zfs.sh
│       └── debian/             # Debian/Ubuntu-specific
│           └── updates.sh      # Updates: total, security, release upgrade
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

#### Generic Collectors (all systems)
1. Create collector in `agent/collectors/generic/`
2. Source publish.sh: `source "$LUMENMON_HOME/core/mqtt/publish.sh"`
3. Call: `publish_metric "metric_name" "$value" "REAL" "$INTERVAL"`
4. Types: REAL (numeric), TEXT (string), INTEGER (whole number)

#### Platform-Specific Collectors
Platform collectors only run when their platform is detected:
- **Proxmox**: `agent/collectors/proxmox/` - checks for `pvesh` command
- **Debian/Ubuntu**: `agent/collectors/debian/` - checks for `apt-get` and `/etc/debian_version`

To add a new platform:
1. Create directory: `agent/collectors/PLATFORM/`
2. Add `_init.sh` that checks for platform and sources collectors
3. Add collector scripts using same `publish_metric` pattern

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

## Frontend CSS Architecture

CSS lives in `console/web/public/css/styles.css` with clear sections:
1. **Base & Layout** - Body, main content, columns
2. **Utility Classes** - Reusable DRY patterns
3. **Components** - Log box, agents table, detail panel, footer
4. **Grid System** - 4-column widget layout
5. **Widgets** - Metric boxes, storage, ZFS displays
6. **Modals** - SQLite viewer, dialogs
7. **Responsive** - Breakpoints for mobile

### TUI Grid System (4-column)

```html
<div class="widget-grid">
    <div class="widget grid-sm">...</div>  <!-- 2/4 width -->
    <div class="widget grid-sm">...</div>  <!-- 2/4 width -->
</div>
```

| Class | Columns | Width |
|-------|---------|-------|
| `.grid-xs` | span 1 | 25% |
| `.grid-sm` | span 2 | 50% |
| `.grid-md` | span 3 | 75% |
| `.grid-lg` | span 4 | 100% |

**Responsive behavior:**
- `<1000px`: 2-column grid
- `<600px`: 1-column grid

### Utility Classes

| Class | Purpose |
|-------|---------|
| `.tui-table` | Borderless WebTUI table reset |
| `.tui-box` | Bordered box with floating header |
| `.tui-metric-box` | Clickable metric card |
| `.no-scrollbar` | Hide scrollbars |
| `.status-online/warning/error` | Status colors |
| `.bar-ok/warning/critical` | Progress bar colors |

### Widget Structure

```html
<div class="widget grid-sm">
    <div class="tui-metric-box">
        <div class="tui-metric-header">CPU</div>
        <div class="tui-metric-value">42.0<span class="tui-unit">%</span></div>
        <div class="tui-metric-sparkline">▁▂▃▄▅▆▇█</div>
        <div class="tui-metric-extra">avg 45.2%</div>
        <div class="tui-expand-hint">enter</div>
    </div>
</div>
```

## Important: Dev Server Restart

**Always restart the dev server before reporting completed changes to the user.**

After making changes to frontend files (HTML, CSS, JS), run:
```bash
touch .reset
```

This triggers the `./dev/auto` script to restart the container and serve updated files. Without this, the browser may serve cached/stale files and changes won't be visible.
