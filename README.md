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

Install the console (installs Docker if needed). The installer gives you an invite link to add your first server.

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```

Install agent with invite link (one command, installs Docker if needed):

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | LUMENMON_INVITE="<invite_url>" bash
```

<img width="650" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />

## Commands

```bash
lumenmon            # Open dashboard (or show status)
lumenmon start      # Start console and/or agent
lumenmon status     # Show system status (alias: s)
lumenmon logs       # Stream container logs (alias: l)
lumenmon invite     # Generate agent invite (alias: i)
lumenmon register   # Register agent with invite
lumenmon update     # Update to latest version (alias: u)
lumenmon uninstall  # Remove everything
lumenmon help       # Show help (alias: h)
```

## How It Works

You can invite clients with a magic link (which is just a per-client ssh account), each client sends metrics via SSH that get stored in a SQLite database on the Console.


```
┌─────────────┐  SSH Tunnel   ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤   Port 2345   ├─────────────┤
│ • CPU 1s    │               │ • SSH Server│──► Web Dashboard
│ • Mem 10s   │  Metric Data  │ • Per-agent │    (port 8080)
│ • Disk 60s  │──────────────►│   Linux user│
└─────────────┘               │ • SQLite DB │
                              └─────────────┘
                                    │
                                    ▼
                              /data/metrics.db
                              (SQLite database)
                              └── Tables:
                                  ├── id_xxx_generic_cpu
                                  ├── id_xxx_generic_mem
                                  └── id_xxx_generic_disk
```

- **Agents** collect metrics (CPU/memory/disk) and push data through a persistent SSH connection.
- **Console** creates isolated Linux users per agent and stores incoming data in SQLite (`/data/metrics.db`).
- **Storage**: One table per metric per agent with typed columns (REAL for numbers, TEXT for strings, INTEGER for counts).

## Security

- **Push-only architecture**: Agents push metrics outbound via SSH. Console never connects to agents, so no firewall rules or port forwarding needed. Works behind NAT.
- **MITM-proof enrollment**: Invite links include the console's SSH host key fingerprint. Agents verify this before sending credentials, preventing man-in-the-middle attacks during setup.
- **SSH key pinning**: After enrollment, agents connect only with SSH keys (no passwords). Keys are generated per-agent and pinned to specific console users, preventing replay attacks.
- **Isolated execution**: Both console and agents run in Docker containers with minimal dependencies (bash + OpenSSH + /proc). Agents can't execute shells on console via ForceCommand restriction.
- **Per-agent isolation**: Each agent gets its own Linux user on the console. File permissions prevent agents from reading each other's data or accessing other parts of the system.

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
# Full auto-setup: reset, start containers, register agent, and launch TUI
./dev/auto

# Testing with multiple agents
./dev/add10      # Spawn 10 agents for testing (requires console running)

# Individual commands
./dev/start      # Start console and agent containers
./dev/stop       # Stop all containers
./dev/reset      # Clean everything and restart fresh
./dev/register   # Register agent with console (requires invite URL)
./dev/tui        # Launch TUI dashboard
./dev/logs       # Show container logs
```

```bash
./dev/updatecss  # Updates bundled WebTUI CSS, Catppuccin theme, and Chart.js
```

---

Based on WebTUI, Flask, Docker, OpenSSH.