```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```


Monitor all your servers from a single terminal. Based on bash, ssh and file storage - no setup of databases, dashboards or thousand of services.

- **30 seconds to monitoring** – One command, and you're watching live metrics
- **Add servers with a magic link** – Copy, paste, done. Each agent gets its own SSH invite
- **Just works everywhere** – If you have Docker and SSH, you have monitoring
- **Live in your terminal** – Beautiful TUI shows everything at a glance
- **Stupid simple** – Pure Bash, SSH, TSV files. No database, no bloat, no overhead

## Quick Start

Install the console, copy the invite link to your servers, watch the metrics flow.

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```

<img width="650" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />


## How It Works

```
┌─────────────┐  SSH Tunnel   ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤   Port 2345   ├─────────────┤
│ • CPU 100ms │               │ • SSH Server│──► TUI Dashboard
│ • Mem 1s    │  TSV Stream   │ • Per-agent │    (Textual)
│ • Disk 60s  │──────────────►│   Linux user│
└─────────────┘               │ • TSV files │
                              └─────────────┘
                                    │
                                    ▼
                              /data/agents/
                              └── <agent-id>/
                                  ├── cpu.tsv
                                  ├── memory.tsv
                                  └── disk.tsv
```

- **Agents** collect metrics (CPU/memory/disk) and stream TSV data through persistent SSH connections
- **Console** creates isolated Linux users per agent, routes data to `/data/agents/<id>/*.tsv` files
- **Security** uses SSH keys only, temporary invite passwords expire in 5 minutes, host key pinning from first connect

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

---

Thanks to Textual, plotext, Docker, and OpenSSH for the heavy lifting.
