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

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install.sh | bash
```

The installer will guide you through setup and show you how to add agents.

<img width="650" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />

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

**Agent** collects system metrics (CPU, memory, disk) and publishes to console via MQTT with TLS.

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

Agents publish JSON to MQTT topics → Console gateway writes to SQLite (one table per agent per metric) → Web dashboard queries SQLite for display.

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
# Full auto-setup: reset, start containers, register agent, and launch WebTUI
./dev/auto

# Multi-agent testing (spawns 3 agents)
./dev/add3

# Create new release (interactive version bumping)
./dev/release

# Update vendored CSS/JS dependencies
./dev/updatedeps
```
</details>

---

## Next / Todos
- Fix Sparklines if offline
- Data Stream from SQLite to flask.
- Caddy Endpoint Protection

Based on WebTUI, Flask, Docker, MQTT.
