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
```
├── agent.sh (Main entry)
├── collectors/ (Data collectors)
│   ├── generic (Scripts running on all system)
│   └── ... (Scripts running dependent on environment, decided by collectors.sh)
├── core/ (Scripts to register with server, start connection, start collectors)
└── data/ (Persistent directory with MQTT credentials)
    └── mqtt/
```

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

### Data Flow

Agents publish JSON to MQTT topics → Console gateway writes to SQLite (one table per agent per metric) → Web dashboard queries SQLite for display. Example: Agent `id_abc123` creates tables `id_abc123_generic_cpu`, `id_abc123_generic_disk`, etc.

**Staleness Detection:** Each metric includes its update interval (e.g. 1s for CPU, 10s for memory). Data is stale if it misses the expected update (with 1s grace): `age > interval + 1s`. Agents show green (all fresh), yellow (connected but some metrics stale), or red (no heartbeat). 

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
