```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
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

## Commands

```bash
lumenmon            # Show status and available commands
lumenmon start      # Start containers
lumenmon logs       # Stream container logs
lumenmon invite     # Generate agent invite (URL + one-line install)
lumenmon register   # Register agent with invite
lumenmon update     # Update CLI, compose files, and images
lumenmon uninstall  # Remove everything
```



## How It Works
### Containers
The Agent container runs collector scripts at configured intervals, publishes metrics to the console via MQTT with TLS. JSON.

The Console container runs an MQTT broker (Mosquitto) to receive data, writes it to SQLite and serves a WebTUI via Flask / Caddy.

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

<summary>Agent app structure</summary>

```
├── agent.sh (Main entry)
├── collectors/ (Data collectors)
│   ├── generic (Scripts running on all system)
│   └── ... (Scripts running dependent on environment, decided by collectors.sh)
├── core/ (Scripts to register with server, start connection, start collectors)
└── data/ (Persistent directory with MQTT credentials)
    └── mqtt/
```

</details>


<details>

<summary>Console app structure</summary>

```
├── console.sh (Main entry)
├── core (Core setup)
│   ├── enrollment (Bash scripts to create invitations and agent registration)
│   ├── mqtt (MQTT broker gateway and subscriber)
│   ├── setup (Server setup and certificate generation) 
├── data (Persistent data dir)
│   ├── metrics.db (SQLite metrics database)
│   └── mqtt (MQTT credentials and TLS certificates)
└── web (Web server)
    ├── app (Flask app)
    ├── config (Caddy Config)
    └── public (HTML, CS, JS)
```

</details>

### Data structure

**The data structure** is quite simple, agents publish JSON metrics to MQTT topics. The gateway subscribes to all agent topics and writes data to SQLite tables (one per agent per metric). If the data type changes, the table is recreated.

<img width="700" alt="image" src="https://github.com/user-attachments/assets/2e67ead2-e5ce-4291-80d1-db08f7dd6ee7" />

## Enrollment / Security
- **Invite system** generates permanent MQTT credentials + TLS certificate fingerprint and formats them in invite links. After enrollment, agents pin the server certificate (self signed certificate for MQTT) and use permanent username/password. 
- **Design** Agents initiate outbound connections. Console cannot connect to agents. The Agent is designed in a very KISS manner, based only on bash and easily reviewable. The console where possible as well, but ofc. the flask webserver is python.
- **Installer** script will start the respective docker containers and create invites for new clients. When console and agent run on the same machine, they communicate via Docker's internal network (`lumenmon-console:8884`).


## Development

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

---


## Next / Todos
- Fix Sparklines if offline
- Data Stream from SQLite to flask.

Based on WebTUI, Flask, Docker, OpenSSH.
