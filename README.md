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
The Agent container runs collector script based on a configured intervall, connects via SSH multiplex to the console and pushes the data to an gateway. Everything is bash.

The Console container creates a linux user per agent to connect, bounds incoming SSH connects via ForceCommand to gateway.py which writes incoming data to an SQLite. A flask Server is delivered via Caddy for the WebTUI.

```
┌─────────────┐               ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤   SSH Tunnel  ├─────────────┤
│ • CPU 1s    │──────────────►│ • SSH Server│──► Web Dashboard
│ • Mem 10s   │  Metric Data  │ • SQLite DB │
│ • Disk 60s  │               │ • WebTUI    │
└─────────────┘               └─────────────┘                 
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

### Data structure

**The data structure** is quite simple, the agent pipes data from scripts against the gateway via SSH (Prefix, timestamp, data type, interval and actual data). The gateway will create the necessary sqlite tables based on the prefix. If the data type e.g. changes, the table is recreated.

<img width="700" alt="image" src="https://github.com/user-attachments/assets/2e67ead2-e5ce-4291-80d1-db08f7dd6ee7" />

### Enrollment / Security
- **Invite system** is based on linux users. Invites are temporary linux users with timestamp in the name (to autodelete them after 60 minutes). 
- **Enrollment**: Invite links include the SSH host key (MITM mitigating). After enrollment, SSH keys of agents are pinned as authorized keys. Therefore, the complete authentication is just linux users + standard ssh tooling.
- **Design** Agents initiate outbound connections. Console can not connect to agents. The Agent is designed in a very KISS manner, based only on bash and easily reviewable. The console where possible as well, but ofc. the flask webserver is not bash but python.

```
**Invite link logic**
ssh://username:password@consolehost:port/#hostkey
ssh://reg_1761133283700:8938fe9d5c32@192.168.10.13:2345/#ssh-ed25519_AAAAC3NzaC1lZDI1NTE5AAAAIGPrge2Vp5PgsgRx9n/Z9prEfttG5xt8MOe1WtjcdhzX
```

# Installer
The installer script** will start the respective docker containers and creates a first invitation. When console and agent run on the same machine (recommended way to run console), they communicate via Docker's internal network (`lumenmon-console:22`), not the external port `localhost:2345`. The installer handles this automatically.


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


## Next / Todos

- Show invite remaing time, sort invites below hosts, fix graphs
- Fix Sparklines if offline
- Polish Auto-Installer (PULSE: unbound variable on some systems) as well as client installer, output status after client installation via magic link
- Fix Same Host installation
- Clean Readme
- Clean scattered logs like .lumenmon/console/data/agents.log
- Unifi agents.log and gateway.log etc in single experience, /data/gateway.log


Based on WebTUI, Flask, Docker, OpenSSH.
