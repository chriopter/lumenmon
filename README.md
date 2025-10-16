```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```


Its too damn complicated to quickly setup system monitoring for a few servers.

Lumenmon fixes that. Monitor all your servers from a single terminal. Pure Bash, SSH, and TSV files — no databases, no heavyweight dashboards, no sprawling services.

**Current State:** The structure, installer, Bash TUI, and collectors are v0.1 and evolving.

- **30 seconds to monitoring** – One command, and you're watching live metrics
- **Add servers with a magic link** – Copy, paste, done. Each agent gets its own SSH invite
- **Just works everywhere** – If you have Docker and SSH, you have monitoring
- **Live in your terminal** – Beautiful TUI shows everything at a glance
- **Stupid simple** – Pure Bash, SSH, TSV files. No database, no bloat, no overhead

## Quick Start

Install the console. The installer gives you an invite link to add servers.

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```

<img width="650" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />


## How It Works

```
┌─────────────┐  SSH Tunnel   ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤   Port 2345   ├─────────────┤
│ • CPU 100ms │               │ • SSH Server│──► TUI Dashboard (Bash)
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

## Development Commands

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

---

Based on WebTUI, Flask, Docker, OpenSSH.