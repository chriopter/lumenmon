# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lumenmon is a lightweight system monitoring solution with SSH transport and TUI dashboard. It consists of two main components:
- **Console**: Central monitoring dashboard with SSH server and TUI interface
- **Agent**: Metrics collector that sends data to console via SSH

## CLI Commands

### Production Commands (`lumenmon`)
```bash
lumenmon              # Open WebTUI (or show status if not running)
lumenmon status       # Show comprehensive system status
lumenmon logs         # Stream logs from all containers
lumenmon invite       # Generate agent enrollment invite
lumenmon register     # Register agent with invite URL
lumenmon update       # Update from GitHub (downloads latest compose, pulls images)
lumenmon uninstall    # Remove all containers and data

# Short aliases available: s (status), l (logs), i (invite), r (register), u (update), h (help)
```

### Status Output
- **Console**: Shows SSH key, service port, authorized keys, active invites, connected agents, active agents
- **Agent**: Shows SSH key, agent ID, console config, network connectivity, host fingerprint, SSH connection, metrics flow

### Development Commands
```bash
# Full auto-setup: reset, start containers, register agent, and launch TUI
./dev/auto

# Individual commands
./dev/start      # Start console and agent containers
./dev/stop       # Stop all containers
./dev/reset      # Clean everything and restart fresh
./dev/register   # Register agent with console (requires invite URL)
./dev/tui        # Launch TUI dashboard
./dev/logs       # Show container logs
```

### Docker Operations
```bash
# Build and run console
docker compose -f console/docker-compose.yml up -d --build

# Build and run agent (with local console)
CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose -f agent/docker-compose.yml up -d --build

# Access TUI directly (Bash TUI)
docker exec -it lumenmon-console /app/tui.sh
```

### Bash TUI Development
- TUI is implemented in Bash under `console/tui/` with modular scripts.
- No Python/Textual dependencies.
- CI currently validates shell syntax (`bash -n`) and builds Docker images.
- Optional: add `shellcheck` locally or in CI for stricter linting.

## Installation

### Quick Install
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install.sh | bash
```

The installer provides an interactive menu for Console, Agent, or both installations.

### Installer Details
- `install.sh`: Self-contained installer that downloads compose files from GitHub
- Downloads from `https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/`
- Three install modes: "Console with Agent" (recommended), "Console only", "Agent only"
- Auto-registers local agent in "both" mode via Docker network
- Installs `lumenmon` CLI symlink to `/usr/local/bin/` or `~/.local/bin/`
- One-line agent install: `LUMENMON_INVITE="<url>" bash install.sh`

## Architecture

### Data Flow
1. Agents collect metrics at intervals (CPU: 1s, Memory: 10s, Disk: 60s)
2. Metrics sent via SSH with type declarations (ForceCommand gateway)
3. Console gateway writes to SQLite database (`/data/metrics.db`)
4. Web dashboard queries SQLite for real-time display
5. Tables: one per metric per agent (`id_xxx_metric_name`)

### Directory Structure
- `console/`: Dashboard container
  - `web/`: Flask web dashboard (port 5000, proxied via Caddy on 8080)
    - `app/`: Python API server
      - `db.py`: Database connection helpers
      - `ssh_status.py`: SSH connection checking
      - `metrics.py`: Metric reading and aggregation
      - `agents.py`, `invites.py`, `debug.py`: API blueprints
    - `public/`: HTML templates, CSS, JavaScript
  - `core/`: Shell scripts for SSH, enrollment, ingress
    - `ingress/gateway.py`: SSH ForceCommand handler (writes to SQLite)
    - `status.sh`: Comprehensive console status checks
  - `data/`: Persistent database and SSH keys (gitignored)

- `agent/`: Metrics collector container
  - `collectors/`: Metric collection scripts (CPU, memory, disk)
  - `core/`: Registration and connection scripts
    - `status.sh`: Comprehensive agent status with connectivity checks
  - `data/`: SSH keys and config (gitignored)

- `install.sh`: Self-contained installer in repo root
  - Downloads compose files from GitHub raw URLs
  - Interactive menu for Console/Agent/Both
  - Auto-registration support

- `lumenmon.sh`: Main CLI script in repo root
  - Smart defaults: no args opens WebTUI or shows status
  - Single-letter aliases for common commands
  - Integrated update and uninstall commands

### Security Model
- SSH key-based authentication only (no passwords)
- Per-agent Linux users in console container
- ForceCommand prevents shell access
- Agent data isolated by user permissions

## Code Style Guidelines

### File Header Comments
Every shell script must start with a concise 2-line comment after the shebang:
- **Line 1**: What the script does (purpose and high-level function)
- **Line 2**: Key details (inputs/outputs, usage, or how it's invoked)

Example:
```bash
#!/bin/bash
# Generates or loads agent SSH keypair and derives unique agent ID from key fingerprint.
# Sets SSH_KEY (private key path) and AGENT_USER (agent ID) variables. Sourced by agent.sh during startup.
```

Guidelines:
- Keep it to 2 lines maximum
- Be specific and descriptive
- Mention what variables are set/exported if applicable
- Note if the script is sourced vs executed directly
- Focus on what users need to understand, not implementation details

## Key Implementation Details

### Console Web Dashboard (`console/web/`)
- Flask API server with HTML/JavaScript frontend
- Real-time agent monitoring with Chart.js visualizations
- Keyboard navigation (j/k, Enter, Esc, i=invite, r=refresh, d=debug)
- Status indicators: green (online), yellow (stale), red (offline)
- Status logic: checks SSH connections + data freshness
- Detail view: CPU/memory/disk charts, all metrics table
- Debug view (d key): system users vs database agents

### SSH Enrollment Flow
1. Console creates invite: `/app/core/enrollment/invite_create.sh`
2. Agent registers: `/app/core/setup/register.sh <invite_url>`
3. Console creates dedicated user and sets up SSH access
4. Agent connects and starts streaming metrics

### Metric Storage (SQLite)
- Database: `/data/metrics.db` (SQLite3 with WAL mode)
- Table structure: one table per metric per agent
- Table naming: `{agent_id}_{metric_name}` (e.g., `id_abc123_generic_cpu`)
- Schema: `(timestamp INTEGER PRIMARY KEY, value TYPE)`
- Types: REAL (numeric), TEXT (strings), INTEGER (whole numbers)
- Protocol: Collectors declare type in header: `metric_name.tsv TYPE`
- Auto-migration: Tables dropped/recreated if type changes

### Status Scripts
Both `console/core/status.sh` and `agent/core/status.sh` provide comprehensive checks:
- **Agent**: SSH key, agent ID, console config, network ping, host fingerprint, SSH connection, metrics flow
- **Console**: Host key, SSH service, authorized keys, active invites, connected agents, active agents (< 60s data)
- Compact output format with clear status indicators: ✓ (success), ✗ (failure), ⚠ (warning), ○ (neutral)

## Common Tasks

### Adding New Metrics
1. Create collector script in `agent/collectors/` (or `agent/collectors/generic/`)
2. Add TYPE config: REAL (numeric), TEXT (string), INTEGER (whole number)
3. Send data with type header: `echo -e "metric_name.tsv $TYPE\n$timestamp $interval $value" | ssh ...`
4. Ensure collector is started by `agent/core/connection/collectors.sh`
5. Metric appears automatically in web dashboard "All Values" table

### Modifying Web Dashboard
- API endpoints: `console/web/app/*.py` (Flask blueprints)
- Frontend: `console/web/public/html/*.html` (Jinja2 templates with inline JS)
- Styling: `console/web/public/css/styles.css` (Catppuccin theme)
- Add charts: modify `detail.html` renderChart() function
- Add keyboard shortcuts: `keyboard.html`

### Debugging
- Container logs: `docker logs lumenmon-console` or `lumenmon logs`
- Agent debug output: Check `agent/data/debug/`
- SSH issues: Verify keys in `console/data/ssh/` and `agent/data/ssh/`
- TUI issues: Run directly with `docker exec -it lumenmon-console /app/tui.sh`
- Status check: `lumenmon status` for comprehensive system state
