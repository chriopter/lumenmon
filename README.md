```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```

It's too damn complicated to quickly setup system monitoring for a few servers.

Lumenmon fixes that. It's a simple monitoring tool inside a docker container, that you can install in under 30 seconds.

Uses **Glances** for comprehensive system monitoring - CPU, memory, disk, network, GPU, sensors, and more!

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install.sh | bash
```

The installer will guide you through setup and show you how to add agents.

<img width="700"  alt="image" src="https://github.com/user-attachments/assets/6e9a1e4c-59ca-4b34-bfa5-269ab3f99b37" />

<details>
<summary>Commands</summary>

```bash
lumenmon            # Show status and available commands
lumenmon start      # Start containers
lumenmon logs       # Stream container logs
lumenmon invite     # Generate agent invite (URL + one-line install)
lumenmon register   # Register agent with invite
lumenmon update     # Update CLI, compose files, and images
lumenmon uninstall  # Remove everything
```
</details>

## How It Works

There are two docker containers:

**Agent** runs Glances to collect 150+ metrics (CPU, memory, disk, network, GPU, sensors) and publishes to console via MQTT.

**Console** receives data via MQTT broker, stores in SQLite, and serves a web dashboard.

```
┌─────────────┐               ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤  MQTT/TLS     ├─────────────┤
│ • CPU 1s    │──────────────►│ • MQTT 8884 │──► Web Dashboard
│ • Mem 10s   │  Metric Data  │ • SQLite DB │
│ • Disk 60s  │               │ • WebTUI    │
└─────────────┘               └─────────────┘
```

<details>
<summary>Architecture, Data Flow & Security</summary>

### Architecture

**Agent:**
- Runs **Glances** (official `nicolargo/glances:latest-full` image)
- Configured to publish metrics to MQTT broker
- No custom code - pure Glances with MQTT export

**Console:**
```
├── console.sh (Main entry)
├── core (Core setup)
│   ├── enrollment (Bash scripts to create invitations and agent registration)
│   ├── mqtt (MQTT broker gateway and subscriber)
│   ├── setup (Server setup and certificate generation)
├── data (Persistent data dir)
│   ├── metrics.db (SQLite metrics database)
│   └── mqtt (MQTT credentials and TLS certificates)
└── web (Web server)
    ├── app (Flask app)
    ├── config (Caddy Config)
    └── public (HTML, CSS, JS)
```

### Data Flow: How Glances Metrics Flow Through Lumenmon

**Simple 4-Step Process:**

1. **Glances Collects** → Every 3 seconds, Glances reads 150+ system metrics
2. **MQTT Publishes** → Glances sends each metric as JSON to its own MQTT topic
3. **Gateway Transforms** → Console MQTT gateway receives messages and writes to SQLite
4. **Dashboard Displays** → Web UI queries SQLite and shows real-time data

**Example Flow:**

```
Glances reads CPU → 15.2%
  ↓
Publishes to MQTT: metrics/id_abc123/agent-glances/cpu/total → "15.2"
  ↓
Gateway receives message:
  - Parses topic: agent_id="id_abc123", metric="cpu_total"
  - Infers type: REAL (it's a float)
  - Infers interval: 3s (CPU metrics update every 3s)
  - Writes to SQLite table: id_abc123_agent-glances_cpu_total
  ↓
Dashboard queries: SELECT value FROM "id_abc123_agent-glances_cpu_total" ORDER BY timestamp DESC LIMIT 1
  ↓
Shows: CPU 15.2%
```

**Table Structure:**
- One table per metric: `{agent_id}_{hostname}_{metric_path}`
- Example: `id_abc123_agent-glances_cpu_total`
- Schema: `(timestamp INTEGER, value TYPE, interval INTEGER)`

**Type Inference:**
- Python float → SQLite REAL (e.g., 15.2)
- Python int → SQLite INTEGER (e.g., 42)
- Python str → SQLite TEXT (e.g., "online")
- Python bool → SQLite INTEGER (e.g., 1 or 0)

**Interval Assignment (for staleness detection):**
- CPU metrics → 3s
- Memory/network → 10s
- Disk/filesystem → 60s
- System info (hostname, version) → 0s (static, never stale)

**Online Status Logic:**
- Check `uptime_seconds` table timestamp
- If data age < 10s → Status: **ONLINE** (green)
- If data age ≥ 10s → Status: **OFFLINE** (red)

**Data Retention:**
- Automatic 7-day cleanup (removes data older than 7 days)
- Runs daily at 3 AM (see `console/core/mqtt/cleanup_old_data.sh`) 

<img width="700" alt="image" src="https://github.com/user-attachments/assets/2e67ead2-e5ce-4291-80d1-db08f7dd6ee7" />

### Security

**Enrollment:** Invite URLs contain permanent MQTT credentials + TLS certificate fingerprint for agent registration.

**TLS Pinning:** Agents verify server certificate fingerprint during first connection, then pin it for all future connections.

**Network Design:** Agents initiate outbound connections only. Console cannot connect to agents.

**Installation:** When console and agent run on same machine, they communicate via Docker network (`lumenmon-console:8884`) with automatic TLS verification.

**Ports:** Console Exposes ports **8080** (web, no auth - will change) and **8884** (MQTT/TLS with rate limiting, ACL, Auth)

</details>

<details>
<summary>Development</summary>

```bash
# Start console + 1 Glances agent with clean database
./dev/auto

# Add 3 more Glances agents for testing
./dev/add3

# Reset all data/databases (keeps containers running)
./dev/reset-data

# Create git tag and trigger release (e.g., v0.13 → v0.14)
./dev/git-tag-release

# Update vendored CSS/JS dependencies (Chart.js, etc.)
./dev/update-vendor-deps
```

**Dev scripts:**
- `./dev/auto` - Full setup: console + agent with clean DB (~25s)
- `./dev/add3` - Add 3 test agents for multi-agent testing (~20s)
- `./dev/reset-data` - Clear all data/DB for fresh testing
- `./dev/git-tag-release` - Bump version and push git tag
- `./dev/update-vendor-deps` - Update Chart.js and other vendors

All scripts are inline bash (no lib files) - just open and read them!

</details>

---

**Powered by:** Glances • MQTT • SQLite • Flask • Docker • WebTUI
