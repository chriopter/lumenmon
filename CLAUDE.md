# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lumenmon is a lightweight system monitoring solution with MQTT transport and web-based dashboard. It consists of two main components:
- **Console**: Central monitoring dashboard with MQTT broker and web interface (Flask + HTML/JS)
- **Agent**: Metrics collector that publishes data to console via MQTT with TLS

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
- **Console**: Shows TLS certificate fingerprint, MQTT broker status, active invites, connected agents, active agents
- **Agent**: Shows agent ID, console config, MQTT credentials status, network connectivity, TLS verification, MQTT connection, metrics flow

### Development Commands
```bash
# Full auto-setup: reset, start containers, register agent, and launch WebTUI
./dev/auto

# Multi-agent testing (spawns 3 agents)
./dev/add3

# Create new release (interactive version bumping)
./dev/release

# Update vendored CSS/JS dependencies
./dev/updatedeps

# For other operations, use the lumenmon CLI:
lumenmon start    # Start containers
lumenmon logs     # View logs
lumenmon register # Register agent
# See: lumenmon --help
```

### Docker Operations
```bash
# Build and run console
docker compose -f console/docker-compose.yml up -d --build

# Build and run agent (with local console)
CONSOLE_HOST=localhost docker compose -f agent/docker-compose.yml up -d --build

# Access web dashboard
# Open browser to http://localhost:8080 (or use 'lumenmon' to open WebTUI)
```

### Web Dashboard Development
- Dashboard is implemented as a Flask API (`console/web/app/`) with HTML/JS frontend (`console/web/public/`)
- Uses Chart.js for visualizations and Catppuccin theme for styling
- Keyboard navigation: j/k (navigate), Enter (details), Esc (back), i (invite), r (refresh), d (debug)
- API server runs on port 5000, proxied via Caddy to port 8080
- CI validates shell syntax (`bash -n`) and builds Docker images
- Optional: add `shellcheck` locally or in CI for stricter shell script linting

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

### Ports
- **8080**: Web dashboard (HTTP via Caddy)
- **8884**: MQTT broker with TLS (Mosquitto)
- **9001**: WebSocket (internal, for future MQTT web client)
- **5000**: Flask API (internal, proxied by Caddy)

### Data Flow
1. Agents collect metrics at intervals (CPU: 1s, Memory: 10s, Disk: 60s)
2. Metrics published to MQTT topics as JSON with type declarations
3. Console gateway subscribes to topics and writes to SQLite database (`/data/metrics.db`)
4. Web dashboard queries SQLite for real-time display
5. Tables: one per metric per agent (`id_xxx_metric_name`)

### Directory Structure
- `console/`: Dashboard container
  - `web/`: Flask web dashboard (port 5000, proxied via Caddy on 8080)
    - `app/`: Python API server
      - `db.py`: Database connection helpers
      - `mqtt_status.py`: MQTT connection checking
      - `metrics.py`: Metric reading and aggregation
      - `agents.py`, `invites.py`, `debug.py`: API blueprints
    - `public/`: HTML templates, CSS, JavaScript
  - `core/`: Shell scripts for MQTT, enrollment, and status
    - `mqtt/mqtt_to_sqlite.py`: MQTT subscriber (writes to SQLite)
    - `enrollment/invite_create.sh`: Generate agent invites
    - `status.sh`: Comprehensive console status checks
  - `data/`: Persistent databases and MQTT certificates (gitignored)
    - `metrics.db`: Metric data storage
    - `mqtt/`:
      - `passwd`: Agent credentials (mosquitto password file)
      - `server.crt`: TLS certificate (public)
      - `server.key`: TLS private key (chmod 600)
      - `fingerprint`: SHA256 fingerprint for agent verification

- `agent/`: Metrics collector container
  - `collectors/`: Metric collection scripts (CPU, memory, disk)
  - `core/`: Registration and connection scripts
    - `status.sh`: Comprehensive agent status with connectivity checks
  - `data/mqtt/`: MQTT credentials (gitignored)
    - `username`: Agent ID
    - `password`: MQTT password (permanent)
    - `host`: Console hostname
    - `fingerprint`: Expected server certificate fingerprint
    - `server.crt`: Server TLS certificate (pinned)

- `install.sh`: Self-contained installer in repo root
  - Downloads compose files from GitHub raw URLs
  - Interactive menu for Console/Agent/Both
  - Auto-registration support

- `lumenmon.sh`: Main CLI script in repo root
  - Smart defaults: no args opens WebTUI or shows status
  - Single-letter aliases for common commands
  - Integrated update and uninstall commands

### Security Model
- **TLS certificate pinning** (agents verify broker certificate fingerprint)
- **Per-agent MQTT credentials** (32-char random passwords, permanent)
- **Agent data isolated by MQTT topic ACLs** (write-only to own topics)
- **DoS protection** (connection/message rate limits)

#### MQTT Security Hardening (Internet-Ready)

**Rate Limiting** (`console/config/mosquitto.conf:23-27`):
- `max_connections 1000` - Prevents connection flooding
- `max_inflight_messages 100` - Limits unacknowledged messages per client
- `max_queued_messages 1000` - Prevents message queue exhaustion
- `max_packet_size 65536` - Blocks oversized packet attacks

**Access Control** (`console/config/acl:12`):
- Agents have write-only access to `metrics/%u/#` (their own topics)
- Cannot read any topics (prevents topic enumeration and data leakage)
- Pattern-based isolation ensures agents cannot access other agents' data

**Strong Authentication**:
- 32-character random passwords (base64, ~191 bits of entropy)
- Brute-force impractical: ~6.3 × 10^57 possible passwords
- No password rotation needed (compromised credentials can be revoked)

**Logging**:
- Auth failures logged to stdout (Docker logs)
- Monitor: `docker logs lumenmon-console 2>&1 | grep -i "auth\|connection"`

**Credential Revocation**:
- Delete agents via web dashboard (press `d` key)
- Removes MQTT credentials and all stored data
- Immediate effect (mosquitto reloaded via SIGHUP)

**Additional Protection** (optional, user-managed):
- Use host firewall (iptables/ufw) to restrict MQTT port 8884
- Add fail2ban on host to monitor Docker logs
- Deploy behind reverse proxy (Cloudflare, nginx) for web dashboard

## Code Style Guidelines

### File Header Comments
Every shell script must start with a concise 2-line comment after the shebang:
- **Line 1**: What the script does (purpose and high-level function)
- **Line 2**: Key details (inputs/outputs, usage, or how it's invoked)

Example:
```bash
#!/bin/bash
# Generates unique agent ID and manages MQTT credentials for authentication.
# Sets AGENT_ID and CREDENTIALS_FILE variables. Sourced by agent.sh during startup.
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
- Keyboard navigation (j/k, Enter, Esc, i=invite, r=refresh, s=SQL viewer, m=MQTT explorer)
- Status indicators: green (online), yellow (stale), red (offline)
- Status logic: checks MQTT connections + data freshness
- Detail view: CPU/memory/disk charts, all metrics table

**Synchronized UI Updates** (`console/web/public/html/index.html:15-58`):
- Global clock (`window.globalClock`) waits for ALL async callbacks, then applies DOM updates together
- Clock loop: tick → fetch all data → wait for responses → apply all DOM updates in one frame → 1s delay → repeat
- Main table: `fetchAgents()` queues DOM updates in `window.globalClock.pendingDomUpdates` (table.html:84-100)
- Detail view: `refreshDetailView()` and `loadMetrics()` queue their DOM updates (detail.html:273-276, 570-576)
- Result: Perfect synchronization - all data fetches complete, then entire UI updates in single frame (zero race conditions)

### MQTT Enrollment Flow
1. Console creates invite: `/app/core/enrollment/invite_create.sh`
   - Generates permanent credentials and includes TLS certificate fingerprint
   - Returns: `lumenmon://USERNAME:PASSWORD@HOST:8884#FINGERPRINT`
2. Agent registers: `/app/core/setup/register.sh <invite_url>`
   - Parses invite URI and extracts credentials
   - Verifies TLS certificate fingerprint (user confirms match)
   - Saves credentials permanently and starts streaming metrics

### Metric Storage (SQLite)
- Database: `/data/metrics.db` (SQLite3 with WAL mode)
- Table structure: one table per metric per agent
- Table naming: `{agent_id}_{metric_name}` (e.g., `id_abc123_generic_cpu`)
- Schema: `(timestamp INTEGER PRIMARY KEY, value TYPE)`
- Types: REAL (numeric), TEXT (strings), INTEGER (whole numbers)
- Protocol: Collectors publish JSON with type field: `{"timestamp": 123, "value": 42, "type": "REAL"}`
- Auto-migration: Tables dropped/recreated if type changes

### Metric Collection Timing
Agent collectors use interval-based timing configured via environment variables:

**Runtime Variables** (set in `agent.sh`):
- `PULSE=1` - Fast metrics (CPU usage) - 1 second interval
- `BREATHE=10` - Medium metrics (memory) - 10 second interval
- `CYCLE=60` - Slow metrics (disk) - 60 second interval
- `REPORT=3600` - Hourly metrics (hostname, version) - 1 hour interval

**Docker Compose Variables** (Hz-based, in `agent/docker-compose.yml`):
- `CPU_SAMPLE_HZ=10` - CPU samples per second (100ms resolution)
- `MEMORY_SAMPLE_HZ=1` - Memory samples per second
- `DISK_SAMPLE_HZ=0.1` - Disk samples per second (every 10s)
- `NETWORK_SAMPLE_HZ=0.5` - Network samples per second (every 2s)
- `PROCESS_SAMPLE_HZ=0.2` - Process samples per second (every 5s)
- `SYSTEM_SAMPLE_HZ=0.017` - System samples per second (every ~60s)

Note: Current collectors use the runtime variables (PULSE/BREATHE/CYCLE/REPORT). The Hz-based variables are available for future collectors that need sub-second sampling.

### Status Scripts
Both `console/core/status.sh` and `agent/core/status.sh` provide comprehensive checks:
- **Agent**: Agent ID, MQTT host, TLS certificate (pinned), certificate fingerprint verification, MQTT connection test, running collectors
- **Console**: TLS certificate, MQTT broker on port 8884, MQTT user count, registered agents, online agents (< 10s data)
- Compact output format with clear status indicators: ✓ (success), ✗ (failure), ⚠ (warning)

### Online Status Detection (Centralized Staleness Logic)

**Single Source of Truth**: `console/web/app/metrics.py:calculate_staleness()` - all staleness calculations happen in backend (DRY principle).

Agents are classified based on heartbeat and per-metric staleness:
- **Online** (green): Heartbeat fresh AND all metrics within expected intervals
- **Stale** (yellow): Heartbeat fresh BUT some metrics overdue (agent connected, collection degraded)
- **Offline** (red): Heartbeat stale (agent disconnected, no heartbeat for >2s)

**Staleness Threshold**: Data is stale if it misses expected update with 1s grace: `age > interval + 1s` (e.g., 1s metric stale after 2s, 60s metric stale after 61s)

**Per-Metric Tracking**: Each metric's interval stored in DB, staleness calculated independently. "All Values" table shows:
- Red-highlighted rows for stale metrics
- "NEXT UPDATE" column with countdown (green) or overdue time (red after 1s grace)
- Interval column showing expected update frequency (0s = one-time value, never stale)

## Common Tasks

### Adding New Metrics
1. Create collector script in `agent/collectors/` (or `agent/collectors/generic/`)
2. Choose type: REAL (numeric), TEXT (string), INTEGER (whole number)
3. Publish JSON to MQTT: `mosquitto_pub -t "agent/$AGENT_ID/metric_name" -m '{"timestamp":123,"value":42,"type":"REAL"}'`
4. Ensure collector is started by `agent.sh`
5. Metric appears automatically in web dashboard "All Values" table

### Deleting Agents
Delete an agent completely using the web dashboard:
1. Press `d` key while agent is selected
2. Confirm deletion
3. Backend performs complete cleanup:
   - Drops all SQLite tables for agent (`id_xxx_*`)
   - Removes MQTT credentials from `/data/mqtt/passwd`
   - Triggers mosquitto password reload (SIGHUP)
4. Agent can no longer authenticate or send data
5. Implementation: `console/web/app/management.py` → `DELETE /api/agents/<agent_id>`

### Modifying Web Dashboard
- API endpoints: `console/web/app/*.py` (Flask blueprints)
- Frontend: `console/web/public/html/*.html` (Jinja2 templates with inline JS)
- Styling: `console/web/public/css/styles.css` (Catppuccin theme)
- Add charts: modify `detail.html` renderChart() function
- Add keyboard shortcuts: `keyboard.html`

### Debugging

**First step: Always run `lumenmon status`** - it checks for common issues including gateway errors and permissions.

**Collector not sending data:**
1. Check gateway log: `docker exec lumenmon-console tail -50 /data/gateway.log`
   - Look for "ERROR" or "EXCEPTION" messages
   - Common: "readonly database" means `/data` permissions wrong (needs `root:agents 775`)
2. Check collector error logs: `docker exec lumenmon-agent cat /tmp/collector_cpu.log`
3. Test manually: `docker exec lumenmon-agent bash -c 'export PULSE=1 ...; collectors/generic/cpu.sh'`

**Database issues:**
- Gateway log: `/data/gateway.log` - all ingress errors logged here
- Permissions: `/data` must have proper permissions for SQLite WAL mode
- Direct queries: `docker exec lumenmon-console sqlite3 /data/metrics.db ".tables"`
- Check WAL files: `docker exec lumenmon-console ls -la /data/metrics.db*`

**MQTT issues:**
- Check broker status: `docker exec lumenmon-console ps aux | grep mosquitto`
- Check MQTT logs: `docker logs lumenmon-console | grep mosquitto`
- Verify credentials: `docker exec lumenmon-console cat /data/mqtt/credentials` (agent)
- Test connection: `docker exec lumenmon-agent mosquitto_pub -h lumenmon-console -p 8884 ...`

**Other issues:**
- Container logs: `docker logs lumenmon-console` or `lumenmon logs`
- Web dashboard: Check Flask logs, verify Caddy proxying port 5000→8080
- Debug viewers: Press 's' for SQL viewer, 'm' for MQTT topic explorer
