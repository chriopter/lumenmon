```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```


Monitor all your servers from a single terminal. No config files, no databases, just SSH.

- **30 seconds to monitoring** – One command, and you're watching live metrics
- **Add servers with a magic link** – Copy, paste, done. Each agent gets its own SSH invite
- **Just works everywhere** – If you have Docker and SSH, you have monitoring
- **Live in your terminal** – Beautiful TUI shows everything at a glance
- **Stupid simple** – Pure Bash, SSH, TSV files. No database, no bloat, no overhead

<img width="650" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />

## Quick Start

Install the console:
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```

You'll see an invite link like this, just paste it on each server to connect the agent.
```
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | \
  LUMENMON_INVITE='ssh://invite:xK3mP9Qw@your-server.com:2345' bash
```

Watch everything live:
```bash
lumenmon
```

That's it. Data flows.

<img width="650" height="870" alt="image" src="https://github.com/user-attachments/assets/281a5b74-908e-400b-b311-64e4a654a324" />


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

**Agent**
- Bash collector scripts for CPU (100ms), memory (1s), disk (60s)
- SSH client multiplexes all metrics through single persistent connection
- Metrics streamed as TSV rows, one file per metric type

**Console**
- SSH server on port 2345, each agent gets dedicated Linux user
- ForceCommand gateway script routes metrics to `/data/agents/<id>/`
- Textual TUI reads live TSV files for real-time display

**Security**
- SSH keys only, no passwords, no shell access via ForceCommand
- Invites are temporary password accounts, expire after 5 minutes or enrollment
- Host key included in invite URL for secure first connection

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
