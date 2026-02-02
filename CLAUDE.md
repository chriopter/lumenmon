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
./dev/updatedeps   # Update vendored JS (Chart.js, MQTT.js)
./dev/deploy-test  # Deploy to remote test server (see below)
```

### CSS Development (Tailwind)
```bash
cd console && npm install   # First time only
cd console && npm run dev   # Watch mode - recompiles on changes
cd console && npm run build # One-time build (used by deploy-test)
```

### Remote Test Server Deployment

For rapid development without waiting for GitHub Actions builds, deploy directly to a test server via SSH.

**Setup:**
```bash
# Set the test server SSH target (add to ~/.bashrc or export before running)
export LUMENMON_TEST_HOST="root@your-test-server.local"
```

**Usage:**
```bash
./dev/deploy-test agent    # Deploy agent scripts, restart systemd service
./dev/deploy-test web      # Deploy web frontend (hot reload, no restart)
./dev/deploy-test console  # Deploy full console, restart container
./dev/deploy-test all      # Deploy everything
./dev/deploy-test status   # Check status on test server
```

**What each deployment does:**

| Target | Files | Restart | Speed |
|--------|-------|---------|-------|
| `agent` | `agent/` → `/opt/lumenmon/agent/` | systemd service | ~1s |
| `web` | `console/web/public/` → container `/app/web/public/` | None (hot reload) | ~3s |
| `console` | `console/web/` + `console/core/` → container `/app/` | Docker container | ~5s |

**Notes:**
- Requires SSH key auth to test server
- `web` deployment runs `npm run build` first to compile Tailwind CSS
- Agent data (`/opt/lumenmon/agent/data/`) is preserved (excluded from rsync)
- Console data (`~/.lumenmon/console/data/`) is preserved (lives outside container)
- Shell scripts get `chmod +x` automatically before copying to container

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
│           └── updates.sh      # debian_updates_*: total, security, release, age
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

#### Collector Template
```bash
#!/bin/bash
# Description of what this collector does.
# Reports X at Y interval.

METRIC="generic_example"
TYPE="REAL"  # REAL, INTEGER, or TEXT

source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    value=$(some_command)

    publish_metric "$METRIC" "$value" "$TYPE" "$BREATHE" "$MIN" "$MAX"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0  # Support status test

    sleep $BREATHE
done
```

#### Key Points
- **Types**: REAL (decimal), INTEGER (whole number), TEXT (string)
- **Intervals**: `$PULSE` (1s), `$BREATHE` (60s), `$CYCLE` (5m), `$REPORT` (1h)
- **Test mode line**: Required after all `publish_metric` calls - enables `lumenmon-agent status` to run collector once
- **Min/Max**: Optional bounds for threshold warnings

#### Platform-Specific Collectors
Platform collectors only run when their platform is detected:
- **Proxmox**: `agent/collectors/proxmox/` - checks for `pvesh` command
- **Debian/Ubuntu**: `agent/collectors/debian/` - checks for `apt-get` and `/etc/debian_version`

To add a new platform:
1. Create directory: `agent/collectors/PLATFORM/`
2. Add `_init.sh` that checks for platform and calls `run_collector` for each script
3. Add collector scripts using same pattern above

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

CSS is built with **Tailwind CSS v4**. Source files:
- `console/web/public/css/input.css` - Tailwind + Catppuccin theme + all styles
- `console/web/public/css/styles.css` - Compiled output (do not edit directly)

**Build commands:**
```bash
cd console && npm run build  # One-time compile
cd console && npm run dev    # Watch mode for development
```

**Styles structure** (in `input.css`):
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

## Important: Auto-Deploy During Development

**Always deploy changes to the test server immediately after making them - don't wait for user to ask.**

After making code changes, deploy automatically:
```bash
# Frontend changes (HTML, CSS, JS, widgets)
./dev/deploy-test web

# Backend changes (Python, Flask, SMTP, MQTT)
./dev/deploy-test console

# Agent changes (collectors, shell scripts)
./dev/deploy-test agent
```

This ensures the user sees changes immediately when testing. Never report changes as "done" without deploying first.

## Important: Git Push Policy

**DO NOT push to git unless explicitly requested by the user.**

- Commit changes locally when asked
- Only push when the user explicitly says to push
- This allows review of changes before they go to the remote repository

## Important: No Sensitive Info in Commits

**Never include sensitive or identifying information in code or commits:**

- No real hostnames, machine names, or domain names (use `example.com`, `your-server.local`)
- No real IP addresses (use `192.168.x.x` or `10.0.0.x` examples)
- No real usernames or credentials
- No internal infrastructure details
- Review diffs before committing to catch accidental leaks

## Development Workflow

### Fast Development Loop (Recommended)

Use `./dev/deploy-test` to deploy directly to a test server via SSH. This bypasses GitHub Actions entirely:

```bash
export LUMENMON_TEST_HOST="root@your-test-server"
./dev/deploy-test web      # Hot reload frontend (~2s)
./dev/deploy-test agent    # Deploy agent + restart (~1s)
./dev/deploy-test console  # Full console + restart (~5s)
```

### Release Workflow

GitHub Actions only builds Docker images on version tags (`v*`), not on every commit:

1. Develop and test using `./dev/deploy-test`
2. When ready for release: `./dev/release` creates a version tag
3. Push the tag → GitHub Actions builds and publishes to ghcr.io
4. Users update via `lumenmon update` / `lumenmon-agent update`

### Why This Approach

| Method | Speed | Use Case |
|--------|-------|----------|
| `./dev/deploy-test` | 1-5 sec | Active development |
| GitHub Actions | 2-3 min | Releases only (tags) |

This keeps the dev loop fast while ensuring releases go through CI.

### Debugging the Test Server

If deployment fails or the test server isn't working:

**1. Check SSH connectivity:**
```bash
ssh $LUMENMON_TEST_HOST "echo ok"
```

**2. Check container status:**
```bash
ssh $LUMENMON_TEST_HOST "docker ps -a | grep lumenmon"
ssh $LUMENMON_TEST_HOST "lumenmon"
```

**3. View container logs:**
```bash
ssh $LUMENMON_TEST_HOST "docker logs lumenmon-console --tail 50"
ssh $LUMENMON_TEST_HOST "docker logs lumenmon-console -f"  # Follow live
```

**4. Check if container is crash-looping:**
```bash
ssh $LUMENMON_TEST_HOST "docker inspect lumenmon-console --format='{{.State.Status}} {{.State.Restarting}}'"
```

**5. Fix permission issues (common after deploy):**
```bash
# Shell scripts losing +x after docker cp
ssh $LUMENMON_TEST_HOST "docker exec lumenmon-console find /app -name '*.sh' -exec chmod +x {} \;"
ssh $LUMENMON_TEST_HOST "docker restart lumenmon-console"
```

**6. If container won't start, check from inside:**
```bash
ssh $LUMENMON_TEST_HOST "docker run --rm -it --entrypoint /bin/sh ghcr.io/chriopter/lumenmon-console:latest"
```

**7. Check agent status:**
```bash
ssh $LUMENMON_TEST_HOST "lumenmon-agent"
ssh $LUMENMON_TEST_HOST "journalctl -u lumenmon-agent --tail 50"
```

**8. Test web interface:**
```bash
ssh $LUMENMON_TEST_HOST "curl -s http://localhost:8080 | head -20"
```

**9. Nuclear option - full reset:**
```bash
ssh $LUMENMON_TEST_HOST "docker stop lumenmon-console; docker rm lumenmon-console"
ssh $LUMENMON_TEST_HOST "cd ~/.lumenmon/console && docker compose up -d"
```
