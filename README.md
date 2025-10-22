```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```


It's too damn complicated to quickly setup system monitoring for a few servers.

Lumenmon fixes that. It's a simple monitoring tool, that you can install in under 30 seconds.

A stupid simple docker container with just a bunch of bash scripts will collect data and send it via SSH to the console. A simple WebTUI to view. That's it.

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

## Next / Todos

- Show invite remaing time, sort invites below hosts, fix graphs
- Fix Sparklines if offline
- Polish Auto-Installer (PULSE: unbound variable on some systems) as well as client installer, output status after client installation via magic link
- Fix Same Host installation
- Clean Readme
- Clean scattered logs like .lumenmon/console/data/agents.log
- Unifi agents.log and gateway.log etc in single experience, /data/gateway.log


## How It Works

```
┌─────────────┐               ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤   SSH Tunnel  ├─────────────┤
│ • CPU 1s    │──────────────►│ • SSH Server│──► Web Dashboard
│ • Mem 10s   │  Metric Data  │ • SQLite DB │
│ • Disk 60s  │               │ • WebTUI    │
└─────────────┘               └─────────────┘                 
```
**The Agent container** runs collector script based on a configured intervall, connects via SSH multiplex to the console and pushes the data to an gateway. Everything is bash.

**The Console container** creates a linux user per agent to connect, bounds incoming SSH connects via ForceCommand to gateway.py which writes incoming data to an SQLite. A flask Server is delivered via Caddy for the WebTUI.

**The data structure** is quite simple, the agent pipes data from scripts against the gateway via SSH (Prefix, data type, interval and actual data). The gateway will create the necessary sqlite tables based on the prefix. If the data type e.g. changes, the table is recreated.

**Invite system** is based on linux users. Invites are temporary linux users with timestamp in the name (to autodelete them after 60 minutes). The console SSH key is pinned from very first connection on to mitigate MITM. When an agent enrolls with such an invite, a permanent user is created and the agents ssh key is pinned on the host as well. The container recreates the user on container start from the data dir. Therefore, the complete authentication is just linux users + standard ssh tooling.


```
**Invite link logic**
ssh://username:password@consolehost:port/#hostkey
ssh://reg_1761133283700:8938fe9d5c32@192.168.10.13:2345/#ssh-ed25519_AAAAC3NzaC1lZDI1NTE5AAAAIGPrge2Vp5PgsgRx9n/Z9prEfttG5xt8MOe1WtjcdhzX
```

<details>

<summary>Agent file structure</summary>

```
├── agent.sh (Main entry)
├── collectors/ (Data collectors)
│   ├── generic (Scripts running on all system)
│   └── ... (Scripts running dependent on environment, decided by collectors.sh)
├── core/ (Scripts to register with server, start connection, start collectors)
└── data/ (Persistent directory with SSH Identity)
```

</details>




<details>

<summary>Console file structure</summary>

```
├── console.sh (Main entry)
├── core (Core setup)
│   ├── enrollment (Bash scripts to create invitations, enroll users etc.)
│   ├── ingress (gateway.py and ssh server config)
│   ├── setup (server setup, including re-creation of users on container start) 
├── data (Persistent data dir)
│   ├── agents (per agent user folder, containing authorized ssh keys)
│   └── ssh (console ssh identity)
└── web (Web server)
    ├── app (Flask app)
    ├── config (Caddy Config)
    └── public (HTML, CS, JS)
```

</details>



**Same-host installations**: When console and agent run on the same machine, they communicate via Docker's internal network (`lumenmon-console:22`), not the external port `localhost:2345`. The installer handles this automatically.

### Security

- **Push-only over SSH**: Agents initiate outbound connections. Console never connects to agents. No firewall rules needed, works behind NAT.
- **MITM-proof enrollment**: Invite links include SSH host key fingerprint. Agents verify before sending credentials. After enrollment, SSH keys pinned to per-agent console users.
- **Isolated execution**: Runs in Docker. ForceCommand prevents shell access. Per-agent Linux users and file permissions enforce data isolation.

### Invite Process

Console creates temp user `reg_<timestamp>` with 5-min expiry. Magic link: `ssh://user:pass@host:2345/#ed25519_hostkey` (host key prevents MITM). Agent sends public key via password auth, console creates permanent user `id_<fingerprint>` with key-based access. Agent connects via persistent SSH control socket, all collectors multiplex through it.

### Collector Execution

Collectors are bash scripts (`collectors/*/*.sh`) running `while true; do sleep $RHYTHM; <read /proc>; done` loops. Each collector uses a timing variable set by agent:

| Rhythm | Interval | Purpose |
|--------|----------|---------|
| PULSE | 1s | Fast-changing metrics (CPU) |
| BREATHE | 60s | Moderate metrics (memory) |
| CYCLE | 300s | Slow-changing (disk usage) |
| REPORT | 3600s | CPU-heavy operations (update status) |

Each sends typed data via SSH: `generic_cpu.tsv REAL\n1729123456 1 23.4`. Console ForceCommand gateway writes to SQLite (`/data/metrics.db`) with type-safe columns. Web dashboard queries database for real-time display.

## Development

```bash
# Full auto-setup: reset, start containers, register agent, and launch WebTUI
./dev/auto

# Multi-agent testing (spawns 3 agents)
./dev/add3

# Create new release (interactive version bumping)
./dev/release

# Update vendored CSS/JS dependencies
./dev/updatecss
```

---

Based on WebTUI, Flask, Docker, OpenSSH.
