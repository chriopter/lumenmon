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


- Fix Sparklines if offline
- Polish Auto-Installer (PULSE: unbound variable on some systems) as well as client installer, output status after client installation via magic link
- Fix Same Host installation
- Clean Readme
- Clean scattered logs like .lumenmon/console/data/agents.log
- Unifi agents.log and gateway.log etc in single experience, /data/gateway.log


## How It Works

Agents push metrics via SSH to console. Each agent gets a dedicated SSH account and data goes into SQLite.

```
┌─────────────┐  SSH Tunnel   ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤   Port 2345   ├─────────────┤
│ • CPU 1s    │               │ • SSH Server│──► Web Dashboard
│ • Mem 10s   │  Metric Data  │ • Per-agent │    (port 8080)
│ • Disk 60s  │──────────────►│   Linux user│
└─────────────┘               │ • SQLite DB │
                              └─────────────┘
```

Agents collect from `/proc`, push through persistent SSH. Console stores in SQLite (`/data/metrics.db`), one table per metric per agent.

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

# For other operations, use the lumenmon CLI:
lumenmon start    # Start containers
lumenmon logs     # View logs
lumenmon register # Register agent
# See: lumenmon --help
```

---

Based on WebTUI, Flask, Docker, OpenSSH.
