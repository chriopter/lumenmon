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

Install the console. The installer gives you an invite link to add your first server.

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```

<img width="650" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />


## How It Works

You can invite clients with a magic link (which is just a per-client ssh account), each client just appends its data to a TSV file in a per-client folder on the Console.


```
┌─────────────┐  SSH Tunnel   ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤   Port 2345   ├─────────────┤
│ • CPU 100ms │               │ • SSH Server│──► WebTUI Dashboard
│ • Mem 1s    │  TSV Stream   │ • Per-agent │
│ • Disk 60s  │──────────────►│   Linux user│
└─────────────┘               │ • TSV files │
                              └─────────────┘
                                    │
                                    ▼
                              /data/agents/
                              └── <agent-id>/
                                  ├── generic_cpu.tsv
                                  ├── generic_mem.tsv
                                  └── generic_disk.tsv
```

- **Agents** collect metrics (CPU/memory/disk) and push TSV data through a persistent SSH connection.
- **Console** creates isolated Linux users per agent and appends incoming data to `/data/agents/<id>/*.tsv`.
- **Security** is SSH-based and push-only. Invites are temporary SSH accounts (password + host fingerprint), exchanged for key-based access on enrollment. Agent and Console run as Docker containers.

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

Each sends 2-line SSH: `generic_cpu.tsv\n1729123456 1 23.4`. Console ForceCommand appends to `/data/agents/$USER/$filename`, rotates at 3600 lines. WebTUI reads TSV directly.

## Commands

```bash
lumenmon            # Open dashboard (or show status)
lumenmon status     # Show system status (alias: s)
lumenmon logs       # Stream container logs (alias: l)
lumenmon invite     # Generate agent invite (alias: i)
lumenmon register   # Register agent with invite
lumenmon update     # Update to latest version (alias: u)
lumenmon uninstall  # Remove everything
lumenmon help       # Show help (alias: h)
```

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

**Updating Web Dependencies:**
WebTUI CSS, Catppuccin theme, and Chart.js are committed to the repo as static files. To update them manually:

```bash
# Update WebTUI CSS
curl -sL https://cdn.jsdelivr.net/npm/@webtui/css@latest/dist/full.css -o console/web/public/css/webtui.css

# Update Catppuccin Mocha theme
curl -sL https://cdn.jsdelivr.net/npm/@webtui/theme-catppuccin@latest/dist/mocha.css -o console/web/public/css/catppuccin.css

# Update Chart.js
curl -sL https://cdn.jsdelivr.net/npm/chart.js@latest/dist/chart.umd.js -o console/web/public/js/vendor/chart.js
```

---

Based on WebTUI, Flask, Docker, OpenSSH.